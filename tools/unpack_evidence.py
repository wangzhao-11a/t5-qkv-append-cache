"""Import completed remote evidence only after checksum and path validation."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile
import tempfile

p=argparse.ArgumentParser()
p.add_argument('archive',type=Path)
p.add_argument('sha256')
p.add_argument('destination',type=Path)
a=p.parse_args()
if hashlib.sha256(a.archive.read_bytes()).hexdigest()!=a.sha256:
    raise SystemExit('Reject incomplete or mismatched transfer before opening the archive')
if a.destination.exists():raise SystemExit('Preserve existing evidence; choose a new destination')
a.destination.parent.mkdir(parents=True,exist_ok=True)
staging=Path(tempfile.mkdtemp(prefix='.evidence-',dir=a.destination.parent))
with tarfile.open(a.archive) as tar:
    names=set()
    for member in tar.getmembers():
        name=PurePosixPath(member.name)
        if name.is_absolute() or '..' in name.parts or not(member.isfile() or member.isdir()) or member.name in names:
            raise SystemExit('Unsafe/duplicate evidence archive member')
        if name.parts[0] not in ('reports','artifacts','DEPLOYMENT_MANIFEST.json'):
            raise SystemExit('Unexpected evidence archive layout')
        names.add(member.name)
    tar.extractall(staging,filter='data')
manifest=staging/'artifacts/binary_manifest.json'
if manifest.exists():
    for record in json.loads(manifest.read_text(encoding='utf-8'))['files']:
        name=PurePosixPath(record['path'])
        if name.is_absolute() or '..' in name.parts:raise SystemExit('Unsafe manifest path')
        file=staging/record['path']
        if file.stat().st_size!=record['bytes'] or hashlib.sha256(file.read_bytes()).hexdigest()!=record['sha256']:
            raise SystemExit('Binary hash mismatch')
staging.rename(a.destination)
print(json.dumps({'destination':str(a.destination),'archive_sha256':a.sha256,'members':len(names)}))
