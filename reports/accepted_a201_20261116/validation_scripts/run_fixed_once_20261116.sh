#!/usr/bin/env bash
# One unchanged public 10-case benchmark after the completed functional gates.
# Never rebuild, profile, retry, change thresholds, or run a second benchmark.
set -euo pipefail
[[ $# == 1 ]] || { echo 'Usage: run_fixed_once_20261116.sh EXACT_DEPLOYMENT_DIRECTORY' >&2; exit 2; }
task_deployment=$(realpath -e -- "$1")
case "$task_deployment" in
  /workspace/t5_qkv_tasks/t5_qkv_f52671207769|/workspace/t5_qkv_tasks/t5_qkv_a2013d56db4f) ;;
  *) echo 'Expected the reviewed exact f526 or a201 deployment'; exit 2 ;;
esac
: "${ASCEND_HOME_PATH:?Load the verified CANN environment first}"
[[ "${T5_DEVICE_CONFIRMED:-}" == 1 ]] || { echo 'Review ports/workers and arrange the whole-board idle window before launch; set T5_DEVICE_CONFIRMED=1'; exit 2; }
task_venv=/workspace/t5_qkv_tasks/venv_t5_py312_torch210_20261116_offline_v3
task_wrapper=$(realpath -e -- "${BASH_SOURCE[0]}")
[[ -x "$task_venv/bin/python" ]] || { echo 'Verified private Python is unavailable'; exit 2; }
export PATH="$task_venv/bin:$ASCEND_HOME_PATH/bin:$ASCEND_HOME_PATH/compiler/ccec_compiler/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export VIRTUAL_ENV="$task_venv" PYTHONDONTWRITEBYTECODE=1 PYTHONNOUSERSITE=1
unset PYTHONHOME PYTHONPATH LD_PRELOAD
source "$task_deployment/scripts/phase_common.sh"
[[ "$TASK_ROOT" == "$task_deployment" ]] || exit 2
export ASCEND_RT_VISIBLE_DEVICES=1 T5_PHYSICAL_DEVICE=3 T5_FUNCTIONAL_DEVICE_SCOPE=board
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv"
export PYTHONPATH="$TASK_ROOT:$TASK_ROOT/reference"
export LD_LIBRARY_PATH="$TASK_ROOT/build/direct/lib:$T5_OPP_ROOT/vendors/t5qkv/op_api/lib:$task_venv/lib/python3.12/site-packages/torch/lib:$task_venv/lib/python3.12/site-packages/torch_npu/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
phase_begin performance_phase correctness_phase
task_evidence="$TASK_ROOT/artifacts/validation/fixed_once_20261116"
mkdir -- "$task_evidence"
export task_venv task_wrapper task_evidence

