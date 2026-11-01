"""Package committed sources and separately manifested tested binaries/evidence."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--evidence', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--submission', type=Path, required=True)
p.add_argument('--evidence-archive', type=Path, required=True)
p.add_argument('--evidence-receipt', type=Path, required=True)
a = p.parse_args()
if a.output.exists():
    raise SystemExit('Preserve existing delivery; choose a new output')
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
if subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT, text=True).strip():
    raise SystemExit('Commit the final tracked sources/reports before packaging')
binary_manifest = json.loads((a.evidence/'artifacts/binary_manifest.json').read_text(encoding='utf-8'))
tested = binary_manifest['build_source_commit']
runtime_paths = ['common', 'csrc', 'direct', 'examples', 'op_host', 'op_kernel',
                 'solution.py', 'setup.py', 'op_project.json']
if subprocess.check_output(['git', 'diff', tested, commit, '--', *runtime_paths], cwd=ROOT):
    raise SystemExit('Final runtime sources differ from the tested binary commit')
files = {}
raw = subprocess.check_output(['git', 'archive', '--format=tar', commit], cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as tar:
    for member in tar:
        name = PurePosixPath(member.name)
        if name.is_absolute() or '..' in name.parts or not (member.isfile() or member.isdir()):
            raise SystemExit('Unsafe committed source archive')
        if member.isfile():
            files[name.as_posix()] = tar.extractfile(member).read()
for record in binary_manifest['files']:
    name = PurePosixPath(record['path'])
    if name.is_absolute() or '..' in name.parts:
        raise SystemExit('Unsafe binary manifest path')
    data = (a.evidence/name).read_bytes()
    if len(data) != record['bytes'] or hashlib.sha256(data).hexdigest() != record['sha256']:
        raise SystemExit('Tested binary checksum mismatch')
    files[name.as_posix()] = data
for folder in ('reports', 'artifacts'):
    for f in (a.evidence/folder).glob('*'):
        if f.is_file():
            files[f'evidence/tested/{folder}/{f.name}'] = f.read_bytes()
for f in (ROOT/'artifacts/wheels').glob('*.whl'):
    files[f'artifacts/wheels/{f.name}'] = f.read_bytes()
for suffix in ('.tar', '.manifest.json'):
    name = f'source_{tested[:12]}{suffix}'
    files[f'artifacts/{name}'] = (ROOT/'artifacts'/name).read_bytes()
with zipfile.ZipFile(a.submission) as z:
    names=['1 自验证步骤说明.md','2.1 精度自验证报告.xlsx','2.2 精度自验证日志.log',
           '3.1 性能自验证报告.xlsx','3.2 性能自验证日志.log','4.1 内存自验证报告.xlsx','4.2 内存自验证日志.log']
    if z.testzip() is not None or len(z.namelist())!=7 or set(z.namelist())!=set(names):
        raise SystemExit('Submission must contain exactly the seven validated materials')
    if tested not in z.read(names[0]).decode('utf-8'):
        raise SystemExit('Submission instructions do not identify the tested runtime source')
    # Keep baseline materials explicitly, then publish the accepted seven at the normal path.
    for name in names:
        old=files.pop('task_submission/'+name,None)
        if old is not None:files['evidence/baseline_c9decf2/task_submission/'+name]=old
        files['task_submission/'+name]=z.read(name)
files['task_submission.zip'] = a.submission.read_bytes()
receipt=json.loads(a.evidence_receipt.read_text(encoding='utf-8'))
archive_data=a.evidence_archive.read_bytes()
if hashlib.sha256(archive_data).hexdigest()!=receipt['sha256']:
    raise SystemExit('Evidence archive SHA256 mismatch')
files['evidence/accepted/'+a.evidence_archive.name]=archive_data
files['evidence/accepted/collector_receipt.json']=a.evidence_receipt.read_bytes()
manifest = {'delivery_commit': commit, 'tested_runtime_source_commit': tested,
            'driver_actual': '26.1.1', 'driver_task_required': '25.5.t6.b001',
            'driver_difference_accepted_by_user': True,
            'source_layout': 'Git archive; binary/runtime artifacts added separately',
            'files': [{'path': n, 'bytes': len(d), 'sha256': hashlib.sha256(d).hexdigest()}
                      for n, d in sorted(files.items())]}
files['DELIVERY_MANIFEST.json'] = (json.dumps(manifest, ensure_ascii=False, indent=2)+'\n').encode('utf-8')
a.output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(a.output, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    for name, data in sorted(files.items()):
        z.writestr('t5_qkv_task/'+name, data)
with zipfile.ZipFile(a.output) as z:
    if z.testzip() is not None:
        raise SystemExit('ZIP integrity failure')
    for record in manifest['files']:
        if hashlib.sha256(z.read('t5_qkv_task/'+record['path'])).hexdigest()!=record['sha256']:
            raise SystemExit('Packaged file checksum mismatch')
print(json.dumps({'archive': str(a.output.resolve()), 'files': len(files),
                  'sha256': hashlib.sha256(a.output.read_bytes()).hexdigest(),
                  'delivery_commit': commit, 'tested_runtime_source_commit': tested}))
