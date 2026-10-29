#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/phase_common.sh"
phase_begin performance_phase correctness_phase
[[ $(cat artifacts/validation/correctness_phase.exit) == 0 ]] || exit 2
[[ ! -e artifacts/validation/performance.json ]] || { echo 'Preserve previous performance evidence'; exit 2; }
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
set -u
export PATH=/workspace/vasc031_a3/bin:$PATH
export ASCEND_RT_VISIBLE_DEVICES=1
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv${ASCEND_CUSTOM_OPP_PATH:+:$ASCEND_CUSTOM_OPP_PATH}"
export PYTHONPATH="/workspace/t5_qkv_tasks/t5_qkv_f0ea7ebdbb46/python_deps:$TASK_ROOT:$TASK_ROOT/reference${PYTHONPATH:+:$PYTHONPATH}"
phase_device_inventory
npu-smi info > artifacts/validation/device_before_performance.txt
grep -q 'No running processes found' artifacts/validation/device_before_performance.txt || exit 2
python reference/benchmark.py --solution-file "$TASK_ROOT/solution.py" --report artifacts/validation/performance.json > artifacts/validation/performance.log 2>&1 || true
python reference/check_performance.py --report artifacts/validation/performance.json --output artifacts/validation/performance_acceptance.json || true
# This run answers a separate question: controlled ratio against allocating views/cat.
python tests/compare_baseline.py --report artifacts/validation/baseline_comparison.json > artifacts/validation/baseline_comparison.log 2>&1
python tools/preflight.py --output artifacts/validation/environment_after.json > artifacts/validation/environment_after.log 2>&1
python tools/fingerprint.py --output artifacts/tested_build_manifest.json
python tools/check_coverage.py --reports artifacts/validation
