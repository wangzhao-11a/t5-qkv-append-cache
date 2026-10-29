"""Import completed remote evidence only after checksum and path validation."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile
import uuid
import shutil
import re

p=argparse.ArgumentParser()
p.add_argument('archive',type=Path)
p.add_argument('sha256',help='64 hex digits, or @path to the downloaded collector log')
p.add_argument('destination',type=Path)
a=p.parse_args()
if a.sha256.startswith('@'):
    records=[json.loads(line) for line in Path(a.sha256[1:]).read_text(encoding='utf-8').splitlines()
             if line.startswith('{"archive":')]
    if len(records)!=1:raise SystemExit('Expected exactly one archive receipt in collector log')
    a.sha256=records[0]['sha256']
if not re.fullmatch('[0-9a-fA-F]{64}',a.sha256):
    raise SystemExit('Expected exactly 64 hex digits; use @collector-log to avoid PTY wrapping transcription')
a.sha256=a.sha256.lower()
# Resolve both ends before Windows rename; relative parent traversal can be
# rejected by the sandbox even when the identical absolute move is allowed.
a.archive=a.archive.resolve()
a.destination=a.destination.resolve()
if hashlib.sha256(a.archive.read_bytes()).hexdigest()!=a.sha256:
    raise SystemExit('Reject incomplete or mismatched transfer before opening the archive')
if a.destination.exists():raise SystemExit('Preserve existing evidence; choose a new destination')
a.destination.parent.mkdir(parents=True,exist_ok=True)
# Python 3.14 mkdtemp applies a private Windows ACL for mode 0700. In the
# desktop sandbox that ACL prevents even realpath/filtering.
# Inherit the workspace ACL; the archive is still fully filtered below.
staging=a.destination.parent/('.evidence-'+uuid.uuid4().hex)
staging.mkdir(mode=0o755)
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
publication='rename'
try:
    staging.rename(a.destination)
except PermissionError as exc:
    # Windows may deny a directory rename after all file reads succeed. Do not
    # re-extract or weaken ACLs: copy to a fresh target and verify every byte.
    if getattr(exc, 'winerror', None) != 5 or a.destination.exists():
        raise
    shutil.copytree(staging, a.destination)
    for source in staging.rglob('*'):
        if source.is_file():
            target=a.destination/source.relative_to(staging)
            if hashlib.sha256(source.read_bytes()).digest()!=hashlib.sha256(target.read_bytes()).digest():
                raise SystemExit('Evidence publication copy mismatch; preserve both directories')
    publication='verified-copy; staging preserved'
    print(json.dumps({'publication':publication,'preserved_staging':str(staging)}))
print(json.dumps({'destination':str(a.destination),'archive_sha256':a.sha256,'members':len(names)}))
