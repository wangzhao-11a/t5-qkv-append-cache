#!/usr/bin/env bash
set -euo pipefail
task_base=/workspace/t5_qkv_tasks
task_wrapper=/tmp/t5_sources_20261116/run_functional_20261116.sh
[[ ! -e "$task_base/functional_pair_20261116.exit" ]] || exit 2
mkdir "$task_base/functional_pair_20261116.lock"
trap 'rc=$?; (set -o noclobber; printf "%s\n" "$rc" > "$task_base/functional_pair_20261116.exit"); exit "$rc"' EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
printf '%s\n' "$$" > "$task_base/functional_pair_20261116.lock/pid"
printf '%s\n' '0dec1c2e913c79710a50d414dfee305298af4b918f59e44c1d6c1cbec009578b  /tmp/t5_sources_20261116/run_functional_20261116.sh' | sha256sum -c --strict
bash -n "$task_wrapper"
for commit in f52671207769 a2013d56db4f; do
  [[ $(cat "$task_base/t5_qkv_$commit/artifacts/validation/build_full.exit") == 0 ]] || exit 2
done
set +u
source /usr/local/Ascend/cann/set_env.sh
set -u
export T5_DEVICE_CONFIRMED=1
for phase in smoke correctness; do
  for commit in f52671207769 a2013d56db4f; do
    bash "$task_wrapper" "$task_base/t5_qkv_$commit" "$phase"
  done
done
printf '%s\n' 'Both functional suites completed; no performance benchmark executed.'
