#!/usr/bin/env bash
# Reuse only the verified, unchanged operator package; build all changed source.
set -euo pipefail
TASK_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$TASK_ROOT"
: "${T5_ACLNN_BASELINE:?Path to the preserved package source checkout}"
: "${T5_OPP_ROOT:?Path to the private installed package}"
: "${ASCEND_HOME_PATH:?Source the CANN environment}"
mkdir -p reports artifacts
trap 'echo "$?" > reports/build_clean.exit' EXIT
exec > reports/build_clean.log 2>&1
python tools/preflight.py --static
for directory in common op_host op_kernel; do diff -qr "$T5_ACLNN_BASELINE/$directory" "$directory"; done
[[ ! -e build/direct ]] || { echo 'Refusing to mix build configurations'; exit 2; }
cp "$T5_ACLNN_BASELINE/artifacts/custom_opp_openEuler_aarch64.run" artifacts/
sha256sum artifacts/*.run > artifacts/aclnn_package.sha256
cp "$T5_ACLNN_BASELINE/DEPLOYMENT_MANIFEST.json" artifacts/aclnn_source_manifest.json
cmake -S direct -B build/direct -DASCEND_CANN_PACKAGE_PATH="$ASCEND_HOME_PATH" \
  -DASCEND_COMPUTE_UNIT=ascend910_93 -DSOC_VERSION=Ascend910_9382 -DCMAKE_BUILD_TYPE=Release
cmake --build build/direct -j "${T5_BUILD_JOBS:-4}"
MAX_JOBS=4 python setup.py build_ext --inplace
cmake -S examples -B build/examples -DCANN_ROOT="$ASCEND_HOME_PATH" -DT5_OPP_ROOT="$T5_OPP_ROOT"
cmake --build build/examples -j 4
python tools/fingerprint.py --output artifacts/build_manifest.json
