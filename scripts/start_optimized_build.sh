#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/phase_common.sh"
[[ ! -e "$T5_OPP_ROOT" && ! -e build ]] || { echo 'Preserve existing baseline'; exit 2; }
phase_begin build_full
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
set -u
export PATH=/workspace/vasc031_a3/bin:$PATH
export ASCEND_RT_VISIBLE_DEVICES=1
export MAX_JOBS=4 T5_BUILD_JOBS=4
bash scripts/build.sh
