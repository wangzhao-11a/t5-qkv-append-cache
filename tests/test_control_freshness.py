"""CPU-only rejection checks for the performance control gate."""
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from check_control_freshness import check_report


class ControlFreshnessTests(unittest.TestCase):
    def setUp(self):
        self.now=datetime(2026,11,1,12,tzinfo=timezone.utc)
        self.solution='/baseline/solution.py'
        self.report={'status':'failed','solution_file':self.solution,'npu_executed':True,
            'protocol':{'warmup':50,'iterations':200,'rounds':5},'cases':[{}]*10,
            'performance_checks':{'checks':[{}]*10},
            'finished_at_utc':(self.now-timedelta(seconds=60)).isoformat()}

    def test_completed_control_can_fail_fixed_limits(self):
        self.assertEqual(check_report(self.report,self.solution,self.now)['age_seconds'],60)

    def test_old_control_rejected(self):
        self.report['finished_at_utc']=(self.now-timedelta(hours=5)).isoformat()
        with self.assertRaises(ValueError):check_report(self.report,self.solution,self.now)

    def test_future_or_naive_timestamp_rejected(self):
        for timestamp in ((self.now+timedelta(seconds=1)).isoformat(),'2026-11-01T12:00:00'):
            with self.subTest(timestamp=timestamp),self.assertRaises(ValueError):
                check_report({**self.report,'finished_at_utc':timestamp},self.solution,self.now)

    def test_wrong_source_rejected(self):
        with self.assertRaises(ValueError):check_report(self.report,'/another/solution.py',self.now)

    def test_wrong_protocol_rejected(self):
        self.report['protocol']['iterations']=20
        with self.assertRaises(ValueError):check_report(self.report,self.solution,self.now)

    def test_incomplete_or_errored_control_rejected(self):
        for patch in ({'cases':[{}]*9},{'npu_executed':False},{'error':'failure'},
                      {'active_case':'unfinished'},{'performance_checks':{'checks':[]}}):
            with self.subTest(patch=patch),self.assertRaises(ValueError):
                check_report({**self.report,**patch},self.solution,self.now)


if __name__=='__main__':unittest.main()
