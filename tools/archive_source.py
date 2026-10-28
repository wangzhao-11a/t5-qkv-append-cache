"""Archive an exact Git commit and build a byte-level Linux deployment manifest."""
import argparse
import hashlib
import json
from pathlib import Path,PurePosixPath
import subprocess
import tarfile

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--commit',default='HEAD');args=p.parse_args()
commit=subprocess.check_output(['git','rev-parse',args.commit],cwd=ROOT,text=True).strip()
out=ROOT/'artifacts';out.mkdir(exist_ok=True)
archive=out/f'source_{commit[:12]}.tar'
subprocess.run(['git','archive','--format=tar',f'--prefix=t5_qkv_{commit[:12]}/',f'--output={archive}',commit],cwd=ROOT,check=True)
files=[]
with tarfile.open(archive) as tar:
    for member in tar.getmembers():
        path=PurePosixPath(member.name)
        if path.is_absolute() or '..' in path.parts or member.issym() or member.islnk():raise ValueError('unsafe archive entry')
        if member.isfile():
            data=tar.extractfile(member).read()
            if path.suffix in ('.sh','.cmd') and (b'\r' in data or data.startswith(b'\xef\xbb\xbf')):raise ValueError(f'bad script bytes: {member.name}')
            files.append({'path':member.name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
manifest={'commit':commit,'archive':archive.name,'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
          'prefix':f't5_qkv_{commit[:12]}','files':files}
target=archive.with_suffix('.manifest.json')
target.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in manifest.items() if k!='files'}))
print('files:',len(files))
