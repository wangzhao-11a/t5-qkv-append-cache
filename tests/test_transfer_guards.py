"""Offline guards for large evidence and incomplete downloads."""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from remote_session import download_preflight


class DownloadGuards(unittest.TestCase):
    def test_large_raw_evidence_requires_compression(self):
        for suffix in ('.log', '.txt', '.json', '.csv'):
            with self.subTest(suffix=suffix), patch.object(Path, 'exists', return_value=False):
                with self.assertRaisesRegex(ValueError, 'Compress'):
                    download_preflight('/tmp/evidence' + suffix, Path('evidence' + suffix), 9 * 1024 * 1024)

    def test_compressed_archive_is_allowed(self):
        with patch.object(Path, 'exists', return_value=False):
            self.assertEqual(download_preflight('/tmp/evidence.tar.gz', Path('evidence.tar.gz'), 35 * 1024 * 1024),
                             Path('evidence.tar.gz.part'))

    def test_previous_partial_is_preserved(self):
        with patch.object(Path, 'exists', return_value=True):
            with self.assertRaises(FileExistsError):
                download_preflight('/tmp/evidence.tar.gz', Path('evidence.tar.gz'), 32)


if __name__ == '__main__':
    unittest.main()
