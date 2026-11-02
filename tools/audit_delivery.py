"""Read-only task-delivery audit; never runs a device test or an installer."""
import argparse
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import re
import tarfile
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SEVEN = ['1 自验证步骤说明.md', '2.1 精度自验证报告.xlsx', '2.2 精度自验证日志.log',
         '3.1 性能自验证报告.xlsx', '3.2 性能自验证日志.log',
         '4.1 内存自验证报告.xlsx', '4.2 内存自验证日志.log']
REQUIRED = [
    'docs/design.md', 'docs/SELF_VALIDATION_20261101.md',
    'common/t5_plan.h', 'op_host/t5_split_qkv_append_cache.cpp',
    'op_host/t5_split_qkv_append_cache_tiling.h', 'op_kernel/t5_copy.h',
    'op_kernel/t5_split_qkv_append_cache.cpp', 'op_project.json',
    'csrc/torch_binding.cpp', 'solution.py', 'setup.py',
    'direct/t5_direct.cpp', 'direct/CMakeLists.txt',
    'examples/aclnn_example.cpp', 'examples/CMakeLists.txt',
    'scripts/build.sh', 'scripts/validate.sh', 'tests/npu_suite.py',
    'tests/compare_baseline.py', 'reference/case.json', 'reference/golden.py',
    'reference/generate_data.py', 'reference/verify.py', 'reference/benchmark.py',
    'reference/check_performance.py', 'reference/coverage_requirements.json',
    'artifacts/custom_opp_openEuler_aarch64.run',
    'reports/accepted_f526712/binary_manifest.json', 'reports/STATUS_latest.json',
    'evidence/accepted/collector_receipt.json',
    'evidence/accepted/t5_evidence_f52671207769.tar.gz',
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def audit(archive):
    errors, checks = [], []

    def check(ok, label):
        checks.append({'check': label, 'passed': bool(ok)})
        if not ok:
            errors.append(label)

    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        check(z.testzip() is None, 'ZIP CRC')
        check(len(names) == len(set(names)), 'No duplicate ZIP entries')
        check(all(not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts
                  and n.startswith('t5_qkv_task/') for n in names), 'Safe single-root ZIP layout')
        files = {n.removeprefix('t5_qkv_task/'): z.read(n) for n in names}
    manifest = json.loads(files['DELIVERY_MANIFEST.json'])
    tested = manifest['tested_runtime_source_commit']
    records = manifest['files']
    check(len(records) == len({r['path'] for r in records}), 'Unique manifest entries')
    check(set(files) == {r['path'] for r in records} | {'DELIVERY_MANIFEST.json'},
          'Manifest covers every packaged file')
    check(all(r['path'] in files and len(files[r['path']]) == r['bytes']
              and sha(files[r['path']]) == r['sha256'] for r in records), 'Every file size and SHA256')
    check(all(files.get(p) for p in REQUIRED), 'Required engineering/source/test/evidence files')

    def load(p):
        return json.loads(files[p])

    reference = load('reference_manifest.json')
    check(all(sha(files[r['path']]) == r['sha256'] for r in reference['files']), 'Frozen reference files')
    check(sha(files['reference/case.json']) ==
          '9ce34ba31fc08abe1969ad4997f7b6173fa950533473d6977398a8ed4db741e8', 'Original 35-case file')
    with zipfile.ZipFile(io.BytesIO(files['task_submission.zip'])) as sub:
        check(sub.testzip() is None and len(sub.namelist()) == 7 and set(sub.namelist()) == set(SEVEN),
              'Nested task_submission.zip exactly matches seven official names')
        check(all(files.get('task_submission/' + n) == sub.read(n) for n in SEVEN),
              'Seven unpacked materials equal nested ZIP bytes')
    with zipfile.ZipFile(io.BytesIO(files['evidence/template/task_submission.zip'])) as template:
        check(set(template.namelist()) == set(SEVEN), 'Official template file names')
    check(sha(files['evidence/template/task_submission.zip']) ==
          manifest['submission_template']['sha256'], 'Official template fingerprint')
    check(tested in files['task_submission/' + SEVEN[0]].decode('utf-8'), 'Instructions identify tested commit')

    sm = load(f'artifacts/source_{tested[:12]}.manifest.json')
    raw = files[f'artifacts/source_{tested[:12]}.tar']
    check(sm['commit'] == tested and sha(raw) == sm['archive_sha256'], 'Exact tested source archive')
    with tarfile.open(fileobj=io.BytesIO(raw)) as t:
        source = {m.name: t.extractfile(m).read() for m in t if m.isfile()}
    check(all(r['path'] in source and sha(source[r['path']]) == r['sha256'] for r in sm['files']),
          'Every tested source file SHA256')
    runtime_dirs = {'common', 'csrc', 'direct', 'examples', 'op_host', 'op_kernel'}
    runtime_files = {'solution.py', 'setup.py', 'op_project.json'}
    runtime_names = [n for n in files if n.split('/')[0] in runtime_dirs or n in runtime_files]
    check(all(files[n] == source[sm['prefix'] + '/' + n] for n in runtime_names),
          'Delivery runtime equals tested runtime')

    bm = load('reports/accepted_f526712/binary_manifest.json')
    check(bm['build_source_commit'] == tested and all(
        sha(files[r['path']]) == r['sha256'] and len(files[r['path']]) == r['bytes']
        for r in bm['files']), 'Tested binaries and source provenance')
    run = files['artifacts/custom_opp_openEuler_aarch64.run']
    skip = int(re.search(br'\nskip="(\d+)"', run[:4000]).group(1))
    payload = run.split(b'\n', skip)[skip]
    expected = re.search(br'\nSHA="(\w+)"', run[:1000]).group(1).decode()
    check(sha(payload) == expected, 'Makeself payload SHA256 (installer not executed)')
    with tarfile.open(fileobj=io.BytesIO(payload)) as t:
        headers = [m for m in t if m.name.endswith('/aclnn_t5_split_qkv_append_cache.h')]
        header = t.extractfile(headers[0]).read() if len(headers) == 1 else b''
        check(all(s in header for s in (b'aclnnT5SplitQkvAppendCacheGetWorkspaceSize',
                                      b'aclnnT5SplitQkvAppendCache(')), 'Two-stage API header inside .run')
        check(any(m.name.endswith('/op_api/lib/libcust_opapi.so') for m in t), 'ACLNN API library inside .run')
    receipt = load('evidence/accepted/collector_receipt.json')
    check(sha(files['evidence/accepted/t5_evidence_f52671207769.tar.gz']) == receipt['sha256'],
          'Original device evidence archive SHA256')

    # Existing task checker revalidates raw results; no device work and no rewrites.
    spec = importlib.util.spec_from_file_location('delivery_coverage', ROOT / 'tools/check_coverage.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    scratch = (ROOT / '.codex-tmp/delivery_audit').resolve()
    directory = (scratch / uuid.uuid4().hex).resolve()
    if not directory.is_relative_to(ROOT.resolve()):
        raise ValueError('Audit scratch directory escaped the workspace')
    directory.mkdir(parents=True, exist_ok=False)
    for name, data in files.items():
        if name.startswith('reports/accepted_f526712/'):
            (directory / PurePosixPath(name).name).write_bytes(data)
    (directory / 'aclnn_invalid_metadata.log').write_bytes(
        files['evidence/tested/reports/aclnn_invalid_metadata.log'])
    coverage = module.evaluate(directory)
    check(coverage['status'] == 'passed', 'Raw accuracy/engineering/memory/performance coverage recheck')

    stage_envs = [load('evidence/tested/reports/' + n)['inventory']['versions'] for n in
                 ('environment_correctness_phase.json', 'environment_performance_phase.json')]
    summary_env = load('reports/STATUS_latest.json')['environment']
    check(all(all(summary_env[k] == stage[k] for k in ('torch', 'torch_npu', 'numpy', 'ml_dtypes'))
              for stage in stage_envs), 'Environment summary matches actual test phases')
    design = files['docs/design.md'].decode('utf-8')
    check(tested in design and all(s in design for s in ('cachedKeyBegin_', 'alignedFragments_', 'aclSetTensorAddr')),
          'Design names tested revision and retained optimization mechanisms')
    stale = '算子实现尚未满足全部固定性能门槛' in files['docs/community_review_draft.md'].decode('utf-8')
    check(not stale, 'Community draft no longer describes old baseline as current')
    publication_path = 'reports/publication_status_20261103.json'
    check(publication_path in files, 'Publication metadata and pending items explicitly recorded')
    publication = load(publication_path) if publication_path in files else {'pending': [
        'Publish personal implementation repository/branch/directory/fixed commit',
        'Synchronize latest design and obtain community review', 'Submit implementation PR']}
    return {
        'archive': str(archive.resolve()), 'archive_sha256': sha(archive.read_bytes()),
        'delivery_commit': manifest['delivery_commit'], 'tested_runtime_source_commit': tested,
        'file_count': len(files), 'manifest_file_count': len(records),
        'status': 'needs_local_revision' if errors else 'local_materials_complete_external_publication_pending',
        'checks': checks, 'errors': errors, 'coverage': coverage, 'publication': publication,
        'npu_rerun': False,
        'limitations': ['Driver 26.1.1 accepted by user; required 25.5.t6.b001 untested',
                        'Original task prose ratio threshold is inconsistent; frozen absolute checker used',
                        'No onsite screenshots; raw logs provided',
                        'No paired reference active-memory result; not fabricated'],
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise SystemExit('Preserve existing audit; choose a new output')
    result = audit(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: result[k] for k in ('status', 'file_count', 'errors', 'archive_sha256')}))
    raise SystemExit(1 if result['errors'] else 0)
