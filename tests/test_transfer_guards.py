"""Offline guards for large evidence and incomplete downloads."""
import sys
import stat
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from remote_session import download_preflight, ensure_upload_parent


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


class UploadParentGuards(unittest.TestCase):
    def test_creates_missing_nested_parent_before_upload(self):
        existing = {'/', '/tmp'}
        def remote_stat(path):
            if path not in existing:
                raise FileNotFoundError(path)
            return SimpleNamespace(st_mode=stat.S_IFDIR | 0o755)
        sftp = Mock()
        sftp.stat.side_effect = remote_stat
        sftp.mkdir.side_effect = existing.add
        ensure_upload_parent(sftp, '/tmp/t5_guard/tools/check.py')
        self.assertEqual([call.args[0] for call in sftp.mkdir.call_args_list],
                         ['/tmp/t5_guard', '/tmp/t5_guard/tools'])
        sftp.put.assert_not_called()

    def test_rejects_relative_or_traversal_without_remote_mutation(self):
        for path in ('relative/check.py', '/tmp/../check.py'):
            sftp = Mock()
            with self.subTest(path=path), self.assertRaises(ValueError):
                ensure_upload_parent(sftp, path)
            sftp.stat.assert_not_called()
            sftp.mkdir.assert_not_called()

    def test_existing_file_parent_is_not_overwritten(self):
        sftp = Mock()
        sftp.stat.return_value = SimpleNamespace(st_mode=stat.S_IFREG | 0o644)
        with self.assertRaises(NotADirectoryError):
            ensure_upload_parent(sftp, '/tmp/check.py')
        sftp.mkdir.assert_not_called()


if __name__ == '__main__':
    unittest.main()
