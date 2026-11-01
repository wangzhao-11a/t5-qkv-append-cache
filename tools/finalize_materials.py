"""Assemble exactly seven named deliverables, preserving absent/failed evidence."""
from datetime import datetime,timezone
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--reports',type=Path,required=True)
p.add_argument('--output-dir',type=Path,required=True)
p.add_argument('--archive',type=Path,required=True)
a=p.parse_args()
OUT=a.output_dir.resolve()
if OUT==(ROOT/'task_submission').resolve() or a.archive.resolve()==(ROOT/'task_submission.zip').resolve():
    raise SystemExit('Preserve original baseline materials; choose new output paths')
if a.archive.exists():raise SystemExit('Preserve existing archive; choose a new output')
OUT.mkdir(parents=True,exist_ok=True)
groups={
    '2.2 精度自验证日志.log':['cpp_smoke.log','aclnn_invalid_metadata.log','public_accuracy.log','extended_accuracy.log','engineering.log'],
    '3.2 性能自验证日志.log':['performance.log','baseline_comparison.log'],
    '4.2 内存自验证日志.log':['memory.log'],
}
for filename,logs in groups.items():
    parts=['T5 QKV task: original device logs\n',f'Assembled at {datetime.now(timezone.utc).isoformat()}\n']
    for log in logs:
        path=a.reports/log
        parts.append(f'\n===== {log} =====\n')
        parts.append(path.read_text(encoding='utf-8',errors='replace') if path.is_file() else
                     'NOT_EXECUTED_OR_NOT_COLLECTED: no device log available. This is not a passing result.\n')
    (OUT/filename).write_text(''.join(parts),encoding='utf-8',newline='\n')
names=['1 自验证步骤说明.md','2.1 精度自验证报告.xlsx','2.2 精度自验证日志.log',
       '3.1 性能自验证报告.xlsx','3.2 性能自验证日志.log','4.1 内存自验证报告.xlsx','4.2 内存自验证日志.log']
for name in names:
    if not (OUT/name).is_file():raise SystemExit(f'Missing deliverable: {name}')
archive=a.archive
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED) as z:
    for name in names:z.write(OUT/name,name)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None and set(z.namelist())==set(names)
print(json.dumps({'archive':str(archive),'files':7,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()}))
