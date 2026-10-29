#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/phase_common.sh"
phase_begin candidate_pipeline
# Each child owns its log/exit/lock and verifies the exact deployment manifest.
for script in start_optimized_build phase_smoke phase_correctness; do
  if bash "scripts/$script.sh"; then
    printf '%s passed\n' "$script"
  else
    rc=$?
    printf '%s failed: %s; dependent stages were not started\n' "$script" "$rc"
    exit "$rc"
  fi
done
performance_rc=0
bash scripts/phase_performance.sh || performance_rc=$?
printf 'performance exit: %s\n' "$performance_rc"
# Failed fixed targets are still evidence; collect only after the stage ends.
bash scripts/collect_evidence.sh
exit "$performance_rc"
