"""Bounded public downloads using Windows curl TLS; keep a per-URL audit."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "research"
BASE = "https://raw.githubusercontent.com/Ascend/samples/fc2aea93e48be8f8cee51d0c6c1b13a08155f83a/cplusplus/level1_single_api/4_op_dev/6_ascendc_custom_op/"
URLS = {
    "sample_direct_CMakeLists.txt": BASE + "kernel_invocation/Add/CMakeLists.txt",
    "sample_add_custom.json": BASE + "acl_invocation/op_dev/add_custom.json",
    "sample_add_host.cpp": BASE + "acl_invocation/op_dev/op_host/add_custom.cpp",
    "sample_add_kernel.cpp": BASE + "kernel_invocation/Add/add_custom.cpp",
    "xllm_tree.json": "https://api.github.com/repos/xLLM-AI/xllm/git/trees/fea4d5d6a3f46b37b3703262be182e0579914103?recursive=1",
    "xllm_t5_issues.json": "https://api.github.com/search/issues?q=repo%3AxLLM-AI%2Fxllm+T5+in%3Atitle%2Cbody",
}

def main():
    records = []
    for name, url in URLS.items():
        path = OUT / name
        if not path.exists():
            temp = path.with_suffix(path.suffix + ".part")
            proc = subprocess.run(["curl.exe", "--fail", "--location", "--silent", "--show-error",
                                   "--max-time", "30", url, "--output", str(temp)], capture_output=True)
            if proc.returncode:
                records.append({"url": url, "status": "unavailable", "error": proc.stderr.decode(errors="replace")})
                continue
            temp.replace(path)
        records.append({"url": url, "file": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    (OUT / "downloads.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(records, indent=2))

if __name__ == "__main__":
    main()
