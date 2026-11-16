#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
import hashlib,json,tarfile
from pathlib import Path
base=Path('/workspace/t5_qkv_tasks')
assert (base/'candidate_stability_20261116.exit').read_text().strip()=='0'
assert (base/'functional_pair_20261116.exit').read_text().strip()=='0'
paths=[]
for commit in ['f52671207769','a2013d56db4f']:
    root=base/('t5_qkv_'+commit)
    assert (root/'artifacts/validation/correctness_phase.exit').read_text().strip()=='0'
    paths.extend(p for p in (root/'artifacts/validation').rglob('*') if p.is_file())
    paths.extend([root/'DEPLOYMENT_MANIFEST.json',root/'artifacts/build_manifest.json'])
venv=base/'venv_t5_py312_torch210_20261116_offline_v3'
paths.extend(venv/name for name in ['metadata_verified.json','install-report.json','installed-freeze.txt','wheelhouse_verified.json','wheelhouse-manifest-kernel-corrected.json','requirements-offline.txt','setup.exit'])
paths.extend(base/name for name in ['target_platform_exact_20261116.json','post_native_smoke_hashes_20261116.json','offline_v3_and_bindings_corrected_20261116.exit','functional_pair_20261116.exit','candidate_stability_20261116.exit'])
manifest=[]
for p in sorted(set(paths)):
    assert p.resolve(strict=True).is_relative_to(base) and not p.is_symlink(),str(p)
    data=p.read_bytes()
    manifest.append({'path':str(p.relative_to(base)),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
index=base/'final_validation_evidence_20261116.manifest.json'
with index.open('x') as f:json.dump({'files':manifest},f,indent=2);f.write('\n')
output=base/'final_validation_evidence_20261116.tar.gz'
with tarfile.open(output,'x:gz') as archive:
    for item in manifest:archive.add(base/item['path'],arcname=item['path'],recursive=False)
    archive.add(index,arcname=index.name,recursive=False)
with output.open('rb') as f:sha=hashlib.file_digest(f,'sha256').hexdigest()
print(json.dumps({'archive':str(output),'sha256':sha,'bytes':output.stat().st_size,'files':len(manifest)}))
PY
