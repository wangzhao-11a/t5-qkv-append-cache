"""Read public upstream evidence only; never apply a pull request."""
import hashlib
import json
import urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "research"
OUT.mkdir(exist_ok=True)


def fetch(url, name):
    request = urllib.request.Request(url, headers={"User-Agent": "T5Qkv-task-evidence"})
    with urllib.request.urlopen(request, timeout=45) as response:
        data = response.read()
    (OUT / name).write_bytes(data)
    return data


def main():
    records = []
    for repo in ("xLLM-AI/xllm", "Ascend/samples", "Ascend/pytorch"):
        slug = repo.replace("/", "_")
        info = json.loads(fetch(f"https://api.github.com/repos/{repo}", slug + "_repo.json"))
        branch = info["default_branch"]
        commit = json.loads(fetch(f"https://api.github.com/repos/{repo}/commits/{branch}", slug + "_head.json"))["sha"]
        tree = json.loads(fetch(f"https://api.github.com/repos/{repo}/git/trees/{commit}?recursive=1", slug + "_tree.json"))
        relevant = [x["path"] for x in tree["tree"] if any(y in x["path"].lower() for y in ("t5", "addcustom", "add_custom", "op_api_common.h", "npustream.h", "npucachingallocator.h"))]
        records.append({"repo": repo, "branch": branch, "commit": commit, "tree_truncated": tree.get("truncated"), "relevant_paths": relevant})
    try:
        data = fetch("https://cann-op.obs.cn-north-4.myhuaweicloud.com/task_submission.zip", "official_task_submission.zip")
        records.append({"template_sha256": hashlib.sha256(data).hexdigest()})
    except Exception as exc:
        records.append({"template_error": str(exc)})
    (OUT / "upstream_snapshot.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")
    for r in records:
        if "relevant_paths" in r:
            r["relevant_paths"] = r["relevant_paths"][:100]
    print(json.dumps(records, indent=2))


if __name__ == "__main__":
    main()
