#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=/workspace/t5_qkv_tasks/t5_qkv_916c7d793f9e
cd "$TASK_ROOT"
trap 'echo "$?" > reports/smoke_phase.exit' EXIT
exec > reports/smoke_phase.log 2>&1
[[ ! -e reports/cpp_smoke.log ]] || { echo 'Preserve previous smoke evidence'; exit 2; }
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
set -u
export PATH=/workspace/vasc031_a3/bin:$PATH
export T5_OPP_ROOT=/root/.local/t5_qkv_916c7d793f9e
export ASCEND_RT_VISIBLE_DEVICES=1
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv${ASCEND_CUSTOM_OPP_PATH:+:$ASCEND_CUSTOM_OPP_PATH}"
export PYTHONPATH="/workspace/t5_qkv_tasks/t5_qkv_f0ea7ebdbb46/python_deps:$TASK_ROOT:$TASK_ROOT/reference${PYTHONPATH:+:$PYTHONPATH}"
python tools/preflight.py --output reports/environment_before.json
npu-smi info > reports/device_before.txt
grep -q 'No running processes found' reports/device_before.txt || { echo 'Device occupancy needs review'; exit 2; }
python - <<'PY'
import sys,torch,torch_npu,numpy,ml_dtypes,json
assert sys.version_info[:3]==(3,12,13)
assert torch.__version__=='2.10.0+cpu'
assert torch_npu.version.git_version.startswith('5dd8ef3')
assert numpy.__version__=='2.2.6' and ml_dtypes.__version__=='0.6.0'
print('Verified Python/package versions',torch_npu.__version__,torch_npu.version.git_version)
PY
build/examples/t5_example > reports/cpp_smoke.log 2>&1
build/examples/t5_example --bf16 >> reports/cpp_smoke.log 2>&1
python - <<'PY' > reports/python_smoke.log 2>&1
import json,torch,torch_npu,numpy as np
import solution,generate_data,golden,verify
from pathlib import Path
torch.npu.set_device(0)
cases=json.loads(Path('reference/case.json').read_text())
records=[]
for dtype in ('float16','bfloat16'):
    case=next(c for c in cases if c['input_desc'][0]['data_type']==dtype)
    arrays=generate_data.generate(case)
    attrs={a['name']:a['value'] for a in case['attr_desc']}
    inputs=verify.device_inputs(case,arrays,'npu:0')
    expected=golden.calculate(arrays,attrs)
    for entry in ('run','run_direct'):
        fn=getattr(solution,entry)
        for repeat in range(20):
            out=fn(inputs,attrs);torch.npu.synchronize()
            verify.validate_ownership(inputs,out)
            verify.compare(case,arrays,out,expected)
        records.append(dict(case_name=case['case_name'],entry=entry,repeats=20,status='passed'))
        print(records[-1],flush=True)
Path('reports/smoke_stability.json').write_text(json.dumps(dict(status='passed',npu_executed=True,records=records),indent=2)+'\n')
PY
