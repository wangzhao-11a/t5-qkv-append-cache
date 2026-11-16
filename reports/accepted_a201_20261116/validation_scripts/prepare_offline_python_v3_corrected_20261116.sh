#!/usr/bin/env bash
# Fresh offline v3 only. No old venv writes and no NPU execution.
set -euo pipefail
task_venv=/workspace/t5_qkv_tasks/venv_t5_py312_torch210_20261116_offline_v3
wheelhouse=/workspace/t5_qkv_tasks/wheelhouse_20261116
base_python=/usr/local/python3.12.13/bin/python
manifest_sha=cd1bffa369da5ed81a79a49d1bc4b2f2d922fe64255c34263853faacb14e9fda
platform_receipt=/tmp/t5_sources_20261116/target_platform_exact_20261116.json
platform_receipt_sha=2f7090cef6c9eec457e40165fa4cda106456383a3acc9e6828a2fdb8ae9da36a
requirements_sha=4c0dc0617d5b79fb468480b19a6256e8756da208c8b8da022f6c7856cfe398da
[[ ! -e "$task_venv" && ! -L "$task_venv" ]] || { echo 'Preserve existing Python environment'; exit 2; }
[[ -d /workspace/t5_qkv_tasks && ! -L /workspace/t5_qkv_tasks ]] || { echo 'Expected real task root'; exit 2; }
mkdir "$task_venv"
finish_setup() {
    rc=$?
    trap - EXIT
    if ! (set -o noclobber; printf '%s\n' "$rc" > "$task_venv/setup.exit"); then
        echo 'Failed to record setup.exit without overwriting evidence' >&2
        exit 1
    fi
    exit "$rc"
}
trap finish_setup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
unset PYTHONPATH PYTHONHOME
export PYTHONNOUSERSITE=1 PYTHONDONTWRITEBYTECODE=1

"$base_python" -I - "$task_venv" "$wheelhouse" "$manifest_sha" "$requirements_sha" "$platform_receipt" "$platform_receipt_sha" <<'PY'
import hashlib, json, platform, re, sys
from pathlib import Path

venv, house = map(Path, sys.argv[1:3])
manifest_sha, requirements_sha = sys.argv[3:5]
evidence_path = Path(sys.argv[5])
assert not evidence_path.is_symlink()
evidence_raw = evidence_path.read_bytes()
assert hashlib.sha256(evidence_raw).hexdigest() == sys.argv[6], 'Target platform receipt changed'
target_evidence = json.loads(evidence_raw)
assert platform.machine() == 'aarch64'
assert platform.python_version() == '3.12.13'
assert platform.system() == 'Linux'
assert platform.release() == target_evidence['platform_release']
assert platform.version() == target_evidence['platform_version']
assert platform.machine() == target_evidence['machine']
assert platform.system() == target_evidence['system']
assert list(platform.libc_ver()) == target_evidence['libc']
assert platform.libc_ver()[0] == 'glibc'
assert tuple(map(int, platform.libc_ver()[1].split('.'))) >= (2, 28)
assert house.resolve(strict=True) == house and venv.resolve(strict=True) == venv

