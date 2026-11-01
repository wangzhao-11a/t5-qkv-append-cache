"""CPU-only checks for allocation resolution; no runtime or device access."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from resolve_device_mapping import resolve_mapping

HEADER = 'NPU ID Chip ID Chip Logic ID Chip Phy-ID Chip Name\n'
CURRENT = HEADER + '3 0 0 6 Ascend910\n3 1 1 7 Ascend910\n3 2 - - Mcu\n'


class DeviceMappingTests(unittest.TestCase):
    def test_current_container_uses_card_three(self):
        result = resolve_mapping(CURRENT, '1', '7')
        self.assertEqual((result['card'], result['chip'], result['physical']), (3, 1, 7))

    def test_original_container_remains_supported(self):
        result = resolve_mapping(HEADER + '0 0 0 0 Ascend910\n0 1 1 1 Ascend910\n', '1', '1')
        self.assertEqual((result['card'], result['chip']), (0, 1))

    def test_stale_physical_allocation_rejected(self):
        with self.assertRaises(ValueError):
            resolve_mapping(CURRENT, '1', '1')

    def test_ambiguous_selector_rejected(self):
        with self.assertRaises(ValueError):
            resolve_mapping(CURRENT + '0 1 1 1 Ascend910\n', '1', '7')

    def test_unrecognized_output_rejected(self):
        for text in ('', 'Driver error\n', CURRENT + 'unexpected row\n'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                resolve_mapping(text, '1', '7')

    def test_invalid_or_multiple_selectors_rejected(self):
        for selector, physical in [('0,1', '7'), ('1', ''), ('-1', '7'), ('1', '-7')]:
            with self.subTest(selector=selector, physical=physical), self.assertRaises(ValueError):
                resolve_mapping(CURRENT, selector, physical)

    def test_wrong_chip_family_rejected(self):
        with self.assertRaises(ValueError):
            resolve_mapping(CURRENT.replace('Ascend910', 'Ascend950'), '1', '7')


if __name__ == '__main__':
    unittest.main()
