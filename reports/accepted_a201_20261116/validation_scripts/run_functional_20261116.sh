#!/usr/bin/env bash
# Existing smoke/stability and full functional tests in the new private runtime.
# No benchmark, profiler, performance acceptance, installation or rebuild.
set -euo pipefail
[[ $# == 2 ]] || { echo 'Usage: run_functional_20261116.sh DEPLOYMENT_DIRECTORY smoke|correctness' >&2; exit 2; }
task_deployment=$(realpath -e -- "$1")
task_mode="$2"
case "$task_mode" in smoke|correctness) ;; *) echo 'Expected smoke or correctness'; exit 2 ;; esac
: "${ASCEND_HOME_PATH:?Load the verified CANN environment first}"
[[ "${T5_DEVICE_CONFIRMED:-}" == 1 ]] || { echo 'Review ports, workers and physical device 3 before launch; set T5_DEVICE_CONFIRMED=1'; exit 2; }
task_venv=/workspace/t5_qkv_tasks/venv_t5_py312_torch210_20261116_offline_v3
[[ -x "$task_venv/bin/python" ]] || { echo 'Private Python is unavailable'; exit 2; }
export PATH="$task_venv/bin:$ASCEND_HOME_PATH/bin:$ASCEND_HOME_PATH/compiler/ccec_compiler/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export VIRTUAL_ENV="$task_venv" PYTHONDONTWRITEBYTECODE=1 PYTHONNOUSERSITE=1
unset PYTHONHOME PYTHONPATH LD_PRELOAD
source "$task_deployment/scripts/phase_common.sh"
[[ "$TASK_ROOT" == "$task_deployment" ]] || exit 2
export ASCEND_RT_VISIBLE_DEVICES=1 T5_PHYSICAL_DEVICE=3 T5_FUNCTIONAL_DEVICE_SCOPE=selected
export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv"
export PYTHONPATH="$TASK_ROOT:$TASK_ROOT/reference"
# Preserve the verified CANN/Python loader environment; prepend only this target.
export LD_LIBRARY_PATH="$TASK_ROOT/build/direct/lib:$T5_OPP_ROOT/vendors/t5qkv/op_api/lib:$task_venv/lib/python3.12/site-packages/torch/lib:$task_venv/lib/python3.12/site-packages/torch_npu/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if [[ "$task_mode" == smoke ]]; then phase_begin smoke_phase build_full; else phase_begin correctness_phase smoke_phase; fi
task_evidence="$TASK_ROOT/artifacts/validation/functional_$task_mode"
mkdir -- "$task_evidence"
export task_mode task_venv task_evidence

# phase_begin owns the exclusive phase lock/log. Preserve its exit semantics,
# adding read-only post-process snapshots even when a test fails.
task_finish() {
  task_rc=$?
  task_test_rc=$task_rc
  trap - EXIT
  set +e
  python tools/preflight.py --output "$task_evidence/environment_after.json" > "$task_evidence/environment_after.log" 2>&1
  task_after_rc=$?
  npu-smi info > "$task_evidence/device_after.txt" 2>&1
  task_smi_rc=$?
  python - <<'PY' > "$task_evidence/clearance.log" 2>&1
import json, os, subprocess
from pathlib import Path
root = Path(os.environ['TASK_ROOT'])
folder = Path(os.environ['task_evidence'])
phase = 'smoke_phase' if os.environ['task_mode'] == 'smoke' else 'correctness_phase'
mapping = json.loads((root / 'artifacts/validation' / ('device_mapping_' + phase + '.json')).read_text())
if mapping['physical'] != 3 or mapping['selector'] != 1:
    raise SystemExit('Unexpected recorded device mapping')
command = ['npu-smi', 'info', '-t', 'proc-mem', '-i', str(mapping['card']), '-c', str(mapping['chip'])]
result = subprocess.run(command, capture_output=True, text=True, timeout=30)
with (folder / 'selected_device_after.txt').open('x') as out:
    out.write(result.stdout + result.stderr)
if result.returncode != 0 or not any(line.strip() == 'No process in device.' for line in result.stdout.splitlines()):
    raise SystemExit('Selected device clearance failed; inspect the captured process list')
before = json.loads((root / 'artifacts/validation' / ('environment_' + phase + '.json')).read_text())['inventory']
after = json.loads((folder / 'environment_after.json').read_text())['inventory']
if before['listening_tcp_ports'] != after['listening_tcp_ports']:
    raise SystemExit('Listening port inventory changed; inspect before/after workers')
print('Selected device is clear; listening ports unchanged. Before/after process inventories retained.')
PY
  task_clear_rc=$?
  if [[ "$task_rc" == 0 && ( "$task_after_rc" != 0 || "$task_smi_rc" != 0 || "$task_clear_rc" != 0 ) ]]; then task_rc=2; fi
  printf 'test_exit=%s inventory_exit=%s smi_exit=%s clearance_exit=%s final_exit=%s\n' "$task_test_rc" "$task_after_rc" "$task_smi_rc" "$task_clear_rc" "$task_rc"
  (set -o noclobber; printf '%s\n' "$task_rc" > "artifacts/validation/$T5_PHASE.exit")
  exit "$task_rc"
}
trap task_finish EXIT

