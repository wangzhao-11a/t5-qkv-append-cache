#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=/workspace/t5_qkv_tasks/t5_qkv_916c7d793f9e
cd "$TASK_ROOT"
mkdir -p artifacts/validation
trap 'echo "$?" > artifacts/validation/correctness_phase.exit' EXIT
exec > artifacts/validation/correctness_phase.log 2>&1
[[ $(cat artifacts/validation/smoke_phase.exit) == 0 ]] || exit 2
[[ ! -e artifacts/validation/public_accuracy.json ]] || { echo 'Preserve previous device evidence'; exit 2; }
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
set -u
export PATH=/workspace/vasc031_a3/bin:$PATH
export T5_OPP_ROOT=/root/.local/t5_qkv_916c7d793f9e
export ASCEND_RT_VISIBLE_DEVICES=1
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv${ASCEND_CUSTOM_OPP_PATH:+:$ASCEND_CUSTOM_OPP_PATH}"
export PYTHONPATH="/workspace/t5_qkv_tasks/t5_qkv_f0ea7ebdbb46/python_deps:$TASK_ROOT:$TASK_ROOT/reference${PYTHONPATH:+:$PYTHONPATH}"
build/examples/t5_example --negative > artifacts/validation/aclnn_invalid_metadata.log 2>&1
python reference/verify.py --solution-file "$TASK_ROOT/solution.py" --report artifacts/validation/public_accuracy.json > artifacts/validation/public_accuracy.log 2>&1
python tests/npu_suite.py --group accuracy --report artifacts/validation/extended_accuracy.json > artifacts/validation/extended_accuracy.log 2>&1
python tests/npu_suite.py --group engineering --report artifacts/validation/engineering.json > artifacts/validation/engineering.log 2>&1
python tests/npu_suite.py --group memory --report artifacts/validation/memory.json > artifacts/validation/memory.log 2>&1
