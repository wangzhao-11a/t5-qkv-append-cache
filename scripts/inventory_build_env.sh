#!/usr/bin/env bash
set -u
exec > >(tee /tmp/t5_qkv_build_env_20261028.log) 2>&1
printf '%s\n' '=== baseline identity ==='
cat /proc/sys/kernel/hostname
cat /usr/local/Ascend/driver/version.info
cat /usr/local/Ascend/cann-9.1.0/aarch64-linux/ascend_toolkit_install.info
printf '%s\n' '=== tools ==='
for tool in cmake c++ git msopgen bisheng; do command -v "$tool" || true; done
printf '%s\n' '=== Python packages without device initialization ==='
/usr/local/python3.12.13/bin/python3 - <<'PY'
import sys,json,importlib.metadata as m
from pathlib import Path
versions={}
for name in ('torch','torch_npu','numpy','ml_dtypes','setuptools','ninja'):
    try:versions[name]=m.version(name)
    except m.PackageNotFoundError:versions[name]='not_installed'
print(json.dumps({'python':sys.version,'executable':sys.executable,'versions':versions},indent=2))
for filename in ('/proc/net/tcp','/proc/net/tcp6'):
    for line in Path(filename).read_text().splitlines()[1:]:
        fields=line.split()
        if fields[3]=='0A':print('LISTEN',filename,fields[1],int(fields[1].split(':')[1],16))
PY
printf '%s\n' '=== candidate device 1 board info ==='
npu-smi info -t board -i 0 -c 1 || true
printf '%s\n' '=== candidate device 1 processes ==='
npu-smi info -t proc -i 0 -c 1 || true
printf '%s\n' '=== CANN compiler layout ==='
ls -l /usr/local/Ascend/cann-9.1.0/set_env.sh /usr/local/Ascend/cann-9.1.0/tools/tikcpp/ascendc_kernel_cmake/ascendc.cmake 2>/dev/null
printf '%s\n' '=== work area ==='
pwd
ls -ld /root /tmp
