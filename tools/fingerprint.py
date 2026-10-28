import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def create():
    records = []
    for path in sorted(ROOT.rglob("*")):
        rel = path.relative_to(ROOT)
        if not path.is_file() or any(p in {".git", "node_modules", "__pycache__", "reports", "research", "task_submission", "artifacts"} for p in rel.parts):
            continue
        records.append({"path": rel.as_posix(), "bytes": path.stat().st_size,
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    try:
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        dirty = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)
    except (OSError, subprocess.SubprocessError):
        commit, dirty = "not_recorded", "unknown"
    return {"source_commit": commit, "worktree_status": dirty, "python": platform.python_version(), "files": records}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(create(), indent=2) + "\n", encoding="utf-8")
