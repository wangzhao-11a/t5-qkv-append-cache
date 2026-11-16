#!/usr/bin/env bash
# Compile the preserved source deployment only. No torch binding or device run.
# Usage: load the verified CANN environment, then bash this_file.sh /exact/deployment
set -euo pipefail
[[ $# == 1 ]] || { echo 'Usage: build_native_20261116.sh DEPLOYMENT_DIRECTORY' >&2; exit 2; }
: "${ASCEND_HOME_PATH:?Load the verified CANN 9.1.0 environment first}"
for command in python3 msopgen cmake c++ realpath sha256sum; do
  command -v "$command" >/dev/null
done
TASK_ROOT=$(realpath -e -- "$1")
WRAPPER_PATH=$(realpath -e -- "${BASH_SOURCE[0]}")
[[ -d "$TASK_ROOT" ]] || { echo 'Deployment must be an existing directory' >&2; exit 2; }
export TASK_ROOT PYTHONDONTWRITEBYTECODE=1
TASK_HOME=$(realpath -e -- "$HOME")
T5_OPP_ROOT=$(realpath -m -- "$TASK_HOME/.local/$(basename -- "$TASK_ROOT")")
case "$T5_OPP_ROOT" in
  "$TASK_HOME"/*) ;;
  *) echo 'Private OPP escaped the user home' >&2; exit 2 ;;
esac
export T5_OPP_ROOT
[[ "${T5_BUILD_JOBS:-4}" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid T5_BUILD_JOBS' >&2; exit 2; }

# Validate the exact git-archive deployment before creating build outputs.
python3 - <<'PY'
import hashlib, json, os, re
from pathlib import Path, PurePosixPath
root = Path(os.environ['TASK_ROOT'])
manifest = json.loads((root / 'DEPLOYMENT_MANIFEST.json').read_text(encoding='utf-8'))
commit, prefix = manifest['commit'], manifest['prefix']
if not re.fullmatch(r'[0-9a-f]{40}', commit):
    raise SystemExit('Manifest requires an exact commit')
if root.name != prefix or prefix != 't5_qkv_' + commit[:12]:
    raise SystemExit('Deployment name/manifest identity mismatch')
seen = set()
for record in manifest['files']:
    member = PurePosixPath(record['path'])
    if member.is_absolute() or '..' in member.parts:
        raise SystemExit('Unsafe deployment member')
    relative = member.relative_to(prefix)
    if not relative.parts or str(relative) in seen:
        raise SystemExit('Invalid or duplicate deployment member')
    seen.add(str(relative))
    path = (root / str(relative)).resolve(strict=True)
    if not path.is_relative_to(root) or not path.is_file():
        raise SystemExit('Deployment member escaped the source directory')
    data = path.read_bytes()
    if len(data) != record['bytes'] or hashlib.sha256(data).hexdigest() != record['sha256']:
        raise SystemExit('Deployment file mismatch: ' + str(relative))
if not seen:
    raise SystemExit('Empty deployment manifest')
print('Verified exact source deployment:', commit, 'files:', len(seen))
PY

cd "$TASK_ROOT"
for target in build "$T5_OPP_ROOT"; do
  [[ ! -e "$target" && ! -L "$target" ]] || {
    echo "Preserve previous native output; refusing existing path: $target" >&2; exit 2;
  }
done
mkdir -p artifacts/validation
for target in artifacts/validation/native_build.log artifacts/validation/native_build.exit; do
  [[ ! -e "$target" && ! -L "$target" ]] || { echo "Preserve existing evidence: $target" >&2; exit 2; }
done
mkdir artifacts/validation/native_build.lock
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'rc=$?; (set -o noclobber; printf "%s\n" "$rc" > artifacts/validation/native_build.exit); exit "$rc"' EXIT
set -o noclobber
exec > artifacts/validation/native_build.log 2>&1
set +o noclobber
printf 'Compile-only deployment: %s\nPrivate OPP: %s\nCANN: %s\n' "$TASK_ROOT" "$T5_OPP_ROOT" "$ASCEND_HOME_PATH"
sha256sum -- "$WRAPPER_PATH" DEPLOYMENT_MANIFEST.json
python3 -c 'import sys; print("Build interpreter:", sys.executable, sys.version)'
cmake --version
c++ --version
python3 tools/preflight.py --static
python3 tools/check_cache_policy.py --cann-root "$ASCEND_HOME_PATH"
python3 tools/fingerprint.py --output artifacts/validation/native_source_before.json

# These commands follow scripts/build.sh, omitting its torch-only binding step.
mkdir build
mkdir -p -- "$(dirname -- "$T5_OPP_ROOT")"
mkdir -- "$T5_OPP_ROOT"
msopgen gen -i "$TASK_ROOT/op_project.json" -c ai_core-Ascend910_9382 -lan cpp \
  -out "$TASK_ROOT/build/aclnn" -f aclnn
cp -a "$TASK_ROOT/op_host/." "$TASK_ROOT/build/aclnn/op_host/"
cp -a "$TASK_ROOT/op_kernel/." "$TASK_ROOT/build/aclnn/op_kernel/"
cp -a "$TASK_ROOT/common" "$TASK_ROOT/build/aclnn/common"
python3 tools/configure_generated.py "$TASK_ROOT/build/aclnn"
( cd "$TASK_ROOT/build/aclnn"; bash -n build.sh; bash build.sh )
mapfile -t packages < <(find "$TASK_ROOT/build/aclnn/build_out" -maxdepth 1 -name '*.run' -type f)
[[ ${#packages[@]} == 1 ]] || { echo 'Expected exactly one compiled ACLNN package'; exit 2; }
package_copy="$TASK_ROOT/artifacts/$(basename -- "${packages[0]}")"
[[ ! -e "$package_copy" && ! -L "$package_copy" ]] || { echo 'Preserve existing package evidence'; exit 2; }
cp -- "${packages[0]}" "$package_copy"
sha256sum -- "$package_copy" > artifacts/validation/native_package.sha256
bash "${packages[0]}" --quiet --install-path="$T5_OPP_ROOT"
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv${ASCEND_CUSTOM_OPP_PATH:+:$ASCEND_CUSTOM_OPP_PATH}"
cmake -S "$TASK_ROOT/direct" -B "$TASK_ROOT/build/direct" \
  -DASCEND_CANN_PACKAGE_PATH="$ASCEND_HOME_PATH" -DASCEND_COMPUTE_UNIT=ascend910_93 \
  -DSOC_VERSION=Ascend910_9382 -DCMAKE_BUILD_TYPE=Release -DRUN_MODE=npu
cmake --build "$TASK_ROOT/build/direct" -j "${T5_BUILD_JOBS:-4}"
cmake -S "$TASK_ROOT/examples" -B "$TASK_ROOT/build/examples" \
  -DCANN_ROOT="$ASCEND_HOME_PATH" -DT5_OPP_ROOT="$T5_OPP_ROOT"
cmake --build "$TASK_ROOT/build/examples" -j "${T5_BUILD_JOBS:-4}"
python3 tools/fingerprint.py --output artifacts/validation/native_source_after.json
python3 - <<'PY'
import hashlib, json, os
from pathlib import Path
root, opp = Path(os.environ['TASK_ROOT']), Path(os.environ['T5_OPP_ROOT'])
commit = json.loads((root / 'DEPLOYMENT_MANIFEST.json').read_text())['commit']
for name in ('native_source_before.json', 'native_source_after.json'):
    source = json.loads((root / 'artifacts/validation' / name).read_text())
    if source['source_commit'] != commit or source['worktree_status'] != 'archive verified':
        raise SystemExit('Source identity changed during native build: ' + name)
files = [root / 'build/direct/lib/libt5_direct.so', root / 'build/examples/t5_example']
files += sorted(p for p in opp.rglob('*') if p.is_file() and p.suffix in {'.so', '.o', '.json', '.h'})
records = []
for path in files:
    data = path.read_bytes()
    records.append({'path': str(path), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
report = {'status': 'compiled_native_only', 'npu_executed': False, 'torch_binding_built': False,
          'source_commit': commit,
          'private_opp': str(opp), 'files': records}
with (root / 'artifacts/validation/native_binary_manifest.json').open('x', encoding='utf-8') as handle:
    json.dump(report, handle, indent=2)
    handle.write('\n')
PY
printf '%s\n' 'Native package, direct launcher and C++ example compiled; no example or NPU test executed.'