# Reuse the verified receipts; this reads bytes/metadata and runs no NPU work.
task_verify_identity() {
  python - "$1" <<'PY'
import hashlib, json, os, sys
from pathlib import Path
root = Path(os.environ['TASK_ROOT'])
folder = root / 'artifacts/validation'
evidence = Path(os.environ['task_evidence'])
venv = Path(os.environ['task_venv'])
stage = sys.argv[1]
def load(path):
    return json.loads(path.read_text())
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
manifest = load(root / 'DEPLOYMENT_MANIFEST.json')
commit = manifest['commit']
if commit not in {'f52671207769bf5f334972c997743eb6aa6f91b3', 'a2013d56db4ff8367160b157335d2ff670aad411'}:
    raise SystemExit('Unexpected exact source commit')
if root.name != 't5_qkv_' + commit[:12] or manifest['prefix'] != root.name:
    raise SystemExit('Deployment path/commit mismatch')
for item in manifest['files']:
    path = root / Path(item['path']).relative_to(root.name)
    if path.stat().st_size != item['bytes'] or digest(path) != item['sha256']:
        raise SystemExit('Tracked source changed: ' + str(path))
if Path(sys.prefix) != venv or (venv / 'setup.exit').read_text().strip() != '0':
    raise SystemExit('Private runtime setup is not verified')
for name in ('native_build', 'native_smoke_20261116', 'build_full', 'smoke_phase', 'correctness_phase'):
    if (folder / (name + '.exit')).read_text().strip() != '0':
        raise SystemExit('Required successful stage: ' + name)
binding = load(folder / 'binding_import.json')
gate = load(folder / 'binding_gate.json')
if (binding['status'] != 'import_passed' or binding['python_executable'] != str(venv / 'bin/python')
        or gate['status'] != 'passed' or gate['source_commit'] != commit
        or gate['python_executable'] != str(venv / 'bin/python')):
    raise SystemExit('Binding receipt does not match this source/runtime')
extension = Path(binding['extension'])
if extension.parent != root or list(root.glob('_t5_qkv*.so')) != [extension]:
    raise SystemExit('Unexpected extension origin/count')
if extension.stat().st_size != binding['bytes'] or digest(extension) != binding['sha256']:
    raise SystemExit('Binding binary changed')
opp = Path(os.environ['T5_OPP_ROOT'])
if (opp != Path.home() / '.local' / root.name or opp.resolve(strict=True) != opp
        or os.environ['ASCEND_CUSTOM_OPP_PATH'] != str(opp / 'vendors/t5qkv')):
    raise SystemExit('Expected the sole private OPP for this exact deployment')
native = load(folder / 'native_binary_manifest.json')
if native['source_commit'] != commit or native['private_opp'] != str(opp):
    raise SystemExit('Native manifest source/OPP mismatch')
expected = {root / 'build/direct/lib/libt5_direct.so', root / 'build/examples/t5_example'}
expected.update(p for p in opp.rglob('*') if p.is_file() and p.suffix in {'.so', '.o', '.json', '.h'})
seen = set()
for item in native['files']:
    path = Path(item['path'])
    if path not in expected or path in seen or not (path.resolve(strict=True).is_relative_to(opp) or path.resolve(strict=True).is_relative_to(root / 'build')):
        raise SystemExit('Unexpected, redirected or duplicate native file: ' + str(path))
    if path.stat().st_size != item['bytes'] or digest(path) != item['sha256']:
        raise SystemExit('Native file changed: ' + str(path))
    seen.add(path)
if seen != expected:
    raise SystemExit('Native manifest file coverage changed')
receipts = [folder / 'binding_import.json', folder / 'binding_gate.json', folder / 'native_binary_manifest.json',
            venv / 'metadata_verified.json', venv / 'install-report.json']
for mode in ('smoke', 'correctness'):
    base = folder / ('functional_' + mode)
    summary, identity = load(base / 'summary.json'), load(base / 'identity.json')
    if (summary['status'] != 'passed_functional_only' or summary['phase'] != mode
            or summary['source_commit'] != commit or summary['npu_executed'] is not True
            or summary['performance_executed'] is not False or identity['source_commit'] != commit
            or identity['extension_sha256'] != binding['sha256'] or identity['physical_device'] != 3
            or identity['runtime_selector'] != 1 or identity['logical_device'] != 0):
        raise SystemExit('Functional receipt does not match this source/binary/device: ' + mode)
    receipts += [base / 'summary.json', base / 'identity.json']
    for name in ('source_before.json', 'source_after.json'):
        fingerprint = load(base / name)
        if fingerprint['source_commit'] != commit or fingerprint['worktree_status'] != 'archive verified':
            raise SystemExit('Functional source receipt mismatch: ' + mode + '/' + name)
    for name, count in summary['counts'].items():
        report = load(folder / name)
        rows = report['cases'] if name == 'public_accuracy.json' else report['records']
        if report['status'] != 'passed' or report['npu_executed'] is not True or len(rows) != count:
            raise SystemExit('Functional report no longer matches its passing receipt: ' + name)
        receipts.append(folder / name)
public = load(root / 'reference/case.json')
ids = [c['case_name'] for c in public if c.get('performance') is True]
if len(ids) != 10 or len(set(ids)) != 10 or set(ids) != set(load(root / 'reference/coverage_requirements.json')['performance_case_ids']):
    raise SystemExit('Expected the original ten fixed performance cases')
if stage == 'before':
    names = ['performance.json', 'performance.log', 'performance_acceptance.json', 'performance_acceptance.log',
             'environment_performance_phase.json', 'device_performance_phase.txt', 'device_performance_phase_idle_probe.txt']
    for name in names:
        path = folder / name
        if path.exists() or path.is_symlink():
            raise SystemExit('Preserve prior performance output: ' + str(path))
report = {'source_commit': commit, 'deployment_manifest_sha256': digest(root / 'DEPLOYMENT_MANIFEST.json'),
          'wrapper_sha256': digest(Path(os.environ['task_wrapper'])), 'extension_sha256': binding['sha256'],
          'native_files_verified': len(seen), 'private_opp': str(opp), 'python_executable': sys.executable,
          'physical_device': 3, 'runtime_selector': 1, 'logical_device': 0,
          'case_ids': ids, 'receipt_sha256': {str(p): digest(p) for p in receipts}}
if stage == 'after' and report != load(evidence / 'identity_before.json'):
    raise SystemExit('Source, binary, wrapper or prerequisite evidence changed during measurement')
with (evidence / ('identity_' + stage + '.json')).open('x') as out:
    json.dump(report, out, indent=2); out.write('\n')
print(json.dumps(report))
PY
}

