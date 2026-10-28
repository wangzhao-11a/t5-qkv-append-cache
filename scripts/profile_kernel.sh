#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=/workspace/t5_qkv_tasks/t5_qkv_c5f66586832a
cd "$TASK_ROOT"
trap 'echo "$?" > reports/profile_kernel_v2.exit' EXIT
exec > reports/profile_kernel_v2.log 2>&1
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
set -u
export PATH=/workspace/vasc031_a3/bin:$PATH
export T5_TASK_ROOT="$TASK_ROOT"
export T5_OPP_ROOT=/root/.local/t5_qkv_c5f66586832a
export ASCEND_RT_VISIBLE_DEVICES=1
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv${ASCEND_CUSTOM_OPP_PATH:+:$ASCEND_CUSTOM_OPP_PATH}"
export PYTHONPATH="/workspace/t5_qkv_tasks/t5_qkv_f0ea7ebdbb46/python_deps:$TASK_ROOT:$TASK_ROOT/reference${PYTHONPATH:+:$PYTHONPATH}"
[[ ! -e artifacts/profile_v2 ]] || exit 2
npu-smi info > reports/device_before_profile.txt
grep -q 'No running processes found' reports/device_before_profile.txt || exit 2
msprof --application='python /tmp/t5_profile_workload_v2.py' --output=artifacts/profile_v2 \
  --runtime-api=on --aic-metrics=Memory --task-time=on --ai-core=on
[[ $(grep -c 'profile workload correctness passed' reports/profile_kernel_v2.log) == 3 ]] || { echo 'Profiler exit code does not prove application success'; exit 2; }
