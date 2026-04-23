#!/usr/bin/env bash
#
# experiment-report.sh — summarise cost, duration, and turn counts across
# a set of `claude --print --output-format json` dispatches captured during
# a lean-spec v3 experiment.
#
# Usage:
#   scripts/experiment-report.sh '<json-glob>' [workflow.json]
#
# Examples:
#   scripts/experiment-report.sh '/tmp/pomodoro-A-*.json'
#   scripts/experiment-report.sh '/tmp/pomodoro-B-*.json' \
#       /path/to/project/features/pomodoro/workflow.json
#
# The glob MUST be quoted so the shell does not expand it before the script
# receives it. The script expands it in the order `ls` returns (alphabetical),
# which for conventional names (architect → coder → reviewer-1 → coder-fix1 →
# reviewer-2 → close) gives a natural lifecycle order.
#
# Requires: jq, awk, ls

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 '<json-glob>' [workflow.json]" >&2
  echo "Example: $0 '/tmp/pomodoro-A-*.json' features/pomodoro/workflow.json" >&2
  exit 1
fi

GLOB="$1"
WF="${2:-}"

# Expand glob safely (null result ok).
# shellcheck disable=SC2206
FILES=( $GLOB )
if [ ! -f "${FILES[0]:-/nonexistent}" ]; then
  echo "No JSON files matched: $GLOB" >&2
  exit 2
fi

total_cost=0
total_ms=0
total_turns=0
errors=0

printf "%-32s %10s %12s %6s %6s\n" "Dispatch" "Cost (\$)" "Duration (s)" "Turns" "Error"
printf "%-32s %10s %12s %6s %6s\n" "--------" "--------" "-----------" "-----" "-----"

for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .json)
  cost=$(jq -r '.total_cost_usd // 0' "$f")
  dur_ms=$(jq -r '.duration_ms // 0' "$f")
  turns=$(jq -r '.num_turns // 0' "$f")
  err=$(jq -r '.is_error // false' "$f")
  dur_s=$(awk "BEGIN { printf \"%.0f\", $dur_ms/1000 }")
  err_flag="no"
  if [ "$err" = "true" ]; then
    err_flag="YES"
    errors=$((errors + 1))
  fi
  printf "%-32s %10.4f %12d %6d %6s\n" "$name" "$cost" "$dur_s" "$turns" "$err_flag"
  total_cost=$(awk "BEGIN { printf \"%.6f\", $total_cost + $cost }")
  total_ms=$(awk "BEGIN { printf \"%.0f\", $total_ms + $dur_ms }")
  total_turns=$((total_turns + turns))
done

total_s=$(awk "BEGIN { printf \"%.0f\", $total_ms/1000 }")
total_min=$(awk "BEGIN { printf \"%.1f\", $total_ms/60000 }")
printf "%-32s %10s %12s %6s %6s\n" "--------" "--------" "-----------" "-----" "-----"
printf "%-32s %10.4f %12d %6d\n" "TOTAL" "$total_cost" "$total_s" "$total_turns"
printf "  wall time: %s min   |   errored dispatches: %d\n" "$total_min" "$errors"

if [ -n "$WF" ]; then
  if [ -f "$WF" ]; then
    echo
    echo "Phase history ($WF):"
    jq -r '.history[] | "  \(.entered_at)  \(.phase)"' "$WF"
  else
    echo
    echo "warning: workflow.json not found at: $WF" >&2
  fi
fi
