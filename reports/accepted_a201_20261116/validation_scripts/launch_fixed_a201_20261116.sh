#!/usr/bin/env bash
set -euo pipefail
[[ $(cat /workspace/t5_qkv_tasks/functional_pair_20261116.exit) == 0 ]] || exit 2
printf '%s\n' '956979ae50769243dfbc4e97d0d727c094c153476b35550142145e17b9222509  /tmp/t5_sources_20261116/run_fixed_once_20261116.sh' | sha256sum -c --strict
bash -n /tmp/t5_sources_20261116/run_fixed_once_20261116.sh
set +u
source /usr/local/Ascend/cann/set_env.sh
set -u
export T5_DEVICE_CONFIRMED=1
exec bash /tmp/t5_sources_20261116/run_fixed_once_20261116.sh /workspace/t5_qkv_tasks/t5_qkv_a2013d56db4f
