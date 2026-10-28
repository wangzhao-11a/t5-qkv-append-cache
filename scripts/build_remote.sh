#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=/workspace/t5_qkv_tasks/t5_qkv_2c8640a3256c
cd "$TASK_ROOT"
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
set -u
export PATH=/usr/local/python3.12.13/bin:$PATH
export T5_OPP_ROOT=/root/.local/t5_qkv_2c8640a3256c
export T5_BUILD_JOBS=4
mkdir -p reports
printf '%s\n' '=== optional existing Python environments, read-only ==='
for interpreter in /workspace/ms_a3/bin/python /workspace/vasc031_a3/bin/python; do
  if [[ -x "$interpreter" ]]; then
    "$interpreter" -c 'import sys,importlib.metadata as m; print(sys.executable,sys.version); print({n:m.version(n) for n in ("torch","torch_npu","numpy")})' || true
  fi
done
printf '%s\n' '=== compile only; no device kernel launches ==='
bash scripts/build.sh > reports/build.log 2>&1
