#!/usr/bin/env bash
# Build only a changed Python binding after proving native source is unchanged.
set -euo pipefail
TASK_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$TASK_ROOT"
: "${T5_NATIVE_BASELINE:?Preserved successful native build checkout}"
mkdir -p reports artifacts
trap 'echo "$?" > reports/build_binding.exit' EXIT
exec > reports/build_binding.log 2>&1
python tools/preflight.py --static
[[ ! -e build ]] || { echo 'Use a fresh checkout'; exit 2; }
for directory in common op_host op_kernel direct examples; do diff -qr "$T5_NATIVE_BASELINE/$directory" "$directory"; done
mkdir -p build/direct/lib build/examples
cp "$T5_NATIVE_BASELINE/build/direct/lib/libt5_direct.so" build/direct/lib/
cp "$T5_NATIVE_BASELINE/build/examples/t5_example" build/examples/
cp "$T5_NATIVE_BASELINE/artifacts/custom_opp_openEuler_aarch64.run" artifacts/
cp "$T5_NATIVE_BASELINE/DEPLOYMENT_MANIFEST.json" artifacts/native_source_manifest.json
sha256sum build/direct/lib/libt5_direct.so build/examples/t5_example artifacts/*.run > artifacts/reused_binary.sha256
MAX_JOBS=4 python setup.py build_ext --inplace
python -c 'import torch, torch_npu, _t5_qkv; print("extension import passed without device initialization")'
python tools/fingerprint.py --output artifacts/build_manifest.json
