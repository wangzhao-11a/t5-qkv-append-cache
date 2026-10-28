#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=/workspace/t5_qkv_tasks/t5_qkv_2c8640a3256c
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
set -u
export ASCEND_RT_VISIBLE_DEVICES=1
/workspace/vasc031_a3/bin/python - <<'PY'
import json,importlib.metadata as m,torch_npu.version as v
print(json.dumps({'numpy':m.version('numpy'),'ml_dtypes':m.version('ml_dtypes'),
                  'torch_npu_git':getattr(v,'git_version','unknown')},indent=2))
PY
# Isolated target; never replace libraries in the existing venv/container.
timeout 240 /workspace/vasc031_a3/bin/python -m pip install --timeout 20 --retries 1 --index-url https://pypi.org/simple \
  --target "$TASK_ROOT/python_deps" --no-deps 'numpy==2.2.6' 'ml_dtypes==0.6.0' \
  > "$TASK_ROOT/reports/dependencies.log" 2>&1
