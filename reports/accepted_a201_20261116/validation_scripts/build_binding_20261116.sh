#!/usr/bin/env bash
# Extend an already verified native build with its Python binding. No NPU work.
set -euo pipefail
[[ $# == 2 ]] || { echo 'Usage: build_binding_20261116.sh DEPLOYMENT_DIRECTORY PRIVATE_VENV' >&2; exit 2; }
: "${ASCEND_HOME_PATH:?Load the verified CANN 9.1.0 environment first}"
TASK_DEPLOYMENT=$(realpath -e -- "$1")
TASK_VENV=$(realpath -e -- "$2")
TASK_WRAPPER=$(realpath -e -- "${BASH_SOURCE[0]}")
[[ -x "$TASK_VENV/bin/python" && -f "$TASK_VENV/pyvenv.cfg" ]] || { echo 'Expected the new private venv'; exit 2; }
# Use only the selected venv, CANN tools and system tools; never inherit old venv PATH.
export PATH="$TASK_VENV/bin:$ASCEND_HOME_PATH/bin:$ASCEND_HOME_PATH/compiler/ccec_compiler/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export VIRTUAL_ENV="$TASK_VENV" PYTHONDONTWRITEBYTECODE=1 PYTHONNOUSERSITE=1
export TASK_VENV TASK_WRAPPER
unset PYTHONPATH PYTHONHOME LD_PRELOAD LIBRARY_PATH CPATH CPLUS_INCLUDE_PATH
unset CONDA_PREFIX CONDA_DEFAULT_ENV CMAKE_PREFIX_PATH
export CC=/usr/bin/cc CXX=/usr/bin/c++
export MAX_JOBS="${T5_BUILD_JOBS:-4}"
[[ "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid T5_BUILD_JOBS'; exit 2; }
source "$TASK_DEPLOYMENT/scripts/phase_common.sh"
[[ "$TASK_ROOT" == "$TASK_DEPLOYMENT" ]] || { echo 'Unexpected phase source root'; exit 2; }
phase_begin build_full native_build

# Select this native build first while retaining the verified CANN/Python
# runtime's existing loader paths. Do not stage a reduced replacement runtime.
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv"
export LD_LIBRARY_PATH="$TASK_ROOT/build/direct/lib:$T5_OPP_ROOT/vendors/t5qkv/op_api/lib:$TASK_VENV/lib/python3.12/site-packages/torch/lib:$TASK_VENV/lib/python3.12/site-packages/torch_npu/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
printf 'Binding-only source: %s\nPrivate venv: %s\nPrivate OPP: %s\n' "$TASK_ROOT" "$TASK_VENV" "$T5_OPP_ROOT"
sha256sum -- "$TASK_WRAPPER" DEPLOYMENT_MANIFEST.json artifacts/validation/native_binary_manifest.json

"$TASK_VENV/bin/python" -I - <<'PY'
import ast
import hashlib
import importlib.metadata as metadata
import json
import os
from pathlib import Path
import platform
import sys

root = Path(os.environ['TASK_ROOT']).resolve(strict=True)
venv = Path(os.environ['TASK_VENV']).resolve(strict=True)
opp = Path(os.environ['T5_OPP_ROOT'])
validation = root / 'artifacts/validation'
commit = json.loads((root / 'DEPLOYMENT_MANIFEST.json').read_text())['commit']
allowed = {'a2013d56db4ff8367160b157335d2ff670aad411', 'f52671207769bf5f334972c997743eb6aa6f91b3'}
if commit not in allowed:
    raise SystemExit('Unexpected exact source commit')
if opp != Path.home() / '.local' / root.name or opp.resolve(strict=True) != opp:
    raise SystemExit('Private OPP must be the exact target path, without redirecting symlinks')
if sys.prefix != str(venv) or platform.python_version() != '3.12.13' or platform.machine() != 'aarch64':
    raise SystemExit('Wrong private Python environment')
if (venv / 'setup.exit').read_text().strip() != '0':
    raise SystemExit('Private Python environment setup has not passed')
receipt = json.loads((venv / 'metadata_verified.json').read_text())
if receipt['status'] != 'pinned_metadata_verified_no_device_execution' or receipt['npu_executed'] is not False:
    raise SystemExit('Missing successful private package receipt')
expected = {
    'torch': ('2.10.0+cpu', '179451716487f8cb09b56459667fa1f5c4c0946c1e75fbeae77cfc40a5768d87'),
    'torch-npu': ('2.10.0.post4', '5cee8b07d98b2188297916342fc587228bfca5703ffa8f48be1a69373414aa44'),
    'numpy': ('2.2.6', 'f2618db89be1b4e05f7a1a847a9c1c0abd63e63a1607d892dd54668dd92faf87'),
    'ml-dtypes': ('0.6.0', '37da32aa97749251025666d62372775019594577b9c9e9cfda83bed48d778fdb'),
}
install = json.loads((venv / 'install-report.json').read_text())['install']
installed = {item['metadata']['name'].lower().replace('_', '-'): item for item in install}
for name, (version, sha) in expected.items():
    distribution = metadata.distribution(name)
    package_root = Path(distribution.locate_file('')).resolve(strict=True)
    if not package_root.is_relative_to(venv) or distribution.version != version:
        raise SystemExit('Installed package identity mismatch: ' + name)
    item = installed[name]
    if (item['metadata']['version'] != version or item['download_info']['archive_info']['hashes']['sha256'] != sha
            or receipt['packages'][name] != {'version': version, 'wheel_sha256': sha}):
        raise SystemExit('Pinned package receipt mismatch: ' + name)
git_version = None
version_source = Path(metadata.distribution('torch-npu').locate_file('torch_npu/version.py'))
for node in ast.parse(version_source.read_text()).body:
    if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == 'git_version' for target in node.targets):
        git_version = ast.literal_eval(node.value)
if not isinstance(git_version, str) or not git_version.startswith('5dd8ef3') or git_version != receipt['torch_npu_git_version']:
    raise SystemExit('TorchNPU Git identity mismatch')
extensions = list(root.rglob('_t5_qkv*.so'))
if extensions:
    raise SystemExit('Preserve existing binding; refusing: ' + repr([str(p) for p in extensions]))
for name in ('environment_build_full.json', 'binding_gate.json', 'binding_import.json', 'binding_source_before.json'):
    path = validation / name
    if path.exists() or path.is_symlink():
        raise SystemExit('Preserve prior binding evidence: ' + str(path))
if (root / 'artifacts/build_manifest.json').exists() or (root / 'artifacts/build_manifest.json').is_symlink():
    raise SystemExit('Preserve existing build fingerprint')
native = json.loads((validation / 'native_binary_manifest.json').read_text())
if (native['source_commit'] != commit or native['private_opp'] != str(opp)
        or native['status'] != 'compiled_native_only' or native['npu_executed'] is not False
        or native['torch_binding_built'] is not False):
    raise SystemExit('Native build identity mismatch')
expected_files = {root / 'build/direct/lib/libt5_direct.so', root / 'build/examples/t5_example'}
expected_files.update(p for p in opp.rglob('*') if p.is_file() and p.suffix in {'.so', '.o', '.json', '.h'})
seen = set()
for record in native['files']:
    path = Path(record['path'])
    if path not in expected_files or path in seen:
        raise SystemExit('Unexpected or duplicate native file: ' + str(path))
    resolved = path.resolve(strict=True)
    if not (resolved.is_relative_to(opp) or resolved.is_relative_to(root / 'build')):
        raise SystemExit('Native file resolves outside this deployment: ' + str(path))
    data = path.read_bytes()
    if len(data) != record['bytes'] or hashlib.sha256(data).hexdigest() != record['sha256']:
        raise SystemExit('Native file changed: ' + str(path))
    seen.add(path)
if seen != expected_files:
    raise SystemExit('Native manifest file coverage mismatch')
for name in ('native_source_before.json', 'native_source_after.json'):
    fingerprint = json.loads((validation / name).read_text())
    if fingerprint['source_commit'] != commit or fingerprint['worktree_status'] != 'archive verified':
        raise SystemExit('Native source fingerprint mismatch: ' + name)
report = {'status': 'passed', 'source_commit': commit, 'native_files_verified': len(seen),
          'private_opp': str(opp), 'python_executable': sys.executable, 'torch_npu_git_version': git_version,
          'packages': receipt['packages'], 'npu_executed': False}
with (validation / 'binding_gate.json').open('x', encoding='utf-8') as handle:
    json.dump(report, handle, indent=2)
    handle.write('\n')
print(json.dumps(report))
PY

# Inventory reads package metadata/driver files and process tables only; no ACL init.
"$TASK_VENV/bin/python" -I tools/preflight.py --output artifacts/validation/environment_build_full.json
"$TASK_VENV/bin/python" -I tools/check_environment.py --input artifacts/validation/environment_build_full.json --accepted-driver 26.1.1
"$TASK_VENV/bin/python" -I tools/fingerprint.py --output artifacts/validation/binding_source_before.json
"$TASK_VENV/bin/python" -I setup.py build_ext --inplace
"$TASK_VENV/bin/python" -I - <<'PY'
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(os.environ['TASK_ROOT']).resolve(strict=True)
sys.path.insert(0, str(root))
import torch
import torch_npu
import _t5_qkv

extensions = list(root.glob('_t5_qkv*.so'))
if len(extensions) != 1 or Path(_t5_qkv.__file__).resolve(strict=True) != extensions[0].resolve(strict=True):
    raise SystemExit('Imported binding must be the sole freshly built target extension')
if torch.__version__ != '2.10.0+cpu' or torch_npu.__version__ != '2.10.0.post4':
    raise SystemExit('Imported package versions differ from metadata')
path = extensions[0]
report = {'status': 'import_passed', 'python_executable': sys.executable,
          'torch': torch.__version__, 'torch_npu': torch_npu.__version__,
          'extension': str(path), 'bytes': path.stat().st_size,
          'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
          'npu_executed': False, 'set_device_called': False}
with (root / 'artifacts/validation/binding_import.json').open('x', encoding='utf-8') as handle:
    json.dump(report, handle, indent=2)
    handle.write('\n')
print(json.dumps(report))
PY
"$TASK_VENV/bin/python" -I tools/fingerprint.py --output artifacts/build_manifest.json
"$TASK_VENV/bin/python" -I - <<'PY'
import hashlib
import json
import os
from pathlib import Path
root = Path(os.environ['TASK_ROOT'])
commit = json.loads((root / 'DEPLOYMENT_MANIFEST.json').read_text())['commit']
for name in ('artifacts/validation/binding_source_before.json', 'artifacts/build_manifest.json'):
    record = json.loads((root / name).read_text())
    if record['source_commit'] != commit or record['worktree_status'] != 'archive verified':
        raise SystemExit('Source changed during binding build: ' + name)
native = json.loads((root / 'artifacts/validation/native_binary_manifest.json').read_text())
for record in native['files']:
    data = Path(record['path']).read_bytes()
    if len(data) != record['bytes'] or hashlib.sha256(data).hexdigest() != record['sha256']:
        raise SystemExit('Native file changed during binding build: ' + record['path'])
print('Binding built and imported; original native binaries and exact source remain verified. No NPU test executed.')
PY
