"""One same-process ABBA alignment diagnostic; never a fixed acceptance run."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import traceback


ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT), str(ROOT / "reference"), str(ROOT / "tools")]


def _file(path):
    path = path.resolve(strict=True)
    return {"path": str(path), "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def _tensor(tensor):
    address = tensor.data_ptr()
    return {"data_ptr": address, "storage_ptr": tensor.untyped_storage().data_ptr(),
            "storage_offset": tensor.storage_offset(), "shape": list(tensor.shape),
            "stride": list(tensor.stride()), "dtype": str(tensor.dtype),
            "address_moduli": {str(n): address % n for n in (32, 512, 4096, 2 * 1024 * 1024)}}


def _private_opp():
    opp = Path(os.environ["T5_OPP_ROOT"]).resolve(strict=True)
    vendor = (opp / "vendors/t5qkv").resolve(strict=True)
    search = os.environ.get("ASCEND_CUSTOM_OPP_PATH", "").split(os.pathsep)
    # Keep this diagnostic process exclusive to the selected custom OPP. A
    # baseline host extension alone cannot establish device kernel identity.
    if len(search) != 1 or not search[0] or Path(search[0]).resolve(strict=True) != vendor:
        raise RuntimeError("ASCEND_CUSTOM_OPP_PATH must contain only the selected T5_OPP_ROOT/vendors/t5qkv")
    return opp


def _binary_identity(extension, opp):
    # /proc maps identifies loaded host libraries, not the device .o selected by
    # CANN. Hash private OPP candidates separately without claiming selection.
    paths = set()
    for line in Path("/proc/self/maps").read_text(encoding="utf-8").splitlines():
        fields = line.split(maxsplit=5)
        if len(fields) != 6 or not fields[5].startswith("/"):
            continue
        path = Path(fields[5])
        if path.name.startswith(("_t5_qkv", "libt5_direct", "libcust_")):
            paths.add(path.resolve(strict=True))
    if extension.resolve() not in paths:
        raise RuntimeError("Expected extension is absent from actual process mappings")
    private = [path for path in opp.rglob("*") if path.is_file()
               and path.suffix in {".so", ".o", ".json"}]
    if not any(p.suffix == ".o" for p in private) or not any(p.suffix == ".json" for p in private):
        raise RuntimeError("Private OPP kernel object/metadata fingerprints are missing")
    if not any(p.name == "libcust_opapi.so" and p.is_relative_to(opp) for p in paths):
        raise RuntimeError("Private OPP libcust_opapi.so is not the mapped API library")
    if any(p.name.startswith("libcust_") and not p.is_relative_to(opp) for p in paths):
        raise RuntimeError("A custom operator library is mapped outside the selected private OPP")
    return {"loaded_host_libraries": [_file(p) for p in sorted(paths)],
            "private_opp_candidate_artifacts": [_file(p) for p in sorted(private)],
            "device_kernel_selection": "not_observed; use the existing CANN loader trace if needed"}


def execute(args, report, save):
    if os.environ.get("T5_DEVICE_CONFIRMED") != "1":
        raise RuntimeError("Require T5_DEVICE_CONFIRMED=1 after the existing board/port/process gate")
    visible = os.environ.get("ASCEND_RT_VISIBLE_DEVICES", "")
    if not visible.isdecimal() or not os.environ.get("T5_PHYSICAL_DEVICE", "").isdecimal():
        raise RuntimeError("Select one visible device and record its verified T5_PHYSICAL_DEVICE")
    root = args.solution_root.resolve(strict=True)
    # Run this diagnostic outside an existing baseline deployment. Do not copy
    # new helpers into or edit the preserved baseline just to inspect it.
    sys.path[:0] = [str(root), str(root / "reference"), str(root / "tools")]
    import fingerprint
    import preflight
    report["static_checks"] = preflight.static_checks()
    source = fingerprint.create()
    if source["source_commit"] != args.source_commit or source["worktree_status"] not in ("", "archive verified"):
        raise RuntimeError("Source fingerprint differs from the requested clean/exact deployment")
    report["source_fingerprint"] = source
    opp = _private_opp()
    import numpy as np
    import torch
    import torch_npu
    import benchmark
    import generate_data
    import golden
    import solution
    import verify
    if not torch.npu.is_available():
        raise RuntimeError("NPU unavailable; no device diagnostic executed")
    torch.npu.set_device(args.device)
    name = torch.npu.get_device_name(args.device)
    # Use tools/preflight.py --require-soc Ascend910_9382 before this script;
    # torch's presentation name is recorded but is not the official SoC query.
    report["environment"] = benchmark.environment_info(torch, torch_npu, args.device)
    report["environment"].update(device_name=name, hostname=os.uname().nodename,
        pid=os.getpid(), private_opp=str(opp), variables={k: os.environ.get(k) for k in (
            "ASCEND_HOME_PATH", "ASCEND_RT_VISIBLE_DEVICES", "ASCEND_CUSTOM_OPP_PATH",
            "T5_PHYSICAL_DEVICE", "T5_ACLNN_EXECUTOR_REUSE", "TASK_QUEUE_ENABLE")})
    extension = Path(solution._extension().__file__).resolve(strict=True)
    if _file(extension)["sha256"] != args.expected_extension_sha256:
        raise RuntimeError("Loaded extension SHA256 differs from the explicit control identity")
    cases = json.loads((root / "reference/case.json").read_text(encoding="utf-8"))
    case = next(c for c in cases if c["case_name"].split("_")[1] == args.case)
    if case.get("performance") is not True or case["input_desc"][1]["shape"] != [16, 16, 2048, 64]:
        raise RuntimeError("Frozen large-case identity mismatch")
    arrays = generate_data.generate(case)
    attributes = {a["name"]: a["value"] for a in case["attr_desc"]}
    expected = golden.calculate(arrays, attributes)
    inputs = verify.device_inputs(case, arrays, f"npu:{args.device}")
    index = args.input_index
    shape, dtype, count = inputs[index].shape, inputs[index].dtype, inputs[index].numel()
    backing = torch.empty(count + args.offset, dtype=dtype, device=inputs[index].device)
    views = {offset: backing[offset:offset + count].view(shape) for offset in (0, args.offset)}
    inputs[index] = views[0]  # Release the original selected-input allocation.
    # Refill this same allocation before each block: overlapping A/B views
    # cannot both contain an arbitrary identical logical input simultaneously.
    host_bits = torch.from_numpy(arrays[index].view(np.int16).copy())
    torch.npu.synchronize()
    if any(t.data_ptr() % 32 for t in inputs):
        raise RuntimeError("A control must begin with all three raw input pointers 32B aligned")
    fn = getattr(solution, args.entry)
    report.update(case_name=case["case_name"], protocol=dict(benchmark.PROTOCOL),
        backing_storage=_tensor(backing), case_sha256=_file(root / "reference/case.json")["sha256"],
        benchmark_sha256=_file(root / "reference/benchmark.py")["sha256"])

    def check_inputs():
        for tensor, original in zip(inputs, arrays):
            if not np.array_equal(verify.cpu_array(tensor).view(np.uint16), original.view(np.uint16)):
                raise AssertionError("Input changed or A/B refill did not preserve logical bits")

    identity = None
    for block, offset in enumerate((0, args.offset, args.offset, 0)):
        record = {"block": block, "mode": "A" if offset == 0 else "B",
                  "offset_elements": offset, "status": "running"}
        report["blocks"].append(record)
        save()
        inputs[index] = views[offset]
        inputs[index].view(torch.int16).copy_(host_bits)
        torch.npu.synchronize()
        check_inputs()
        outputs = fn(inputs, attributes)
        torch.npu.synchronize()
        report["npu_executed"] = True
        verify.validate_ownership(inputs, outputs)
        accuracy = verify.compare(case, arrays, outputs, expected)
        check_inputs()
        record.update(input_metadata_before_measure=[_tensor(t) for t in inputs],
                      output_metadata_before_measure=[_tensor(t) for t in outputs], accuracy=accuracy)
        del outputs
        current_identity = _binary_identity(extension, opp)
        if identity is None:
            identity = current_identity
            report["binary_identity_before"] = identity
        elif current_identity != identity:
            raise RuntimeError("Loaded library or private OPP artifact changed between ABBA blocks")
        save()
        # No Python address logging or retained outputs inside the measured call.
        record["result"] = benchmark.measure(lambda: fn(inputs, attributes), torch.npu)
        save()
        check_inputs()
        outputs = fn(inputs, attributes)
        torch.npu.synchronize()
        verify.validate_ownership(inputs, outputs)
        record["accuracy_after_measure"] = verify.compare(case, arrays, outputs, expected)
        record["output_metadata_after_measure"] = [_tensor(t) for t in outputs]
        del outputs
        check_inputs()
        record["status"] = "passed"
        save()
    report["binary_identity_after"] = _binary_identity(extension, opp)
    if report["binary_identity_after"] != identity:
        raise RuntimeError("Binary identity changed during diagnostic")
    report["status"] = "passed_diagnostic_checks"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=("007", "017"), required=True)
    parser.add_argument("--entry", choices=("run", "run_direct"), required=True)
    parser.add_argument("--input-index", type=int, choices=(0, 1, 2), required=True)
    parser.add_argument("--offset", type=int, choices=(1, 16), required=True)
    parser.add_argument("--device", type=int, default=0)
    parser.add_argument("--solution-root", type=Path, default=ROOT,
                        help="Existing exact baseline or candidate deployment; it is not modified")
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--expected-extension-sha256", required=True)
    parser.add_argument("--hypothesis", required=True, help="New discriminating question for this one ABBA run")
    parser.add_argument("--report", type=Path, required=True)
    if len(sys.argv) == 1:
        parser.print_help()
        return 0
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_commit) or not re.fullmatch(r"[0-9a-f]{64}", args.expected_extension_sha256):
        parser.error("Use an exact lowercase 40-digit source commit and 64-digit extension SHA256")
    if args.device != 0 or not args.hypothesis.strip():
        parser.error("Use logical device 0 of the single assigned device and a nonempty hypothesis")
    report = {"status": "running", "purpose": "diagnostic_only_not_fixed_acceptance",
              "npu_executed": False, "started_at_utc": datetime.now(timezone.utc).isoformat(),
              "requested": {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
              "diagnostic_script": _file(Path(__file__)), "order": ["A", "B", "B", "A"],
              "blocks": [], "limitations": [
                  "Input A/B views share one allocation and are refilled outside timing.",
                  "Outputs are fresh allocations; their addresses are sampled outside timing only and may differ.",
                  "Raw host addresses do not establish actual GM aliases, executor mode or kernel branch selection.",
                  "Private OPP hashes identify candidates, not the actual device object selected by CANN.",
                  "The diagnostic has a different working set and sequence from the frozen acceptance harness.",
                  "The binary identity check performs file I/O before each block; the frozen measure warmup follows it.",
              ]}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    with args.report.open("x", encoding="utf-8", newline="\n") as handle:
        def save():
            handle.seek(0)
            handle.write(json.dumps(report, indent=2, allow_nan=False) + "\n")
            handle.truncate()
            handle.flush()
        save()
        code = 1
        try:
            execute(args, report, save)
            code = 0
        except (Exception, KeyboardInterrupt) as exc:
            report.update(status="failed", error=str(exc))
            for block in report["blocks"]:
                if block["status"] == "running":
                    block.update(status="failed", error=str(exc))
            traceback.print_exc()
        finally:
            report["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
            save()
    print(json.dumps({"status": report["status"],
                      "completed_blocks": sum(b["status"] == "passed" for b in report["blocks"]),
                      "performance_acceptance": "not_evaluated", "report": str(args.report)}))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
