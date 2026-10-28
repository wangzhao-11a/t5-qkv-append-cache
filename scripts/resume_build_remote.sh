#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=/workspace/t5_qkv_tasks/t5_qkv_2c8640a3256c
cd "$TASK_ROOT"
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
set -u
export PATH=/workspace/vasc031_a3/bin:$PATH
export T5_OPP_ROOT=/root/.local/t5_qkv_2c8640a3256c
export ASCEND_RT_VISIBLE_DEVICES=1
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv${ASCEND_CUSTOM_OPP_PATH:+:$ASCEND_CUSTOM_OPP_PATH}"
exec > reports/build_resume.log 2>&1
# The successful compiled package is kept; no repeat of ACLNN compilation.
mapfile -t packages < <(find "$TASK_ROOT/build/aclnn/build_out" -maxdepth 1 -name '*.run' -type f)
[[ ${#packages[@]} -eq 1 ]] || { echo 'unexpected final package count'; exit 2; }
mkdir -p artifacts "$T5_OPP_ROOT"
cp -- "${packages[0]}" artifacts/
sha256sum "${packages[0]}" > artifacts/aclnn_package.sha256
bash "${packages[0]}" --quiet --install-path="$T5_OPP_ROOT"
cmake -S direct -B build/direct -DASCEND_CANN_PACKAGE_PATH="$ASCEND_HOME_PATH" -DASCEND_COMPUTE_UNIT=ascend910_93
cmake --build build/direct -j 4
MAX_JOBS=4 python setup.py build_ext --inplace
cmake -S examples -B build/examples -DCANN_ROOT="$ASCEND_HOME_PATH" -DT5_OPP_ROOT="$T5_OPP_ROOT"
cmake --build build/examples -j 4
python tools/fingerprint.py --output artifacts/build_manifest.json
