"""Compile and execute the actual T5 header with a CPU-only DMA adapter on Windows."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-commit', default='f52671207769bf5f334972c997743eb6aa6f91b3')
    parser.add_argument('--report', type=Path, required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--compile-only', dest='compile_only', action='store_true', default=True,
        help='default: record host compilation only; current Windows application policy blocks new executables')
    mode.add_argument('--execute', dest='compile_only', action='store_false',
        help='explicitly request host execution on a machine whose application policy permits it; never bypass policy')
    args = parser.parse_args()
    if args.report.exists():
        parser.error('preserve prior report; choose a new output path')
    if os.name != 'nt':
        parser.error('this runner uses installed Windows MSVC; no dependency installation is performed')
    vswhere = Path(os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)')) / 'Microsoft Visual Studio/Installer/vswhere.exe'
    installation = subprocess.check_output([str(vswhere), '-latest', '-products', '*', '-requires',
        'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property', 'installationPath'], encoding='utf-8').strip()
    vcvars = Path(installation) / 'VC/Auxiliary/Build/vcvars64.bat'
    if not vcvars.is_file():
        parser.error('installed MSVC C++ tools were not found')
    baseline_commit = subprocess.check_output(['git', 'rev-parse', '--verify', args.baseline_commit + '^{commit}'], cwd=ROOT, encoding='utf-8').strip()
    baseline = subprocess.check_output(['git', 'show', baseline_commit + ':op_kernel/t5_copy.h'], cwd=ROOT)
    candidate = (ROOT / 'op_kernel/t5_copy.h').read_bytes()
    artifact_root = ROOT / 'artifacts'
    artifact_root.mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='host-kernel-', dir=artifact_root))
    result = {'scope':'CPU adapter executes actual header; no device, cache, concurrency or performance validation',
        'baseline_commit':baseline_commit, 'cann_compiled':False, 'npu_executed':False, 'work_directory':str(work), 'versions':{}}
    for name, header in [('baseline', baseline), ('candidate', candidate)]:
        directory = work/name
        directory.mkdir()
        (directory/'t5_copy.h').write_bytes(header)
        exe = directory/'test_t5_copy.exe'
        command = '\r\n'.join([
            '@echo off', 'call "' + str(vcvars) + '" >nul', 'if errorlevel 1 exit /b %errorlevel%',
            'cl /nologo /std:c++17 /EHsc /O2 /W4 /I"' + str(ROOT/'tests/host_kernel') + '" /I"' + str(ROOT)
            + '" /I"' + str(directory) + '" /Fo"' + str(directory/'test_t5_copy.obj') + '" /Fe"' + str(exe)
            + '" "' + str(ROOT/'tests/host_kernel/test_t5_copy.cpp') + '"', 'exit /b %errorlevel%', ''])
        # This is a local Windows build command, never a Linux-bound script.
        batch = directory/'build_windows.bat'
        batch.write_bytes(command.encode('utf-8'))
        build = subprocess.run(['cmd.exe', '/d', '/c', str(batch)], cwd=directory, capture_output=True, timeout=90)
        (directory/'build.log').write_bytes(build.stdout + build.stderr)
        if build.returncode:
            raise RuntimeError(f'{name} host compilation failed; see {directory / "build.log"}')
        if args.compile_only:
            result['versions'][name] = {'kernel_sha256':hashlib.sha256(header).hexdigest(),
                'host_compiled':True, 'host_executed':False, 'build_log':str(directory/'build.log')}
            continue
        try:
            run = subprocess.run([str(exe)], cwd=directory, capture_output=True, encoding='utf-8', timeout=120)
        except OSError as error:
            raise RuntimeError(f'{name} host executable could not start: {error}; this is not a passed semantic test') from error
        (directory/'run.log').write_text(run.stdout + run.stderr, encoding='utf-8')
        if run.returncode:
            raise RuntimeError(f'{name} host semantic check failed; see {directory / "run.log"}')
        rows = [json.loads(line) for line in run.stdout.splitlines()]
        result['versions'][name] = {'kernel_sha256':hashlib.sha256(header).hexdigest(),
            'host_compiled':True, 'host_executed':True, 'records':rows}
    result['status'] = 'host_compiled_not_executed' if args.compile_only else 'passed_host_semantics_only'
    args.report.parent.mkdir(parents=True, exist_ok=True)
    with args.report.open('x', encoding='utf-8', newline='\n') as handle:
        json.dump(result, handle, indent=2)
        handle.write('\n')
    print(json.dumps({'status':result['status'], 'report':str(args.report),
        'host_executed':not args.compile_only,
        'cases_per_version':{k:v['records'][-1]['host_semantic_cases'] for k,v in result['versions'].items() if 'records' in v}}))


if __name__ == '__main__':
    main()
