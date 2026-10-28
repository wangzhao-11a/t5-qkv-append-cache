#!/usr/bin/env bash
set -euo pipefail
/usr/local/python3.12.13/bin/python3 - <<'PY'
from pathlib import Path
import os,signal
pid=2696764
p=Path(f'/proc/{pid}/cmdline')
if p.exists():
    command=p.read_bytes().replace(b'\0',b' ').decode()
    required=('--target /workspace/t5_qkv_tasks/t5_qkv_2c8640a3256c/python_deps','-m pip install','numpy==2.2.6')
    if not all(x in command for x in required):raise SystemExit('PID identity mismatch; refusing signal')
    os.kill(pid,signal.SIGTERM)
    print('Stopped only this task stalled NumPy download:',pid)
else:print('Task pip process already exited')
PY