# The original phase owns the lock/log/exit. Add only read-only final clearance
# and byte checks, including on a failing benchmark/checker; never rerun NPU work.
task_finish() {
  task_rc=$?
  task_run_rc=$task_rc
  trap - EXIT
  set +e
  task_verify_identity after > "$task_evidence/identity_after.log" 2>&1
  task_identity_rc=$?
  python tools/preflight.py --output "$task_evidence/environment_after.json" > "$task_evidence/environment_after.log" 2>&1
  task_inventory_rc=$?
  npu-smi info > "$task_evidence/device_after.txt" 2>&1
  task_smi_rc=$?
  python - <<'PY' > "$task_evidence/clearance.log" 2>&1
import json, os
from pathlib import Path
root = Path(os.environ['TASK_ROOT'])
folder = Path(os.environ['task_evidence'])
before = json.loads((root / 'artifacts/validation/environment_performance_phase.json').read_text())['inventory']
after = json.loads((folder / 'environment_after.json').read_text())['inventory']
if before['listening_tcp_ports'] != after['listening_tcp_ports']:
    raise SystemExit('Listening ports changed; inspect before/after process inventories')
if 'No running processes found' not in (folder / 'device_after.txt').read_text():
    raise SystemExit('Whole-board clearance failed; retain evidence and stop')
print('Benchmark/checker processes exited; board clear; ports unchanged. Process inventories retained.')
PY
  task_clearance_rc=$?
  if [[ "$task_rc" == 0 && ( "$task_identity_rc" != 0 || "$task_inventory_rc" != 0 || "$task_smi_rc" != 0 || "$task_clearance_rc" != 0 ) ]]; then task_rc=2; fi
  printf 'run_exit=%s identity_exit=%s inventory_exit=%s smi_exit=%s clearance_exit=%s final_exit=%s\n' "$task_run_rc" "$task_identity_rc" "$task_inventory_rc" "$task_smi_rc" "$task_clearance_rc" "$task_rc"
  (set -o noclobber; printf '%s\n' "$task_rc" > "artifacts/validation/$T5_PHASE.exit")
  exit "$task_rc"
}
trap task_finish EXIT
task_verify_identity before
phase_device_inventory board
python tools/check_environment.py --input artifacts/validation/environment_performance_phase.json --accepted-driver 26.1.1
python - <<'PY'
import json, os
from pathlib import Path
root = Path(os.environ['TASK_ROOT'])
folder = root / 'artifacts/validation'
before = json.loads((folder / 'environment_performance_phase.json').read_text())['inventory']['environment']
functional = json.loads((folder / 'environment_correctness_phase.json').read_text())['inventory']['environment']
for key in ('ASCEND_HOME_PATH', 'ASCEND_RT_VISIBLE_DEVICES', 'ASCEND_CUSTOM_OPP_PATH', 'T5_OPP_ROOT',
            'T5_ACLNN_EXECUTOR_REUSE', 'TASK_QUEUE_ENABLE', 'T5_PHYSICAL_DEVICE'):
    if before[key] != functional[key]:
        raise SystemExit('Runtime setting differs from passing correctness: ' + key)
print('Runtime controls match the completed correctness phase.')
PY

# Exactly one invocation of the frozen public benchmark. Its own protocol is
# 50 warmups, 200 calls per round, 5 rounds, over all ten public performance cases.
# Output paths are reserved by the exclusive phase lock and preflight checks.
set -o noclobber
set +e
python reference/benchmark.py --device 0 --solution-file "$TASK_ROOT/solution.py" --report artifacts/validation/performance.json > artifacts/validation/performance.log 2>&1
task_benchmark_rc=$?
# This is CPU-only. On threshold failure the raw benchmark JSON already contains
# the detailed performance_checks; do not rewrite status to make this checker pass.
python reference/check_performance.py --report artifacts/validation/performance.json --output artifacts/validation/performance_acceptance.json > artifacts/validation/performance_acceptance.log 2>&1
task_checker_rc=$?
set -e
printf 'benchmark_exit=%s checker_exit=%s\n' "$task_benchmark_rc" "$task_checker_rc"
[[ "$task_benchmark_rc" == 0 ]] || exit "$task_benchmark_rc"
[[ "$task_checker_rc" == 0 ]] || exit "$task_checker_rc"
