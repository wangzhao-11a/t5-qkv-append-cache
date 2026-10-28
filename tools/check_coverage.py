"""Fail closed on missing, duplicate, failed, or non-device coverage evidence."""
import argparse
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def evaluate(directory):
    requirements=json.loads((ROOT/'reference/coverage_requirements.json').read_text(encoding='utf-8'))
    problems=[]
    def load(name):
        path=directory/name
        if not path.is_file():problems.append(f'missing {name}');return {}
        data=json.loads(path.read_text(encoding='utf-8'))
        if data.get('status')!='passed' or data.get('npu_executed') is not True:
            problems.append(f'{name}: not passed on device')
        return data
    def keys(data,field='records',default_entry=None):
        found=set()
        for item in data.get(field,[]):
            key=(item.get('case_name'),item.get('entry',default_entry))
            if key in found:problems.append(f'duplicate record: {key}')
            if item.get('status','passed')!='passed':problems.append(f'failed record: {key}')
            found.add(key)
        return found
    def require(found,expected,label):
        for key in sorted(set(expected)-found):problems.append(f'{label}: missing {key}')
    public=load('public_accuracy.json')
    require(keys(public,'cases','run'),[(x,'run') for x in requirements['public_cases']],'public')
    extra=load('extended_accuracy.json');found=keys(extra)
    expected=[(x,'run_direct') for x in requirements['public_cases']]
    expected += [(x,e) for x in requirements['extra_input_case_ids'] for e in requirements['extra_entries']]
    expected += [(x,e) for x in requirements['negative_scenarios'] for e in requirements['negative_entries']]
    expected += [(x,'verifier') for x in requirements['verifier_checks']]
    require(found,expected,'extended')
    eng=load('engineering.json');found=keys(eng)
    expected=[(x,'prepared_stream') for x in requirements['stream_case_ids']]
    expected += [(f'prepared_metadata_{i}','prepare') for i in range(5)]
    expected += [(x,e) for x in ('sequential_cache_append','output_lifetime','input_release_cross_stream') for e in ('run','run_direct')]
    require(found,expected,'engineering')
    for item in eng.get('records',[]):
        if item.get('entry')=='prepared_stream' and item.get('calls',0)<10:problems.append('stream prepared calls < 10')
    mem=load('memory.json');found=keys(mem)
    require(found,[(x,e) for x in requirements['performance_case_ids'] for e in ('run','run_direct')],'memory')
    for item in mem.get('records',[]):
        if item.get('workspace_bytes')!=0:problems.append('nonzero workspace')
        if item.get('peak_increment',float('inf'))>item.get('output_bytes',0)+16384:problems.append('memory peak exceeded')
        history=item.get('after_each_release',[])
        if len(history)!=20 or any(n!=item.get('before') for n in history):problems.append('memory not reclaimed')
    performance=load('performance.json')
    from importlib.util import spec_from_file_location,module_from_spec
    spec=spec_from_file_location('frozen_performance_checker',ROOT/'reference/check_performance.py')
    checker=module_from_spec(spec);spec.loader.exec_module(checker)
    targets=json.loads((ROOT/'reference/performance_targets.json').read_text(encoding='utf-8'))
    cases=json.loads((ROOT/'reference/case.json').read_text(encoding='utf-8'))
    try:
        perf_result=checker.evaluate(performance,targets,cases)
        if perf_result['status']!='passed':problems.append('fixed performance limits/protocol failed')
    except Exception as exc:problems.append(f'performance evidence invalid: {exc}')
    baseline=load('baseline_comparison.json')
    require(keys(baseline,'cases','baseline'),[(x,'baseline') for x in requirements['performance_case_ids']],'baseline')
    metadata=directory/'aclnn_invalid_metadata.log'
    if not metadata.exists():problems.append('missing raw ACLNN metadata checks')
    else:
        checks=[json.loads(line) for line in metadata.read_text(encoding='utf-8').splitlines() if line.startswith('{"metadata_scenario"')]
        if {x['metadata_scenario'] for x in checks if x['status']=='passed'}!=set(range(5)):
            problems.append('incomplete raw ACLNN metadata checks')
    return {'status':'failed' if problems else 'passed','problems':problems,
            'scope':'Automated coverage only. Environment evidence, build artifacts and source fingerprints also require review.'}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--reports',type=Path,required=True);args=p.parse_args()
    result=evaluate(args.reports)
    args.reports.mkdir(parents=True,exist_ok=True)
    (args.reports/'coverage_acceptance.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))
    raise SystemExit(0 if result['status']=='passed' else 1)
