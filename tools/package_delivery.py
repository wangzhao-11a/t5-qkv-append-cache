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
a = p.parse_args()
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
files['task_submission.zip'] = (ROOT/'task_submission.zip').read_bytes()
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
