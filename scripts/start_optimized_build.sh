#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=/workspace/t5_qkv_tasks/t5_qkv_c9decf212667
cd "$TASK_ROOT"
mkdir -p artifacts/validation
trap 'echo "$?" > artifacts/validation/build_full.exit' EXIT
exec > artifacts/validation/build_full.log 2>&1
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
set -u
export PATH=/workspace/vasc031_a3/bin:$PATH
export T5_OPP_ROOT=/root/.local/t5_qkv_c9decf212667
export ASCEND_RT_VISIBLE_DEVICES=1
export MAX_JOBS=4 T5_BUILD_JOBS=4
[[ ! -e "$T5_OPP_ROOT" && ! -e build ]] || { echo 'Preserve existing baseline'; exit 2; }
bash scripts/build.sh
