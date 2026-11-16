#!/usr/bin/env bash
set -euo pipefail
cd /workspace/t5_qkv_tasks
mkdir native_smoke_pair_20261116.lock
trap 'rc=$?; (set -o noclobber; printf "%s\n" "$rc" > native_smoke_pair_20261116.exit); exit "$rc"' EXIT
printf '%s\n' '3a60d8a1128a27bf2f1ab77a5133de956b788e3b7d10a5dde2959cb57001a53c  /tmp/t5_sources_20261116/native_smoke_20261116.sh' | sha256sum --check --strict
bash -n /tmp/t5_sources_20261116/native_smoke_20261116.sh
bash /tmp/t5_sources_20261116/native_smoke_20261116.sh /workspace/t5_qkv_tasks/t5_qkv_f52671207769
bash /tmp/t5_sources_20261116/native_smoke_20261116.sh /workspace/t5_qkv_tasks/t5_qkv_a2013d56db4f
printf '%s\n' 'Both native smoke phases passed; this is not full accuracy or performance acceptance.'
