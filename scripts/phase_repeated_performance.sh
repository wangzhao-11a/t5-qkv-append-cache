#!/usr/bin/env bash
# Five fresh-process frozen runs; stop at the first failure, never retry to pass.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/phase_common.sh"
phase_begin repeated_performance_phase performance_phase
: "${ASCEND_HOME_PATH:?Load the verified CANN 9.1.0 environment first}"
: "${ASCEND_RT_VISIBLE_DEVICES:?Select the assigned single runtime device}"
: "${T5_PHYSICAL_DEVICE:?Record the verified physical device mapping}"
: "${T5_DEVICE_CONFIRMED:?Check ports, worker processes and assigned device first}"
[[ "$T5_DEVICE_CONFIRMED" == 1 ]] || exit 2
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv${ASCEND_CUSTOM_OPP_PATH:+:$ASCEND_CUSTOM_OPP_PATH}"
export PYTHONPATH="$TASK_ROOT:$TASK_ROOT/reference${PYTHONPATH:+:$PYTHONPATH}"
python tools/check_coverage.py --reports artifacts/validation > artifacts/validation/repeated_coverage_before.log
phase_device_inventory board
mkdir artifacts/validation/repeated_performance
for run in 1 2 3 4 5; do
  prefix="artifacts/validation/repeated_performance/run_${run}"
  npu-smi info > "${prefix}_device_before.txt"
  grep -q 'No running processes found' "${prefix}_device_before.txt" || exit 2
  python tools/preflight.py --require-soc Ascend910_9382 --output "${prefix}_environment.json" > "${prefix}_environment.log"
  rc=0
  python reference/benchmark.py --solution-file "$TASK_ROOT/solution.py" \
    --report "${prefix}.json" > "${prefix}.log" 2>&1 || rc=$?
  printf '%s\n' "$rc" > "${prefix}.exit"
  npu-smi info > "${prefix}_device_after.txt"
  # Each subprocess must complete all ten cases under the untouched protocol.
  # A failed run remains failed; do not continue hoping for a favorable layout.
  [[ "$rc" == 0 ]] || exit "$rc"
  grep -q 'No running processes found' "${prefix}_device_after.txt" || exit 2
  python reference/check_performance.py --report "${prefix}.json" \
    --output "${prefix}_acceptance.json" > "${prefix}_acceptance.log" 2>&1
done
python tools/fingerprint.py --output artifacts/validation/repeated_performance/source_after.json
printf '%s\n' 'All five independent frozen runs passed. Results are separate from address diagnostics.'
