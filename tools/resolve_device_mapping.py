"""Resolve the verified physical allocation from official npu-smi info -m text."""
import argparse
import json
from pathlib import Path
import re


def resolve_mapping(text, selector, physical):
    if not re.fullmatch(r'[0-9]+', str(selector)) or not re.fullmatch(r'[0-9]+', str(physical)):
        raise ValueError('Require one numeric runtime selector and a verified physical ID')
    lines = [line.split() for line in text.splitlines() if line.strip()]
    if not lines or lines[0] != 'NPU ID Chip ID Chip Logic ID Chip Phy-ID Chip Name'.split():
        raise ValueError('Unrecognized npu-smi mapping header')
    devices = []
    for fields in lines[1:]:
        if len(fields) == 5 and fields[2:4] == ['-', '-'] and fields[4] == 'Mcu':
            continue
        if len(fields) != 5 or not all(re.fullmatch(r'[0-9]+', value) for value in fields[:4]):
            raise ValueError('Unrecognized npu-smi mapping row')
        card, chip, logic, phy = map(int, fields[:4])
        devices.append(dict(card=card, chip=chip, selector=logic, physical=phy, chip_name=fields[4]))
    matches = [item for item in devices if item['selector'] == int(selector)]
    if len(matches) != 1 or matches[0]['physical'] != int(physical):
        raise ValueError('Runtime selector does not uniquely match the verified physical allocation')
    selected = matches[0]
    if sum(item['physical'] == selected['physical'] for item in devices) != 1:
        raise ValueError('Ambiguous physical allocation')
    if selected['chip_name'] != 'Ascend910':
        raise ValueError('Unexpected chip family for this fixed acceptance')
    return selected


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--selector', required=True)
    parser.add_argument('--physical', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = resolve_mapping(args.input.read_text(encoding='utf-8'), args.selector, args.physical)
    # Preserve a previous mapping record rather than overwriting evidence.
    with args.output.open('x', encoding='utf-8', newline='\n') as output:
        json.dump(result, output, indent=2)
        output.write('\n')
    print(result['card'], result['chip'])
