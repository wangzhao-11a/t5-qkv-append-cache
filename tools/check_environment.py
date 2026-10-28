"""Fail on a known version mismatch; require manual evidence for unknowns."""
import argparse,json
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True)
p.add_argument('--accepted-driver',default='25.5.t6.b001',help='Explicitly agreed evaluation driver; the reference task remains unchanged')
args=p.parse_args()
data=json.loads(args.input.read_text(encoding='utf-8'))['inventory']
expected={'torch':'2.10.0+cpu','torch_npu':'2.10.0.post4','numpy':'2.2.6','ml_dtypes':'0.6.0'}
errors=[]
if data['python']!='3.12.13':errors.append('Python must be 3.12.13')
if data['machine']!='aarch64':errors.append('Architecture must be aarch64')
for name,value in expected.items():
    if data['versions'].get(name)!=value:errors.append(f'{name}: expected {value}, got {data["versions"].get(name)}')
if not data['environment'].get('ASCEND_HOME_PATH'):errors.append('CANN environment is not loaded')
if not str(data.get('torch_npu_git_version','')).startswith('5dd8ef3'):errors.append('torch_npu git version must start with 5dd8ef3')
if args.accepted_driver not in data.get('/usr/local/Ascend/driver/version.info',''):errors.append(f'Agreed driver {args.accepted_driver} is not verified')
if errors:raise SystemExit('\n'.join(errors))
print(f'Queried versions and agreed driver {args.accepted_driver} match. Reference driver remains 25.5.t6.b001. Review npu-smi, CANN 9.1.0, OS and container evidence.')
