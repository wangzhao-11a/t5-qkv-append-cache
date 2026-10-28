#!/usr/bin/env bash
set -u
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
export ASCEND_RT_VISIBLE_DEVICES=1
/workspace/vasc031_a3/bin/python - <<'PY'
import sys,json,torch,torch_npu,importlib.util
print(json.dumps({'python':sys.version,'executable':sys.executable,'torch':torch.__version__,
 'torch_npu':torch_npu.__version__,'numpy_spec':str(importlib.util.find_spec('numpy')),
 'ml_dtypes_available':importlib.util.find_spec('ml_dtypes') is not None},indent=2))
PY
printf '%s\n' '=== generator help ==='
msopgen gen -h | head -n 65