def digest(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()

def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON key: ' + key)
        result[key] = value
    return result

manifest_path, requirements = house/'wheelhouse-manifest-kernel-corrected.json', house/'requirements-offline.txt'
assert not manifest_path.is_symlink() and not requirements.is_symlink()
assert digest(manifest_path) == manifest_sha, 'Wheelhouse manifest changed'
assert digest(requirements) == requirements_sha, 'Requirements lock changed'
manifest_bytes = manifest_path.read_bytes()
manifest = json.loads(manifest_bytes, object_pairs_hook=unique_keys)
assert manifest['target']['platform_release'] == platform.release()
assert manifest['target']['platform_version'] == target_evidence['platform_version']
assert manifest['target_platform_release_evidence']['sha256'] == sys.argv[6]
assert manifest['target_unverified_fields'] == []
assert manifest['dependency_closure_verified'] is True
assert manifest['wheel_code_imported_or_installed'] is False
assert len(manifest['files']) == 14
names, files, verified, lock = set(), set(), [], []
for record in sorted(manifest['files'], key=lambda item: item['name']):
    name, filename = record['name'], record['filename']
    assert name not in names and filename not in files
    assert Path(filename).name == filename and '\\' not in filename and filename.endswith('.whl')
    assert re.fullmatch('[0-9a-f]{64}', record['sha256'])
    names.add(name)
    files.add(filename)
    path = house/filename
    assert path.is_file() and not path.is_symlink() and path.resolve(strict=True).parent == house
    size = record.get('bytes')
    if name == 'torch':
        assert record['version'] == '2.10.0+cpu' and record['local_file'] is False
        assert filename == 'torch-2.10.0+cpu-cp312-cp312-manylinux_2_28_aarch64.whl'
        assert record['sha256'] == '179451716487f8cb09b56459667fa1f5c4c0946c1e75fbeae77cfc40a5768d87'
        size = 146526037  # Verified target preservation.json; external manifest has no bytes field.
    else:
        assert record['local_file'] is True and record['official_sha256_verified'] is True
    assert isinstance(size, int) and path.stat().st_size == size, filename + ': size mismatch'
    assert digest(path) == record['sha256'], filename + ': SHA256 mismatch'
    verified.append({'name': name, 'version': record['version'], 'filename': filename,
                     'bytes': size, 'sha256': record['sha256']})
    lock.append(f"{name}=={record['version']} --hash=sha256:{record['sha256']}\n")
assert {path.name for path in house.glob('*.whl')} == files, 'Unexpected or missing wheel files'
assert requirements.read_bytes() == ''.join(lock).encode('utf-8'), 'Lock does not exactly cover manifest'
receipt = {'status': 'all_14_wheels_verified_before_install', 'manifest_sha256': manifest_sha,
           'requirements_sha256': requirements_sha, 'wheelhouse': str(house), 'files': verified,
           'npu_executed': False, 'external_torch_bytes': 146526037}
with (venv/'wheelhouse_verified.json').open('x', encoding='utf-8') as handle:
    json.dump(receipt, handle, indent=2); handle.write('\n')
with (venv/'wheelhouse-manifest-kernel-corrected.json').open('xb') as handle:
    handle.write(manifest_bytes)
with (venv/'requirements-offline.txt').open('xb') as handle:
    handle.write(requirements.read_bytes())
print(json.dumps(receipt))
PY

"$base_python" -I -m venv "$task_venv"
export VIRTUAL_ENV="$task_venv"
timeout 1200 "$task_venv/bin/python" -I -m pip --isolated install \
 --disable-pip-version-check --no-cache-dir --only-binary=:all: \
 --no-index --find-links "$wheelhouse" --require-hashes \
 --report "$task_venv/install-report.json" -r "$task_venv/requirements-offline.txt"
"$task_venv/bin/python" -I -m pip check
"$task_venv/bin/python" -I -m pip freeze --all > "$task_venv/installed-freeze.txt"
"$task_venv/bin/python" -I - "$task_venv" "$wheelhouse" <<'PY'
import ast, importlib.metadata as metadata, json, platform, sys
from pathlib import Path
from urllib.parse import unquote, urlparse

root, house = map(Path, sys.argv[1:3])
assert Path(sys.prefix).resolve(strict=True) == root
assert platform.python_version() == '3.12.13' and platform.machine() == 'aarch64'
expected = {record['name']: record for record in json.loads((root/'wheelhouse_verified.json').read_text())['files']}
installed = json.loads((root/'install-report.json').read_text())['install']
records = {}
for item in installed:
    name = item['metadata']['name'].lower().replace('_', '-')
    assert name not in records, name
    records[name] = item
assert set(records) == set(expected), 'Offline installation report does not cover exactly 14 packages'
verified = {}
for name, wanted in expected.items():
    record = records[name]
    assert record['metadata']['version'] == wanted['version'], name
    assert record['download_info']['archive_info']['hashes']['sha256'] == wanted['sha256'], name
    url = urlparse(record['download_info']['url'])
    assert url.scheme == 'file' and url.netloc in ('', 'localhost'), name + ': nonlocal installation source'
    assert Path(unquote(url.path)).resolve(strict=True) == house/wanted['filename'], name
    distribution = metadata.distribution(name)
    assert distribution.version == wanted['version'], name
    assert Path(distribution.locate_file('')).resolve(strict=True).is_relative_to(root), name
    verified[name] = {'version': wanted['version'], 'wheel_sha256': wanted['sha256']}
source = Path(metadata.distribution('torch-npu').locate_file('torch_npu/version.py'))
git_version = None
for node in ast.parse(source.read_text(encoding='utf-8')).body:
    if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == 'git_version' for target in node.targets):
        git_version = ast.literal_eval(node.value)
assert isinstance(git_version, str) and git_version.startswith('5dd8ef3'), 'TorchNPU Git identity differs from baseline'
core = {name: verified[name] for name in ('torch', 'torch-npu', 'numpy', 'ml-dtypes')}
result = {'status': 'pinned_metadata_verified_no_device_execution', 'python': sys.version,
          'executable': sys.executable, 'packages': core, 'all_packages': verified,
          'torch_npu_git_version': git_version, 'npu_executed': False,
          'note': 'Fresh offline v3; all 14 package sources/hashes verified. Old environments preserved.'}
with (root/'metadata_verified.json').open('x', encoding='utf-8') as handle:
    json.dump(result, handle, indent=2); handle.write('\n')
print(json.dumps(result))
PY
