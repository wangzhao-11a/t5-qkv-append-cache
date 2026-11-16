#!/usr/bin/env bash
# CPU-only actual-header checks. Does not initialize or execute an NPU.
set -euo pipefail
if [[ $# != 3 ]]; then
  echo 'Usage: run_host_semantics_20261116.sh CANDIDATE_SOURCE F526_SOURCE NEW_LOG_DIRECTORY' >&2
  exit 2
fi
for task_command in python3 c++ sha256sum; do
  command -v "$task_command" >/dev/null || { echo "Missing existing tool: $task_command" >&2; exit 2; }
done
task_candidate=$(cd -- "$1" && pwd -P)
task_baseline=$(cd -- "$2" && pwd -P)
[[ "$task_candidate" != "$task_baseline" ]] || { echo 'Candidate and baseline must be separate source directories' >&2; exit 2; }
# Deliberately no mkdir -p: an existing output directory is never reused.
mkdir -- "$3"
task_logs=$(cd -- "$3" && pwd -P)

finish() {
  task_exit=$?
  trap - EXIT
  task_summary_exit=0
  python3 - "$task_candidate" "$task_baseline" "$task_logs" "$task_exit" <<'PY' || task_summary_exit=$?
import hashlib
import json
from pathlib import Path
import sys

candidate, baseline, logs = map(Path, sys.argv[1:4])
shell_exit = int(sys.argv[4])
stages = ('verify_sources', 'compiler_version', 'baseline_compile', 'baseline_run', 'candidate_compile', 'candidate_run')
report = {
    'purpose': 'CPU actual-header semantic checks; not CANN/device/performance acceptance',
    'candidate_source_commit': 'a2013d56db4ff8367160b157335d2ff670aad411',
    'baseline_source_commit': 'f52671207769bf5f334972c997743eb6aa6f91b3',
    'candidate_directory': str(candidate), 'baseline_directory': str(baseline),
    'log_directory': str(logs), 'shell_exit_code': shell_exit,
    'npu_executed': False, 'cann_compiled': False,
    'stages': {}, 'versions': {}, 'errors': [],
}
for stage in stages:
    path = logs / (stage + '.exit')
    code = int(path.read_text().strip()) if path.exists() else None
    report['stages'][stage] = {'exit_code': code, 'status': 'not_run' if code is None else ('passed' if code == 0 else 'failed')}
    if code != 0:
        report['errors'].append(stage + ': incomplete or failed')
identity = logs / 'verified_sources.json'
if identity.is_file():
    report['verified_sources'] = json.loads(identity.read_text())
for version in ('baseline', 'candidate'):
    if report['stages'][version + '_run']['exit_code'] != 0:
        continue
    try:
        records = [json.loads(line) for line in (logs / (version + '_run.log')).read_text().splitlines()]
        if len(records) != 9:
            raise ValueError('expected eight large-case rows plus one final summary')
        summary = records[-1]
        if (summary.get('status') != 'passed' or type(summary.get('host_semantic_cases')) is not int
                or summary['host_semantic_cases'] != 776 or summary.get('npu_executed') is not False
                or summary.get('cann_compiled') is not False):
            raise ValueError('missing successful 776-case host-only summary')
        expected = {(dtype, offset) for dtype in ('fp16', 'bf16') for offset in (0, 1, 2, 4)}
        found = set()
        for row in records[:-1]:
            key = (row.get('dtype_bits'), row.get('offset_mask'))
            if row.get('case') != 'large' or type(row.get('offset_mask')) is not int or key not in expected or key in found:
                raise ValueError('invalid, duplicate or missing large-case record')
            found.add(key)
            if any(type(row.get(k)) is not int or row[k] < 0 for k in ('dma_read', 'pad_read', 'dma_write', 'pad_write')):
                raise ValueError('invalid DMA counters')
        if found != expected:
            raise ValueError('large-case coverage is incomplete')
        binary = logs / version / 'test_t5_copy'
        report['versions'][version] = {'records': records, 'executable_sha256': hashlib.sha256(binary.read_bytes()).hexdigest()}
    except (OSError, ValueError, KeyError, TypeError) as error:
        report['errors'].append(version + ': ' + str(error))
report['status'] = 'passed_host_semantics_only' if shell_exit == 0 and not report['errors'] else 'failed_or_incomplete'
with (logs / 'summary.json').open('x', encoding='utf-8', newline='\n') as handle:
    json.dump(report, handle, indent=2)
    handle.write('\n')
print(json.dumps({'status': report['status'], 'summary': str(logs / 'summary.json'), 'errors': report['errors']}))
raise SystemExit(0 if report['status'] == 'passed_host_semantics_only' else 1)
PY
  if [[ "$task_exit" != 0 ]]; then exit "$task_exit"; fi
  exit "$task_summary_exit"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

run_stage() {
  local task_stage="$1" task_rc
  shift
  if "$@" > "$task_logs/$task_stage.log" 2>&1; then task_rc=0; else task_rc=$?; fi
  printf '%s\n' "$task_rc" > "$task_logs/$task_stage.exit"
  printf '%s exit=%s\n' "$task_stage" "$task_rc"
  return "$task_rc"
}

run_stage verify_sources python3 - "$task_candidate" "$task_baseline" "$task_logs" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

candidate, baseline, logs = map(Path, sys.argv[1:])
expected = {
    'candidate_kernel': (candidate / 'op_kernel/t5_copy.h', '2f1f39b85e2ab621ec626754d294e37f51761ee3ddc8af54c4b4ed5b37c407ff'),
    'baseline_kernel': (baseline / 'op_kernel/t5_copy.h', '80187bdde2fc70e730a1f690dc1c0cfc4bf516a38a2d7988c9e3c0a911ea79c4'),
    'candidate_plan': (candidate / 'common/t5_plan.h', 'dfe4f6bd28d74a76f9243c6555c679c2e8cc656f57db56a2eb9a7d52cbb41a99'),
    'baseline_plan': (baseline / 'common/t5_plan.h', 'dfe4f6bd28d74a76f9243c6555c679c2e8cc656f57db56a2eb9a7d52cbb41a99'),
    'host_adapter': (candidate / 'tests/host_kernel/kernel_operator.h', '605417965936f5485d5804dc1c639382105c45c8e7502cb8a11927c4d734ed57'),
    'host_test': (candidate / 'tests/host_kernel/test_t5_copy.cpp', '512cc3e7f386b745805c062436bd65d8c1e2969cc9c77b364359de57a8dcf926'),
}
records = {}
for name, (path, wanted) in expected.items():
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != wanted:
        raise ValueError(f'{name} SHA256 mismatch: {path}')
    records[name] = {'path': str(path), 'sha256': actual}
for name, root, commit in (
    ('candidate', candidate, 'a2013d56db4ff8367160b157335d2ff670aad411'),
    ('baseline', baseline, 'f52671207769bf5f334972c997743eb6aa6f91b3'),
):
    manifest = root / 'DEPLOYMENT_MANIFEST.json'
    if manifest.exists() and json.loads(manifest.read_text())['commit'] != commit:
        raise ValueError(f'{name} deployment manifest commit mismatch')
    records[name + '_deployment_manifest_present'] = manifest.exists()
with (logs / 'verified_sources.json').open('x', encoding='utf-8', newline='\n') as handle:
    json.dump(records, handle, indent=2)
    handle.write('\n')
print(json.dumps({'status': 'passed', 'hashed_files': len(expected)}))
PY
run_stage compiler_version c++ --version

for task_version in baseline candidate; do
  mkdir -- "$task_logs/$task_version"
  if [[ "$task_version" == baseline ]]; then task_source="$task_baseline"; else task_source="$task_candidate"; fi
  # Copy only the verified real kernel header; the same verified host adapter
  # and test source are used for both versions. Common plan bytes are identical.
  cp -- "$task_source/op_kernel/t5_copy.h" "$task_logs/$task_version/t5_copy.h"
  run_stage "${task_version}_compile" c++ -std=c++17 -O2 -Wall -Wextra \
    -I"$task_logs/$task_version" -I"$task_candidate/tests/host_kernel" -I"$task_candidate" \
    "$task_candidate/tests/host_kernel/test_t5_copy.cpp" -o "$task_logs/$task_version/test_t5_copy"
  run_stage "${task_version}_run" "$task_logs/$task_version/test_t5_copy"
done
