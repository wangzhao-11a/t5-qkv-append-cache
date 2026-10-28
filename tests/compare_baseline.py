"""Supplemental same-device baseline ratios; does not replace fixed limits."""
import argparse
import json
from pathlib import Path
import sys
import traceback

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT),str(ROOT/'reference')]

def execute(report):
    import numpy as np
    import torch,torch_npu
    import benchmark,generate_data,golden,verify,solution
    torch.npu.set_device(0)
    cases=json.loads((ROOT/'reference/case.json').read_text(encoding='utf-8'))
    for case in (c for c in cases if c.get('performance')):
        arrays=generate_data.generate(case);attributes={a['name']:a['value'] for a in case['attr_desc']}
        inputs=verify.device_inputs(case,arrays,'npu:0');b,h,l,d=inputs[1].shape
        def baseline():
            parts=inputs[0].reshape(b,3,h,d)
            q=parts[:,0].reshape(b,h,1,d).clone(memory_format=torch.contiguous_format)
            k=parts[:,1].reshape(b,h,1,d);v=parts[:,2].reshape(b,h,1,d)
            return q,torch.cat((inputs[1],k),dim=2),torch.cat((inputs[2],v),dim=2)
        functions={'views_concat_q_copy':baseline,'custom':lambda:solution.run(inputs,attributes)}
        results={}
        for name,fn in functions.items():
            outputs=fn();torch.npu.synchronize()
            verify.validate_ownership(inputs,outputs)
            verify.compare(case,arrays,outputs,golden.calculate(arrays,attributes))
            for tensor,original in zip(inputs,arrays):
                assert np.array_equal(verify.cpu_array(tensor).view(np.uint16),original.view(np.uint16))
            del outputs
            results[name]=benchmark.measure(fn,torch.npu)
        record={'case_name':case['case_name'],'results':results,'selected_baseline':'views_concat_q_copy',
                'excluded_candidates':[],
                'custom_over_baseline':results['custom']['wall_us_median']/results['views_concat_q_copy']['wall_us_median']}
        report['cases'].append(record);report['npu_executed']=True
        print(json.dumps(record),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);args=p.parse_args()
    report={'status':'running','npu_executed':False,'protocol':{'warmup':50,'iterations':200,'rounds':5},
            'ratio_acceptance':'undefined in inconsistent task prose; report measurements only','cases':[]}
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report),encoding='utf-8')
    code=1
    try:execute(report);report['status']='passed';code=0
    except BaseException as exc:report.update(status='failed',error=str(exc));traceback.print_exc()
    finally:args.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    raise SystemExit(code)
