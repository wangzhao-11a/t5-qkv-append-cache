#!/usr/bin/env bash
# Source from a deployed phase script; never infer a candidate from an old hash.
TASK_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$TASK_ROOT"
export TASK_ROOT
export T5_OPP_ROOT="$HOME/.local/$(basename -- "$TASK_ROOT")"
python3 - <<'PY'
import hashlib, json, os
from pathlib import Path
root = Path(os.environ['TASK_ROOT'])
m = json.loads((root / 'DEPLOYMENT_MANIFEST.json').read_text())
assert root.name == m['prefix'] == 't5_qkv_' + m['commit'][:12], 'Deployment identity mismatch'
for record in m['files']:
    relative = Path(record['path']).relative_to(m['prefix'])
    data = (root / relative).read_bytes()
    assert len(data) == record['bytes'] and hashlib.sha256(data).hexdigest() == record['sha256'], relative
print('Verified deployment', m['commit'])
PY

phase_begin() {
  local phase="$1" prerequisite="${2:-}"
  mkdir -p artifacts/validation
  if [[ -n "$prerequisite" ]]; then
    [[ -f "artifacts/validation/$prerequisite.exit" ]] &&
      [[ $(cat "artifacts/validation/$prerequisite.exit") == 0 ]] || {
        echo "Required successful stage: $prerequisite" >&2; exit 2;
      }
  fi
  [[ ! -e "artifacts/validation/$phase.log" && ! -e "artifacts/validation/$phase.exit" ]] || {
    echo "Preserve previous $phase evidence; use a fresh deployment" >&2; exit 2;
  }
  # mkdir arbitrates competing launches before either can truncate a log.
  mkdir "artifacts/validation/$phase.lock" || exit 2
  T5_PHASE="$phase"
  trap 'rc=$?; (set -o noclobber; printf "%s\n" "$rc" > "artifacts/validation/$T5_PHASE.exit"); exit "$rc"' EXIT
  set -o noclobber
  exec > "artifacts/validation/$phase.log" 2>&1
  set +o noclobber
}

phase_device_inventory() {
  local scope="${1:-${T5_FUNCTIONAL_DEVICE_SCOPE:-selected}}"
  python tools/preflight.py --require-soc Ascend910_9382 --output "artifacts/validation/environment_${T5_PHASE}.json"
  npu-smi info > "artifacts/validation/device_${T5_PHASE}.txt"
  if [[ "$scope" == board ]]; then
    # Timed comparisons retain the original isolated-board requirement.
    local idle_checks=0 attempt
    for attempt in $(seq 1 90); do
      npu-smi info > "artifacts/validation/device_${T5_PHASE}_idle_probe.txt"
      if grep -q 'No running processes found' "artifacts/validation/device_${T5_PHASE}_idle_probe.txt"; then
        idle_checks=$((idle_checks+1))
      else
        idle_checks=0
      fi
      printf 'Board idle check %s: %s consecutive\n' "$attempt" "$idle_checks"
      if [[ "$idle_checks" == 3 ]]; then break; fi
      sleep 10
    done
    [[ "$idle_checks" == 3 ]] || { echo 'Performance requires an idle board'; exit 2; }
  elif [[ "$scope" == selected && "${ASCEND_RT_VISIBLE_DEVICES:-}" == 1 ]]; then
    # Verified mapping on this 910_9382 container: physical 1 = card 0/chip 1.
    # Query the official per-chip process list, not a guessed text-table column.
    npu-smi info -t proc-mem -i 0 -c 1 > "artifacts/validation/selected_device_${T5_PHASE}.txt"
    grep -Eq '^[[:space:]]*No process in device\.[[:space:]]*$' \
      "artifacts/validation/selected_device_${T5_PHASE}.txt" || {
      echo 'Selected physical device 1 occupancy needs review'; exit 2;
    }
  else
    echo 'Unknown occupancy scope or device mapping'; exit 2
  fi
}
