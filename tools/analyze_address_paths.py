"""Summarize existing integer-address probes; never infer actual kernel paths."""
import argparse
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path


CALLS = 1051  # One accuracy call, 50 warmups, then five rounds of 200.
TILE_ELEMENTS = 32768  # f526712, not a claim about the probed binary.


def _object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def _triples(value, label):
    if not isinstance(value, list) or len(value) != CALLS:
        raise ValueError(f"{label}: require exactly {CALLS} calls")
    for index, triple in enumerate(value):
        if not isinstance(triple, list) or len(triple) != 3:
            raise ValueError(f"{label}[{index}]: require three addresses")
        if any(type(address) is not int or not 0 < address < 2**64 for address in triple):
            raise ValueError(f"{label}[{index}]: addresses must be positive uint64 integers")
    return [tuple(triple) for triple in value]


def _alignment_mask(triple):
    return sum(1 << index for index, address in enumerate(triple) if address % 32 == 0)


def _segment(inputs, outputs, shape_eligible, start, end):
    ins, outs = inputs[start:end], outputs[start:end]
    return {
        "call_indices_zero_based": [start, end - 1],
        "calls": end - start,
        "input_32b_aligned_calls_by_tensor": [sum(a[i] % 32 == 0 for a in ins) for i in range(3)],
        "output_32b_aligned_calls_by_tensor": [sum(a[i] % 32 == 0 for a in outs) for i in range(3)],
        "input_alignment_masks": dict(sorted(Counter(_alignment_mask(a) for a in ins).items())),
        "output_alignment_masks": dict(sorted(Counter(_alignment_mask(a) for a in outs).items())),
        "unique_input_triples": len(set(ins)),
        "unique_output_triples": len(set(outs)),
        "input_triple_changes_within_segment": sum(a != b for a, b in zip(ins, ins[1:])),
        "output_triple_changes_within_segment": sum(a != b for a, b in zip(outs, outs[1:])),
        "executor_reuse_input_alignment_condition_calls": sum(_alignment_mask(a) == 7 for a in ins),
        "f526_host_raw_pointer_necessary_conditions_calls": sum(
            shape_eligible and _alignment_mask(a) == 7 and _alignment_mask(b) == 7
            for a, b in zip(ins, outs)
        ),
    }


