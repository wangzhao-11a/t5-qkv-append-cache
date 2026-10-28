"""Small workload for the official msprof tool; not an acceptance timer."""
import json
import os
from pathlib import Path
import sys
ROOT=Path(os.environ['T5_TASK_ROOT']).resolve()
assert (ROOT/'solution.py').is_file() and (ROOT/'reference/case.json').is_file(), 'Invalid profile project root'
sys.path[:0]=[str(ROOT),str(ROOT/'reference')]
import torch,torch_npu
import solution,generate_data,golden,verify
torch.npu.set_device(0)
cases=json.loads((ROOT/'reference/case.json').read_text())
for number in ('001','006','007'):
    c=next(c for c in cases if c['case_name']==f'T5SplitQkvAppendCache_{number}_float16_random')
    arrays=generate_data.generate(c)
    attrs={a['name']:a['value'] for a in c['attr_desc']}
    xs=verify.device_inputs(c,arrays,'npu:0')
    for _ in range(20):out=solution.run(xs,attrs)
    torch.npu.synchronize()
    verify.compare(c,arrays,out,golden.calculate(arrays,attrs))
    print(c['case_name'],'profile workload correctness passed',flush=True)
    del out,xs,arrays