python - <<'PY'
import hashlib, json, os, sys
from pathlib import Path
root = Path(os.environ['TASK_ROOT'])
folder = root / 'artifacts/validation'
venv = Path(os.environ['task_venv'])
commit = json.loads((root / 'DEPLOYMENT_MANIFEST.json').read_text())['commit']
if commit not in {'a2013d56db4ff8367160b157335d2ff670aad411', 'f52671207769bf5f334972c997743eb6aa6f91b3'}:
    raise SystemExit('Unexpected exact source commit')
if Path(sys.prefix) != venv or (venv / 'setup.exit').read_text().strip() != '0':
    raise SystemExit('Private runtime setup is not verified')
for name in ('build_full', 'native_build', 'native_smoke_20261116'):
    if (folder / (name + '.exit')).read_text().strip() != '0':
        raise SystemExit('Required successful stage: ' + name)
binding = json.loads((folder / 'binding_import.json').read_text())
gate = json.loads((folder / 'binding_gate.json').read_text())
if (binding['status'] != 'import_passed' or binding['python_executable'] != str(venv / 'bin/python')
        or gate['source_commit'] != commit or gate['python_executable'] != str(venv / 'bin/python')):
    raise SystemExit('Binding was not verified in the requested private runtime/source')
extension = Path(binding['extension'])
if extension.parent != root or list(root.glob('_t5_qkv*.so')) != [extension]:
    raise SystemExit('Unexpected extension origin/count')
if extension.stat().st_size != binding['bytes'] or hashlib.sha256(extension.read_bytes()).hexdigest() != binding['sha256']:
    raise SystemExit('Binding binary changed')
native = json.loads((folder / 'native_binary_manifest.json').read_text())
opp = Path(os.environ['T5_OPP_ROOT'])
if native['source_commit'] != commit or native['private_opp'] != str(opp):
    raise SystemExit('Native manifest source or private OPP mismatch')
expected = {root / 'build/direct/lib/libt5_direct.so', root / 'build/examples/t5_example'}
expected.update(p for p in opp.rglob('*') if p.is_file() and p.suffix in {'.so', '.o', '.json', '.h'})
seen = set()
for record in native['files']:
    path = Path(record['path'])
    if path not in expected or path in seen:
        raise SystemExit('Unexpected/duplicate native binary record')
    data = path.read_bytes()
    if len(data) != record['bytes'] or hashlib.sha256(data).hexdigest() != record['sha256']:
        raise SystemExit('Native file changed: ' + str(path))
    seen.add(path)
if seen != expected:
    raise SystemExit('Native file coverage changed')
smoke = json.loads((folder / 'native_smoke_summary.json').read_text())
if (smoke['source_commit'] != commit or smoke['status'] != 'passed_native_smoke_only'
        or smoke['physical_device'] != 3 or smoke['runtime_selector'] != 1 or smoke['logical_device'] != 0):
    raise SystemExit('Prior native smoke does not match this target')
raw = (folder / 'native_smoke_negative.log').read_bytes()
rows = [json.loads(line) for line in raw.decode().splitlines() if line.startswith('{')]
if (len(rows) != 5 or {r['metadata_scenario'] for r in rows} != set(range(5))
        or any(r['status'] != 'passed' or r['acl_status'] == 0 for r in rows)
        or rows != smoke['records']['negative']):
    raise SystemExit('Prior raw native metadata evidence is incomplete')
