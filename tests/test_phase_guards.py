"""Linux-only regression checks; never imports torch or touches an NPU."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform.startswith('linux'), 'Run native Linux phase guards on the remote host')
class PhaseGuards(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.commit = 'a' * 40
        self.root = Path(self.temp.name) / ('t5_qkv_' + self.commit[:12])
        (self.root / 'scripts').mkdir(parents=True)
        data = (ROOT / 'scripts/phase_common.sh').read_bytes()
        (self.root / 'scripts/phase_common.sh').write_bytes(data)
        manifest = dict(commit=self.commit, prefix=self.root.name, files=[dict(
            path=self.root.name + '/scripts/phase_common.sh', bytes=len(data),
            sha256=hashlib.sha256(data).hexdigest())])
        (self.root / 'DEPLOYMENT_MANIFEST.json').write_text(json.dumps(manifest), encoding='utf-8')
        self.phase = self.root / 'scripts/test.sh'
        self.phase.write_text('set -euo pipefail\nsource "$(dirname "$0")/phase_common.sh"\n'
                              'phase_begin test "${1:-}"\nprintf "original evidence\\n"\n', encoding='utf-8')

    def run_phase(self, *args):
        return subprocess.run(['bash', str(self.phase), *args], capture_output=True)

    def test_success_and_retry_preserves_evidence(self):
        self.assertEqual(self.run_phase().returncode, 0)
        log = self.root / 'artifacts/validation/test.log'
        exit_file = log.with_suffix('.exit')
        before = (log.read_bytes(), exit_file.read_bytes())
        self.assertNotEqual(self.run_phase().returncode, 0)
        self.assertEqual(before, (log.read_bytes(), exit_file.read_bytes()))

    def test_missing_prerequisite_creates_no_phase_log(self):
        self.assertNotEqual(self.run_phase('build_full').returncode, 0)
        self.assertFalse((self.root / 'artifacts/validation/test.log').exists())

    def test_changed_source_rejected_before_logs(self):
        with (self.root / 'scripts/phase_common.sh').open('ab') as f:
            f.write(b'\n# changed\n')
        self.assertNotEqual(self.run_phase().returncode, 0)
        self.assertFalse((self.root / 'artifacts').exists())

    def test_wrong_deployment_name_rejected(self):
        renamed = self.root.with_name('t5_qkv_' + 'b' * 12)
        self.root.rename(renamed)
        self.root, self.phase = renamed, renamed / 'scripts/test.sh'
        self.assertNotEqual(self.run_phase().returncode, 0)
        self.assertFalse((self.root / 'artifacts').exists())

    def test_existing_launch_lock_rejected(self):
        (self.root / 'artifacts/validation/test.lock').mkdir(parents=True)
        self.assertNotEqual(self.run_phase().returncode, 0)
        self.assertFalse((self.root / 'artifacts/validation/test.log').exists())

    def test_term_records_signal_failure_instead_of_previous_success(self):
        self.phase.write_text('set -euo pipefail\nsource "$(dirname "$0")/phase_common.sh"\n'
                              'phase_begin test\nwhile :; do sleep 0.1; done\n', encoding='utf-8')
        process = subprocess.Popen(['bash', str(self.phase)], stdout=subprocess.DEVNULL)
        try:
            deadline = time.monotonic() + 5
            while not (self.root / 'artifacts/validation/test.log').exists():
                self.assertIsNone(process.poll())
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.02)
            process.terminate()
            self.assertEqual(process.wait(timeout=5), 143)
            self.assertEqual((self.root / 'artifacts/validation/test.exit').read_text().strip(), '143')
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)


if __name__ == '__main__':
    unittest.main()
