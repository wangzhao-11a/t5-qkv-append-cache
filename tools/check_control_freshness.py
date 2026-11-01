"""Reject stale or incomplete controls before a new timed comparison."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path


def check_report(report, solution, now, max_age_seconds=1800):
    if report.get('solution_file') != solution:
        raise ValueError('Control belongs to a different runtime source')
    if report.get('protocol') != {'warmup':50,'iterations':200,'rounds':5}:
        raise ValueError('Control protocol mismatch')
    if (report.get('npu_executed') is not True or 'error' in report or 'active_case' in report
            or len(report.get('cases',[])) != 10
            or len(report.get('performance_checks',{}).get('checks',[])) != 10):
        raise ValueError('Control did not complete all ten cases')
    end=datetime.fromisoformat(report['finished_at_utc'])
    if end.tzinfo is None:
        raise ValueError('Control timestamp has no timezone')
    age=(now-end).total_seconds()
    if not 0 <= age <= max_age_seconds:
        raise ValueError(f'Control age {age:.1f}s is outside [0, {max_age_seconds}]')
    return {'status':'passed','control_solution':solution,'control_finished_at_utc':report['finished_at_utc'],
            'age_seconds':age,'max_age_seconds':max_age_seconds,
            'scope':'Temporal comparison guard; does not prove identical physical memory placement.'}


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--report',type=Path,required=True)
    parser.add_argument('--solution',required=True)
    parser.add_argument('--source-commit',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    assert args.report.with_suffix('.exit').read_text().strip()=='0', 'Control stage did not finish cleanly'
    report=json.loads(args.report.read_text())
    solution=Path(args.solution)
    source=json.loads((solution.parent/'DEPLOYMENT_MANIFEST.json').read_text())
    assert source['commit']==args.source_commit, 'Control deployment changed'
    assert hashlib.sha256(solution.read_bytes()).hexdigest()==report['solution_file_sha256']
    result=check_report(report,args.solution,datetime.now(timezone.utc))
    result.update(control_report=str(args.report),control_source_commit=args.source_commit)
    with args.output.open('x',encoding='utf-8',newline='\n') as output:
        json.dump(result,output,indent=2)
        output.write('\n')
    print(json.dumps(result))
