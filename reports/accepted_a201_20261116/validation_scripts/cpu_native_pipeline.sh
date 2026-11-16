#!/usr/bin/env bash
set -euo pipefail
cd /workspace/t5_qkv_tasks
[[ ! -e preparation_20261116.exit ]] || { echo 'Preserve existing preparation result'; exit 2; }
mkdir preparation_20261116.lock
trap 'rc=$?; (set -o noclobber; printf "%s\n" "$rc" > preparation_20261116.exit); exit "$rc"' EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
printf '%s\n' \
 '15b769a4cc914453f34caf9d11e63e532ba7a38fdd188b509f23e10fa384ee5e  /tmp/t5_sources_20261116/run_host_semantics_20261116.sh' \
 'b5b4d6f99643815ea38ff6c7c052e777e0daf1c5572265d37366925991e72adc  /tmp/t5_sources_20261116/build_native_20261116.sh' | sha256sum --check --strict
bash -n /tmp/t5_sources_20261116/run_host_semantics_20261116.sh
bash -n /tmp/t5_sources_20261116/build_native_20261116.sh
bash /tmp/t5_sources_20261116/run_host_semantics_20261116.sh \
 /workspace/t5_qkv_tasks/t5_qkv_a2013d56db4f \
 /workspace/t5_qkv_tasks/t5_qkv_f52671207769 \
 /workspace/t5_qkv_tasks/host_semantics_20261116
set +u
source /usr/local/Ascend/cann/set_env.sh
set -u
export T5_BUILD_JOBS=4 MAX_JOBS=4
bash /tmp/t5_sources_20261116/build_native_20261116.sh /workspace/t5_qkv_tasks/t5_qkv_f52671207769
bash /tmp/t5_sources_20261116/build_native_20261116.sh /workspace/t5_qkv_tasks/t5_qkv_a2013d56db4f
printf '%s\n' 'CPU semantic checks and both native builds completed; no NPU operation was executed.'