def analyze(path):
    raw = path.read_bytes()
    data = json.loads(raw.decode("utf-8"), object_pairs_hook=_object)
    if not isinstance(data, dict) or data.get("purpose") != "diagnostic_only_not_acceptance_timing":
        raise ValueError("Expected the existing diagnostic address-probe JSON format")
    if not isinstance(data.get("baseline"), str) or not data["baseline"]:
        raise ValueError("Missing baseline identity")
    records = data.get("records")
    if not isinstance(records, dict) or not records:
        raise ValueError("Missing shape/dtype records")
    results = []
    identities = set()
    for key, entry in records.items():
        identity = ast.literal_eval(key)
        if not isinstance(identity, tuple) or len(identity) != 2:
            raise ValueError(f"Invalid shape/dtype key: {key}")
        shape, dtype = identity
        if not isinstance(shape, tuple) or len(shape) != 4 or any(type(n) is not int for n in shape):
            raise ValueError(f"Invalid shape: {key}")
        b, h, length, dim = shape
        if (not 1 <= b <= 64 or not 1 <= h <= 128 or not 0 <= length <= 8192
                or not 1 <= dim <= 256 or b * h * dim * (2 * length + 3) > 2**28
                or b * h * length * dim < 16 * 1024 * 1024):
            raise ValueError(f"Shape outside the original large-cache probe: {key}")
        if dtype not in ("torch.float16", "torch.bfloat16") or identity in identities:
            raise ValueError(f"Unsupported or duplicate shape/dtype: {key}")
        identities.add(identity)
        if not isinstance(entry, dict) or type(entry.get("calls")) is not int or entry["calls"] != CALLS:
            raise ValueError(f"{key}: expected exactly {CALLS} recorded calls")
        inputs = _triples(entry.get("input_addresses"), key + ".input_addresses")
        outputs = _triples(entry.get("output_addresses"), key + ".output_addresses")
        expected = {
            "unique_input_triples": len(set(inputs)),
            "unique_output_triples_after_accuracy": len(set(outputs[1:])),
            "timed_round_unique_output_triples": [len(set(outputs[51 + 200*i:251 + 200*i])) for i in range(5)],
        }
        for field, value in expected.items():
            if entry.get(field) != value or type(entry.get(field)) is not type(value):
                raise ValueError(f"{key}: inconsistent {field}")
        supplied_counts = entry.get("output_counts")
        if not isinstance(supplied_counts, list):
            raise ValueError(f"{key}: missing output_counts")
        counts = {}
        for item in supplied_counts:
            if not isinstance(item, dict) or type(item.get("count")) is not int or item["count"] <= 0:
                raise ValueError(f"{key}: malformed output_counts")
            addresses = item.get("addresses")
            if (not isinstance(addresses, list) or len(addresses) != 3
                    or any(type(a) is not int or not 0 < a < 2**64 for a in addresses)):
                raise ValueError(f"{key}: malformed output_counts addresses")
            triple = tuple(addresses)
            if triple in counts:
                raise ValueError(f"{key}: duplicate output_counts addresses")
            counts[triple] = item["count"]
        if counts != Counter(outputs):
            raise ValueError(f"{key}: output_counts does not match recorded calls")
        shape_eligible = b * h * (length + 1) * dim >= 16 * 1024 * 1024 and dim % 16 == 0 and TILE_ELEMENTS % 16 == 0
        samples = []
        seen = set()
        for index, pair in enumerate(zip(inputs, outputs)):
            if pair not in seen and len(samples) < 3:
                samples.append({"call_index_zero_based": index, "input_addresses": pair[0], "output_addresses": pair[1]})
                seen.add(pair)
        results.append({
            "shape": shape, "dtype": dtype,
            "f526_shape_and_tile_condition": shape_eligible,
            "all_calls": _segment(inputs, outputs, shape_eligible, 0, CALLS),
            "accuracy": _segment(inputs, outputs, shape_eligible, 0, 1),
            "warmup": _segment(inputs, outputs, shape_eligible, 1, 51),
            "rounds": [_segment(inputs, outputs, shape_eligible, 51 + 200*i, 251 + 200*i) for i in range(5)],
            "address_samples": samples,
        })
    return {
        "purpose": "offline_host_raw_pointer_condition_analysis_only",
        "input_path": str(path.resolve()), "input_sha256": hashlib.sha256(raw).hexdigest(),
        "probed_baseline": data["baseline"],
        "condition_model_commit": "f52671207769bf5f334972c997743eb6aa6f91b3",
        "protocol_layout": {"accuracy": 1, "warmup": 50, "rounds": 5, "calls_per_round": 200, "total": CALLS},
        "alignment_mask_bits": {"input": ["packed", "past_key", "past_value"], "output": ["query", "key", "value"], "meaning": "set bit means raw address is 32B aligned"},
        "limitations": [
            "Conditions are derived from host raw pointer integers, not observed device paths.",
            "Actual GM aliases, the seventh cached-key view, and actual kernel branches are not observed.",
            "Input alignment is necessary but does not establish executor reuse support, configuration, or success.",
            "Applying the f526 condition model does not identify the probed kernel as f526.",
            "Address alignment or stability does not prove a high-address-bit, physical-layout, or L2 root cause.",
            "Diagnostic timing is not fixed acceptance evidence; this report contains no performance verdict.",
        ],
        "records": results,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = analyze(args.input)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(report, indent=2, allow_nan=False) + "\n")
    except (ValueError, SyntaxError, OSError) as exc:
        parser.error(str(exc))
    print(json.dumps({"status": "analyzed", "records": len(report["records"]), "output": str(args.output), "performance_verdict": "not_evaluated"}))


if __name__ == "__main__":
    main()