outputs = ['smoke_stability.json', 'python_smoke.log'] if os.environ['task_mode'] == 'smoke' else [
    'public_accuracy.json', 'public_accuracy.log', 'extended_accuracy.json', 'extended_accuracy.log',
    'engineering.json', 'engineering.log', 'memory.json', 'memory.log', 'aclnn_invalid_metadata.log']
phase = 'smoke_phase' if os.environ['task_mode'] == 'smoke' else 'correctness_phase'
outputs += ['environment_' + phase + '.json', 'device_' + phase + '.txt',
            'device_mapping_' + phase + '.txt', 'device_mapping_' + phase + '.json',
            'selected_device_' + phase + '.txt']
for name in outputs:
    path = folder / name
    if path.exists() or path.is_symlink():
        raise SystemExit('Preserve prior output: ' + str(path))
if os.environ['task_mode'] == 'correctness':
    with (folder / 'aclnn_invalid_metadata.log').open('xb') as out:
        out.write(raw)
record = {'source_commit': commit, 'extension_sha256': binding['sha256'],
          'native_files_verified': len(seen), 'reused_native_negative_sha256': hashlib.sha256(raw).hexdigest(),
          'physical_device': 3, 'runtime_selector': 1, 'logical_device': 0, 'performance_executed': False}
with (Path(os.environ['task_evidence']) / 'identity.json').open('x') as out:
    json.dump(record, out, indent=2); out.write('\n')
print(json.dumps(record))
PY

phase_device_inventory selected
python tools/check_environment.py --input "artifacts/validation/environment_$T5_PHASE.json" --accepted-driver 26.1.1
python tools/fingerprint.py --output "$task_evidence/source_before.json"

if [[ "$task_mode" == smoke ]]; then
  # Same 4 cases x 2 entries x 20 repeats as scripts/phase_smoke.sh.
  # Native C++ smoke is already preserved and verified above, so is not repeated.
  python - <<'PY' > artifacts/validation/python_smoke.log 2>&1
import json, math, torch, torch_npu
import solution, generate_data, golden, verify
from pathlib import Path
torch.npu.set_device(0)
cases = json.loads(Path('reference/case.json').read_text())
records = []
selected = []
for dtype in ('float16', 'bfloat16'):
    matching = [c for c in cases if c['input_desc'][0]['data_type'] == dtype]
    selected.extend((matching[0], max(matching, key=lambda c: math.prod(c['input_desc'][1]['shape']))))
for case in selected:
    arrays = generate_data.generate(case)
    attrs = {a['name']: a['value'] for a in case['attr_desc']}
    inputs = verify.device_inputs(case, arrays, 'npu:0')
    expected = golden.calculate(arrays, attrs)
    for entry in ('run', 'run_direct'):
        fn = getattr(solution, entry)
        for repeat in range(20):
            out = fn(inputs, attrs); torch.npu.synchronize()
            verify.validate_ownership(inputs, out)
            verify.compare(case, arrays, out, expected)
        records.append(dict(case_name=case['case_name'], entry=entry, repeats=20, status='passed'))
        print(records[-1], flush=True)
with Path('artifacts/validation/smoke_stability.json').open('x') as output:
    json.dump(dict(status='passed', npu_executed=True, records=records), output, indent=2)
    output.write('\n')
PY
else
  python reference/verify.py --device 0 --solution-file "$TASK_ROOT/solution.py" --report artifacts/validation/public_accuracy.json > artifacts/validation/public_accuracy.log 2>&1
  python tests/npu_suite.py --device 0 --group accuracy --report artifacts/validation/extended_accuracy.json > artifacts/validation/extended_accuracy.log 2>&1
  python tests/npu_suite.py --device 0 --group engineering --report artifacts/validation/engineering.json > artifacts/validation/engineering.log 2>&1
  python tests/npu_suite.py --device 0 --group memory --report artifacts/validation/memory.json > artifacts/validation/memory.log 2>&1
fi

python tools/fingerprint.py --output "$task_evidence/source_after.json"
python - <<'PY'
import hashlib, json, math, os
from pathlib import Path
root = Path(os.environ['TASK_ROOT'])
folder = root / 'artifacts/validation'
evidence = Path(os.environ['task_evidence'])
identity = json.loads((evidence / 'identity.json').read_text())
commit = identity['source_commit']
for name in ('source_before.json', 'source_after.json'):
    data = json.loads((evidence / name).read_text())
    if data['source_commit'] != commit or data['worktree_status'] != 'archive verified':
        raise SystemExit('Source changed: ' + name)
