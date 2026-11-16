#!/usr/bin/env bash
# Child setup must exit and write setup.exit before either binding starts.
set -euo pipefail
installer=/tmp/t5_sources_20261116/prepare_offline_python_v3_corrected_20261116.sh
binding=/tmp/t5_sources_20261116/build_binding_20261116.sh
task_venv=/workspace/t5_qkv_tasks/venv_t5_py312_torch210_20261116_offline_v3
run_lock=/workspace/t5_qkv_tasks/offline_v3_and_bindings_corrected_20261116.lock
run_exit=/workspace/t5_qkv_tasks/offline_v3_and_bindings_corrected_20261116.exit
[[ ! -e "$run_exit" && ! -L "$run_exit" ]] || { echo 'Preserve existing pipeline exit receipt'; exit 2; }
# Atomic, single-use lock. Retain it after success/failure to reject duplicate launches.
mkdir "$run_lock" || { echo 'Pipeline is already running or has run; preserve its lock'; exit 2; }
finish_pipeline() {
    rc=$?
    trap - EXIT
    if ! (set -o noclobber; printf '%s\n' "$rc" > "$run_exit"); then
        echo 'Failed to record pipeline exit without overwriting evidence' >&2
        exit 1
    fi
    exit "$rc"
}
trap finish_pipeline EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
(set -o noclobber; printf '%s\n' "$$" > "$run_lock/pid")
printf '%s\n' 'c1635b687d7f01f17047086e17e048d640fd2e69f7a32999c19a20e6aef0d3ff  /tmp/t5_sources_20261116/prepare_offline_python_v3_corrected_20261116.sh' \
 '41115edbb8eea50ae6fa83158c8b2868c3f0263d4cbae7ba38b33510ad335170  /tmp/t5_sources_20261116/build_binding_20261116.sh' | sha256sum --check --strict
for script in "$installer" "$binding"; do
    /usr/local/python3.12.13/bin/python -I - "$script" <<'PY'
import sys
from pathlib import Path
raw = Path(sys.argv[1]).read_bytes()
assert b'\r' not in raw and not raw.startswith(b'\xef\xbb\xbf'), 'Expected LF/no-BOM shell script'
raw.decode('utf-8')
PY
    bash -n "$script"
done
bash "$installer"
/usr/local/python3.12.13/bin/python -I - "$task_venv" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
assert (root/'setup.exit').read_bytes() == b'0\n', 'Setup EXIT receipt is not a completed success'
receipt = json.loads((root/'metadata_verified.json').read_text())
assert receipt['status'] == 'pinned_metadata_verified_no_device_execution'
assert receipt['npu_executed'] is False and len(receipt['all_packages']) == 14
PY
set +u
source /usr/local/Ascend/cann/set_env.sh
set -u
bash "$binding" /workspace/t5_qkv_tasks/t5_qkv_f52671207769 "$task_venv"
bash "$binding" /workspace/t5_qkv_tasks/t5_qkv_a2013d56db4f "$task_venv"
printf '%s\n' 'Offline v3 and both bindings completed; no NPU tests executed.'
