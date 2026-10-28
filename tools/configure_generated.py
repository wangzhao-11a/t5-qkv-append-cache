"""Configure the official msopgen scaffold, fail if expected knobs disappear."""
import json
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
path = root / "CMakePresets.json"
config = json.loads(path.read_text(encoding="utf-8"))
changed = set()
for preset in config.get("configurePresets", []):
    variables = preset.get("cacheVariables", {})
    for key, value in {"ASCEND_COMPUTE_UNIT": "ascend910_93", "vendor_name": "t5qkv",
                       "ENABLE_SOURCE_PACKAGE": False, "ENABLE_BINARY_PACKAGE": True}.items():
        if key in variables:
            old = variables[key]
            if isinstance(old, dict):
                old["value"] = value
            else:
                variables[key] = value
            changed.add(key)
if "ASCEND_COMPUTE_UNIT" not in changed or "vendor_name" not in changed:
    raise RuntimeError("Unexpected msopgen scaffold; inspect CMakePresets.json before adapting")
path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
print("Configured:", sorted(changed))
