#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/phase_common.sh"
[[ "${T5_PHYSICAL_DEVICE:-}" =~ ^[0-9]+$ ]] || {
  echo 'Refuse to invent the physical device identity; set verified T5_PHYSICAL_DEVICE' >&2; exit 2;
}
[[ ! -e artifacts/binary_manifest.json ]] || { echo 'Preserve previous collection'; exit 2; }
phase_begin collect_evidence
set +u
source /usr/local/Ascend/cann-9.1.0/set_env.sh
set -u
export PATH=/workspace/vasc031_a3/bin:$PATH
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
import hashlib,json,os,tarfile
from pathlib import Path
root=Path.cwd()
manifest={'build_source_commit':json.loads(Path('DEPLOYMENT_MANIFEST.json').read_text())['commit'],
 'native_source_commit':json.loads(Path('DEPLOYMENT_MANIFEST.json').read_text())['commit'],
 'aclnn_source_commit':json.loads(Path('DEPLOYMENT_MANIFEST.json').read_text())['commit'],
 'private_installation':os.environ['T5_OPP_ROOT'],
 'physical_device':int(os.environ['T5_PHYSICAL_DEVICE']),'logical_device':0,
 'visible_device_selector':os.environ['ASCEND_RT_VISIBLE_DEVICES'],
 'model_path':None,'service_ports':[],
 'commands':['bash '+str(root/'scripts'/name) for name in ('start_optimized_build.sh',
 'phase_smoke.sh','phase_correctness.sh','phase_performance.sh')],
 'files':[]}
for f in sorted(Path('artifacts/binaries').glob('*'))+sorted(Path('artifacts').glob('*.run')):
    manifest['files'].append(dict(path=f.as_posix(),bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest()))
Path('artifacts/binary_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
paths=[(p,'reports/'+p.name) for p in Path('artifacts/validation').iterdir() if p.is_file()]
paths += [(p,p.as_posix()) for p in Path('artifacts').rglob('*')
          if p.is_file() and 'previews' not in p.parts and 'validation' not in p.parts]
archive=Path('/tmp')/('t5_evidence_'+root.name.removeprefix('t5_qkv_')+'.tar.gz')
with tarfile.open(archive,'x:gz') as tar:
    for p,name in paths:tar.add(p,arcname=name,recursive=False)
print(json.dumps({'archive':str(archive),'files':len(paths),'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()}))
PY
