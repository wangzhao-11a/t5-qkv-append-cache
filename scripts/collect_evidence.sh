#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=/workspace/t5_qkv_tasks/t5_qkv_916c7d793f9e
cd "$TASK_ROOT"
mkdir -p artifacts/validation
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
set -u
export PATH=/workspace/vasc031_a3/bin:$PATH
export T5_OPP_ROOT=/root/.local/t5_qkv_916c7d793f9e
export ASCEND_RT_VISIBLE_DEVICES=1
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv${ASCEND_CUSTOM_OPP_PATH:+:$ASCEND_CUSTOM_OPP_PATH}"
export PYTHONPATH="/workspace/t5_qkv_tasks/t5_qkv_f0ea7ebdbb46/python_deps:$TASK_ROOT:$TASK_ROOT/reference${PYTHONPATH:+:$PYTHONPATH}"
export LD_LIBRARY_PATH="/workspace/vasc031_a3/lib/python3.12/site-packages/torch/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p artifacts/binaries
cp _t5_qkv*.so build/direct/lib/libt5_direct.so build/examples/t5_example artifacts/binaries/
ldd artifacts/binaries/_t5_qkv*.so > artifacts/binaries/ldd_binding.txt
ldd artifacts/binaries/libt5_direct.so > artifacts/binaries/ldd_direct.txt
ldd artifacts/binaries/t5_example > artifacts/binaries/ldd_example.txt
if grep -n 'not found' artifacts/binaries/ldd_*.txt; then exit 2; fi
readelf -d artifacts/binaries/_t5_qkv*.so > artifacts/binaries/readelf_binding.txt
python tools/preflight.py --output artifacts/validation/environment_final.json > artifacts/validation/environment_final.log
python tools/check_environment.py --input artifacts/validation/environment_final.json --accepted-driver 26.1.1 > artifacts/validation/specified_environment_check.log 2>&1 || true
python tools/fingerprint.py --output artifacts/tested_build_manifest.json
python - <<'PY'
import hashlib,json,tarfile
from pathlib import Path
root=Path.cwd()
manifest={'build_source_commit':json.loads(Path('DEPLOYMENT_MANIFEST.json').read_text())['commit'],
 'native_source_commit':json.loads(Path('DEPLOYMENT_MANIFEST.json').read_text())['commit'],
 'aclnn_source_commit':json.loads(Path('DEPLOYMENT_MANIFEST.json').read_text())['commit'],
 'private_installation':'/root/.local/t5_qkv_916c7d793f9e','physical_device':1,'logical_device':0,
 'model_path':None,'service_ports':[],
 'commands':['/tmp/t5_start_optimized_build_916c7d7.sh','/tmp/t5_phase_smoke_916c7d7.sh',
 '/tmp/t5_phase_correctness_916c7d7.sh','/tmp/t5_phase_performance_916c7d7.sh'],
 'files':[]}
for f in sorted(Path('artifacts/binaries').glob('*'))+sorted(Path('artifacts').glob('*.run')):
    manifest['files'].append(dict(path=f.as_posix(),bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest()))
Path('artifacts/binary_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
paths=[(p,'reports/'+p.name) for p in Path('artifacts/validation').iterdir() if p.is_file()]
paths += [(p,p.as_posix()) for p in Path('artifacts').rglob('*')
          if p.is_file() and 'previews' not in p.parts and 'validation' not in p.parts]
with tarfile.open('/tmp/t5_evidence_916c7d7.tar.gz','w:gz') as tar:
    for p,name in paths:tar.add(p,arcname=name,recursive=False)
print(json.dumps({'archive':'/tmp/t5_evidence_916c7d7.tar.gz','files':len(paths),'sha256':hashlib.sha256(Path('/tmp/t5_evidence_916c7d7.tar.gz').read_bytes()).hexdigest()}))
PY
