#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 ]] || exit 2
task_source=$(realpath -e -- "$1")
set +u
source /usr/local/Ascend/cann/set_env.sh
set -u
source "$task_source/scripts/phase_common.sh"
phase_begin native_smoke_20261116 native_build
export ASCEND_RT_VISIBLE_DEVICES=1 T5_PHYSICAL_DEVICE=3
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv"
export LD_LIBRARY_PATH="$T5_OPP_ROOT/vendors/t5qkv/op_api/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
phase_device_inventory selected
python3 tools/preflight.py --output artifacts/validation/native_smoke_before.json
for variant in fp16 bf16 negative; do
  rc=0
  if [[ "$variant" == fp16 ]]; then
    build/examples/t5_example > "artifacts/validation/native_smoke_${variant}.log" 2>&1 || rc=$?
  else
    build/examples/t5_example "--$variant" > "artifacts/validation/native_smoke_${variant}.log" 2>&1 || rc=$?
  fi
  printf '%s\n' "$rc" > "artifacts/validation/native_smoke_${variant}.exit"
  [[ "$rc" == 0 ]] || exit "$rc"
done
npu-smi info -t proc-mem -i 1 -c 1 > artifacts/validation/native_smoke_device_after.txt
grep -Eq '^[[:space:]]*No process in device\.[[:space:]]*$' artifacts/validation/native_smoke_device_after.txt
python3 tools/preflight.py --output artifacts/validation/native_smoke_after.json
python3 - <<'PY'
import json
from pathlib import Path
folder=Path('artifacts/validation');records={}
for variant in ['fp16','bf16','negative']:
    rows=[json.loads(line) for line in (folder/('native_smoke_'+variant+'.log')).read_text().splitlines() if line.startswith('{')]
    if variant=='negative':
        assert len(rows)==5 and {r['metadata_scenario'] for r in rows}==set(range(5))
        assert all(r['status']=='passed' and r['acl_status']!=0 for r in rows)
    else:
        assert len(rows)==1 and rows[0]['status']=='passed' and rows[0]['workspace_bytes']==0 and rows[0]['bit_mismatches']==0
    records[variant]=rows
before=json.loads((folder/'native_smoke_before.json').read_text())['inventory']
after=json.loads((folder/'native_smoke_after.json').read_text())['inventory']
assert before['listening_tcp_ports']==after['listening_tcp_ports'], 'Listening port inventory changed during native smoke'
r={'status':'passed_native_smoke_only','npu_executed':True,'records':records,
 'source_commit':json.loads(Path('DEPLOYMENT_MANIFEST.json').read_text())['commit'],
 'physical_device':3,'runtime_selector':1,'logical_device':0,
 'limitations':'Small shape only; not 35-case accuracy, engineering, memory or performance acceptance'}
with (folder/'native_smoke_summary.json').open('x') as f:json.dump(r,f,indent=2);f.write('\n')
print(json.dumps(r))
PY
