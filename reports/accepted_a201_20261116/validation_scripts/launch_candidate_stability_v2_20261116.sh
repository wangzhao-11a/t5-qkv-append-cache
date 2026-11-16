#!/usr/bin/env bash
# Complete the existing allocating-baseline coverage, then run the existing five-process gate.
set -euo pipefail
task_root=/workspace/t5_qkv_tasks/t5_qkv_a2013d56db4f
task_venv=/workspace/t5_qkv_tasks/venv_t5_py312_torch210_20261116_offline_v3
task_exit=/workspace/t5_qkv_tasks/candidate_stability_20261116.exit
[[ ! -e "$task_exit" ]] || exit 2
mkdir /workspace/t5_qkv_tasks/candidate_stability_20261116.lock
trap 'rc=$?; (set -o noclobber; printf "%s\n" "$rc" > "$task_exit"); exit "$rc"' EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
printf '%s\n' "$$" > /workspace/t5_qkv_tasks/candidate_stability_20261116.lock/pid
[[ $(cat "$task_root/artifacts/validation/performance_phase.exit") == 0 ]] || exit 2
[[ $(cat "$task_venv/setup.exit") == 0 ]] || exit 2
set +u
source /usr/local/Ascend/cann/set_env.sh
set -u
export PATH="$task_venv/bin:$ASCEND_HOME_PATH/bin:$ASCEND_HOME_PATH/compiler/ccec_compiler/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export VIRTUAL_ENV="$task_venv" PYTHONNOUSERSITE=1 PYTHONDONTWRITEBYTECODE=1
unset PYTHONHOME PYTHONPATH LD_PRELOAD
export ASCEND_RT_VISIBLE_DEVICES=1 T5_PHYSICAL_DEVICE=3 T5_DEVICE_CONFIRMED=1
export T5_OPP_ROOT=/root/.local/t5_qkv_a2013d56db4f
export PYTHONPATH="$task_root:$task_root/reference"
export LD_LIBRARY_PATH="$task_root/build/direct/lib:$T5_OPP_ROOT/vendors/t5qkv/op_api/lib:$task_venv/lib/python3.12/site-packages/torch/lib:$task_venv/lib/python3.12/site-packages/torch_npu/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
task_identity() {
 "$task_venv/bin/python" -I - "$task_root" <<'PY'
import hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1]);folder=root/'artifacts/validation'
binding=json.loads((folder/'binding_import.json').read_text())
assert binding['sha256']=='77b2943dab7f139c8a947ee710db6e841f8a4df08d4a41969ea2c88094db39a6'
assert hashlib.sha256(Path(binding['extension']).read_bytes()).hexdigest()==binding['sha256']
manifest=json.loads((folder/'native_binary_manifest.json').read_text())
for r in manifest['files']:
 data=Path(r['path']).read_bytes();assert len(data)==r['bytes'] and hashlib.sha256(data).hexdigest()==r['sha256']
assert json.loads((folder/'fixed_once_20261116/identity_after.json').read_text())['extension_sha256']==binding['sha256']
print('Verified candidate binding and native bytes unchanged')
PY
}
task_identity
[[ ! -e "$task_root/artifacts/validation/coverage_acceptance.json" ]] || { echo 'Preserve existing coverage receipt'; exit 2; }
[[ ! -e "$task_root/artifacts/validation/stability_environment_after.json" ]] || exit 2
(
 source "$task_root/scripts/phase_common.sh"
 phase_begin baseline_comparison_phase performance_phase
 task_comparison_finish() {
  task_rc=$?
  trap - EXIT
  set +e
  npu-smi info > artifacts/validation/baseline_comparison_device_after.txt
  task_smi_rc=$?
  grep -q 'No running processes found' artifacts/validation/baseline_comparison_device_after.txt
  task_clear_rc=$?
  python tools/preflight.py --output artifacts/validation/baseline_comparison_environment_after.json
  task_inventory_rc=$?
  python - <<'PY'
import json
from pathlib import Path
p=Path('artifacts/validation')
a=json.loads((p/'environment_baseline_comparison_phase.json').read_text())['inventory']
b=json.loads((p/'baseline_comparison_environment_after.json').read_text())['inventory']
assert a['listening_tcp_ports']==b['listening_tcp_ports']
PY
  task_ports_rc=$?
  if [[ "$task_rc" == 0 && ( "$task_smi_rc" != 0 || "$task_clear_rc" != 0 || "$task_inventory_rc" != 0 || "$task_ports_rc" != 0 ) ]]; then task_rc=2; fi
  (set -o noclobber; printf '%s\n' "$task_rc" > "artifacts/validation/$T5_PHASE.exit")
  exit "$task_rc"
 }
 trap task_comparison_finish EXIT
 export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv"
 [[ ! -e artifacts/validation/baseline_comparison.json && ! -e artifacts/validation/baseline_comparison.log ]] || exit 2
 phase_device_inventory board
 set -o noclobber
 python tests/compare_baseline.py --report artifacts/validation/baseline_comparison.json > artifacts/validation/baseline_comparison.log 2>&1
 )
# The tracked repeat script prepends this exact private OPP itself.
unset ASCEND_CUSTOM_OPP_PATH
bash -n "$task_root/scripts/phase_repeated_performance.sh"
rc=0
bash "$task_root/scripts/phase_repeated_performance.sh" || rc=$?
task_identity
(
 cd "$task_root"
 python tools/preflight.py --output artifacts/validation/stability_environment_after.json
 python - <<'PY'
import json
from pathlib import Path
p=Path('artifacts/validation')
before=json.loads((p/'environment_performance_phase.json').read_text())['inventory']
after=json.loads((p/'stability_environment_after.json').read_text())['inventory']
assert before['listening_tcp_ports']==after['listening_tcp_ports']
print('Listening ports unchanged; process inventories preserved')
PY
)
exit "$rc"
