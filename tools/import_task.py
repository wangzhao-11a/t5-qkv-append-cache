"""Import the original task without changing bytes; reject unsafe ZIP entries."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"C:/Users/wzy85/Downloads/a06a5aac7a2a4f69bf7006576ea39f7f.zip")


def main():
    target = ROOT / "reference"
    target.mkdir(exist_ok=True)
    records = []
    with zipfile.ZipFile(SOURCE, metadata_encoding="gbk") as archive:
        entries = [e for e in archive.infolist() if not e.is_dir()]
        parents = {PurePosixPath(e.filename).parent for e in entries}
        if len(parents) != 1:
            raise ValueError("Expected a single task directory")
        for entry in entries:
            path = PurePosixPath(entry.filename)
            if path.is_absolute() or ".." in path.parts or "\\" in entry.filename:
                raise ValueError(f"Unsafe ZIP path: {entry.filename!r}")
            payload = archive.read(entry)
            out = target / path.name
            if out.exists() and out.read_bytes() != payload:
                raise ValueError(f"Refusing to replace different reference: {out}")
            out.write_bytes(payload)
            records.append({"archive_path": entry.filename, "path": "reference/" + path.name,
                            "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()})
    checks = []
    for line in (target / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines():
        digest, name = line.split(maxsplit=1)
        name = name.lstrip("*")
        check = target / name
        matched_by = "path"
        if not check.exists():
            matches = [r for r in records if r["sha256"] == digest]
            if len(matches) != 1:
                checks.append({"file": name, "expected_sha256": digest,
                               "pass": False, "reason": "missing path and no content hash match in original ZIP"})
                continue
            check = ROOT / matches[0]["path"]
            matched_by = "unique SHA256 (upstream filename mismatch)"
        actual = hashlib.sha256(check.read_bytes()).hexdigest()
        checks.append({"file": name, "actual_file": check.name, "matched_by": matched_by, "pass": actual == digest})
    manifest = {"source": str(SOURCE), "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                "zip_legacy_filename_encoding": "GBK (ZIP UTF-8 flag absent)",
                "files": records, "supplied_sha256_checks": checks,
                "original_manifest_valid": all(x["pass"] for x in checks)}
    (ROOT / "reference_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"files": len(records), "passed_hashes": sum(x["pass"] for x in checks),
                      "original_manifest_valid": manifest["original_manifest_valid"],
                      "errors": [x for x in checks if not x["pass"]]}, ensure_ascii=True))


if __name__ == "__main__":
    main()