binding = json.loads((folder / 'binding_import.json').read_text())
if hashlib.sha256(Path(binding['extension']).read_bytes()).hexdigest() != identity['extension_sha256']:
    raise SystemExit('Extension changed during functional tests')
native = json.loads((folder / 'native_binary_manifest.json').read_text())
for item in native['files']:
    raw = Path(item['path']).read_bytes()
    if len(raw) != item['bytes'] or hashlib.sha256(raw).hexdigest() != item['sha256']:
        raise SystemExit('Native binary changed during functional tests')
requirements = json.loads((root / 'reference/coverage_requirements.json').read_text())
cases = json.loads((root / 'reference/case.json').read_text())
counts = {}
def load(name, key, expected, entry=None):
    report = json.loads((folder / name).read_text())
    if report.get('status') != 'passed' or report.get('npu_executed') is not True:
        raise SystemExit('Missing passing device result: ' + name)
    records = report[key]
    keys = [(r['case_name'], r.get('entry', entry)) for r in records]
    if len(keys) != len(set(keys)) or set(keys) != set(expected) or any(r.get('status') != 'passed' for r in records):
        raise SystemExit('Incomplete/duplicate/unexpected functional coverage: ' + name)
    counts[name] = len(records)
    return records
if os.environ['task_mode'] == 'smoke':
    selected = []
    for dtype in ('float16', 'bfloat16'):
        matching = [c for c in cases if c['input_desc'][0]['data_type'] == dtype]
        selected += [matching[0]['case_name'], max(matching, key=lambda c: math.prod(c['input_desc'][1]['shape']))['case_name']]
    rows = load('smoke_stability.json', 'records', [(name, e) for name in selected for e in ('run', 'run_direct')])
    if any(r['repeats'] != 20 for r in rows):
        raise SystemExit('Incomplete repeated-output checks')
else:
    load('public_accuracy.json', 'cases', [(name, 'run') for name in requirements['public_cases']], 'run')
    expected = [(name, 'run_direct') for name in requirements['public_cases']]
    expected += [(name, e) for name in requirements['extra_input_case_ids'] for e in requirements['extra_entries']]
    expected += [(name, e) for name in requirements['negative_scenarios'] for e in requirements['negative_entries']]
    expected += [(name, 'verifier') for name in requirements['verifier_checks']]
    expected += [('cache_policy_odd_boundary_' + dtype, e) for dtype in ('float16', 'bfloat16') for e in ('run', 'run_direct')]
    load('extended_accuracy.json', 'records', expected)
    perf = [c for c in cases if c.get('performance')]
    expected = [('executor_address_refresh_' + c['case_name'], 'run') for c in (perf[1], perf[6])]
    expected += [(name, 'prepared_stream') for name in requirements['stream_case_ids']]
    expected += [('prepared_metadata_' + str(i), 'prepare') for i in range(5)]
    expected += [(name, e) for name in ('sequential_cache_append', 'output_lifetime', 'input_release_cross_stream') for e in ('run', 'run_direct')]
    rows = load('engineering.json', 'records', expected)
    if any(r.get('calls', 0) < requirements['min_prepared_calls_per_stream'] for r in rows if r['entry'] == 'prepared_stream'):
        raise SystemExit('Incomplete stream repeat count')
    rows = load('memory.json', 'records', [(name, e) for name in requirements['performance_case_ids'] for e in ('run', 'run_direct')])
    for r in rows:
        if (r['workspace_bytes'] != 0 or r['peak_increment'] > r['output_bytes'] + 16384
                or len(r['after_each_release']) != 20 or any(v != r['before'] for v in r['after_each_release'])):
            raise SystemExit('Memory acceptance failed')
summary = {'status': 'passed_functional_only', 'phase': os.environ['task_mode'], 'source_commit': commit,
           'npu_executed': True, 'performance_executed': False, 'counts': counts,
           'limitation': 'No performance measured or accepted; phase exit also requires post-process clearance.'}
with (evidence / 'summary.json').open('x') as output:
    json.dump(summary, output, indent=2); output.write('\n')
print(json.dumps(summary))
PY
