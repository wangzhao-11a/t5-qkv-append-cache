"""Verify an uploaded git archive before extracting and atomically publishing."""
import hashlib
import json
from pathlib import Path,PurePosixPath
import subprocess
import sys
import tarfile
import tempfile

archive=Path(sys.argv[1]);manifest=json.loads(Path(sys.argv[2]).read_text(encoding='utf-8'))
parent=Path('/workspace/t5_qkv_tasks');parent.mkdir(exist_ok=True)
target=parent/manifest['prefix']
if target.exists():raise SystemExit('Refusing to replace existing baseline '+str(target))
if hashlib.sha256(archive.read_bytes()).hexdigest()!=manifest['archive_sha256']:raise SystemExit('archive hash mismatch')
with archive.open('rb') as stream:
    archived_commit=subprocess.check_output(['git','get-tar-commit-id'],stdin=stream,text=True).strip()
if archived_commit!=manifest['commit']:raise SystemExit('embedded git commit mismatch')
staging=Path(tempfile.mkdtemp(prefix='.staging-',dir=parent))
with tarfile.open(archive) as tar:
    expected={r['path']:r for r in manifest['files']}
    actual=set()
    for member in tar.getmembers():
        p=PurePosixPath(member.name)
        if p.is_absolute() or '..' in p.parts or p.parts[0]!=manifest['prefix'] or not(member.isfile() or member.isdir()):
            raise SystemExit('invalid archive layout')
        if member.isfile():
            data=tar.extractfile(member).read();record=expected.get(member.name)
            if not record or len(data)!=record['bytes'] or hashlib.sha256(data).hexdigest()!=record['sha256']:
                raise SystemExit('member checksum mismatch')
            actual.add(member.name)
    if actual!=set(expected):raise SystemExit('missing archive member')
    tar.extractall(staging,filter='data')
source=staging/manifest['prefix']
for script in source.rglob('*.sh'):
    raw=script.read_bytes()
    if b'\r' in raw or raw.startswith(b'\xef\xbb\xbf'):raise SystemExit('reject CRLF/BOM script')
    subprocess.run(['bash','-n',str(script)],check=True)
(source/'DEPLOYMENT_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
source.rename(target);staging.rmdir()
print(json.dumps({'target':str(target),'commit':manifest['commit'],'files_verified':len(actual)}))
