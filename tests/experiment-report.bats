#!/usr/bin/env bats
#
# experiment-report.bats — verify scripts/experiment-report.sh correctly
# aggregates cost/duration/turns across a set of fixture claude JSON outputs.

setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$PLUGIN_ROOT/scripts/experiment-report.sh"
  TMP="$(mktemp -d)"

  # Three fixture dispatches: architect, coder, reviewer-1.
  # Costs chosen so totals are easy to verify by hand.
  cat > "$TMP/exp-architect.json" <<'EOF'
{
  "is_error": false,
  "duration_ms": 60000,
  "num_turns": 3,
  "total_cost_usd": 0.5
}
EOF

  cat > "$TMP/exp-coder.json" <<'EOF'
{
  "is_error": false,
  "duration_ms": 120000,
  "num_turns": 5,
  "total_cost_usd": 1.25
}
EOF

  cat > "$TMP/exp-reviewer-1.json" <<'EOF'
{
  "is_error": false,
  "duration_ms": 180000,
  "num_turns": 7,
  "total_cost_usd": 2.0
}
EOF
}

teardown() {
  rm -rf "$TMP"
}

# ---------- CLI surface ----------

@test "script is executable" {
  [ -x "$SCRIPT" ]
}

@test "running without args exits non-zero with usage hint" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "glob matching nothing exits non-zero with helpful message" {
  run "$SCRIPT" "$TMP/nothing-here-*.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No JSON files matched"* ]]
}

# ---------- aggregation ----------

@test "total cost is the sum of individual costs" {
  run "$SCRIPT" "$TMP/exp-*.json"
  [ "$status" -eq 0 ]
  # 0.5 + 1.25 + 2.0 = 3.75
  [[ "$output" == *"3.7500"* ]]
}

@test "total duration is the sum of individual durations in seconds" {
  run "$SCRIPT" "$TMP/exp-*.json"
  [ "$status" -eq 0 ]
  # 60+120+180 = 360s
  [[ "$output" == *"360"* ]]
}

@test "total turns is the sum of individual turn counts" {
  run "$SCRIPT" "$TMP/exp-*.json"
  [ "$status" -eq 0 ]
  # 3+5+7 = 15
  [[ "$output" =~ TOTAL[[:space:]]+[0-9]+\.[0-9]+[[:space:]]+[0-9]+[[:space:]]+15 ]]
}

@test "wall time is rendered in minutes with one decimal" {
  run "$SCRIPT" "$TMP/exp-*.json"
  [ "$status" -eq 0 ]
  # 360s = 6.0 min
  [[ "$output" == *"wall time: 6.0 min"* ]]
}

# ---------- per-dispatch rows ----------

@test "each fixture is printed with its own row" {
  run "$SCRIPT" "$TMP/exp-*.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exp-architect"* ]]
  [[ "$output" == *"exp-coder"* ]]
  [[ "$output" == *"exp-reviewer-1"* ]]
}

# ---------- error handling ----------

@test "errored dispatch is counted and flagged" {
  cat > "$TMP/exp-fail.json" <<'EOF'
{
  "is_error": true,
  "duration_ms": 30000,
  "num_turns": 2,
  "total_cost_usd": 0.1
}
EOF
  run "$SCRIPT" "$TMP/exp-fail.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"YES"* ]]
  [[ "$output" == *"errored dispatches: 1"* ]]
}

@test "missing fields default to zero (no crash on partial JSON)" {
  cat > "$TMP/exp-partial.json" <<'EOF'
{ "is_error": false }
EOF
  run "$SCRIPT" "$TMP/exp-partial.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0.0000"* ]]
  [[ "$output" == *"TOTAL"* ]]
}

# ---------- workflow history rendering ----------

@test "workflow.json phase history is rendered when passed" {
  cat > "$TMP/workflow.json" <<'EOF'
{
  "slug": "exp",
  "phase": "closed",
  "history": [
    { "phase": "specifying", "entered_at": "2026-04-24T00:00:00Z" },
    { "phase": "implementing", "entered_at": "2026-04-24T00:10:00Z" },
    { "phase": "closed", "entered_at": "2026-04-24T00:30:00Z" }
  ]
}
EOF
  run "$SCRIPT" "$TMP/exp-*.json" "$TMP/workflow.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Phase history"* ]]
  [[ "$output" == *"specifying"* ]]
  [[ "$output" == *"implementing"* ]]
  [[ "$output" == *"closed"* ]]
}

@test "missing workflow.json path emits a warning but does not fail the run" {
  run "$SCRIPT" "$TMP/exp-*.json" "$TMP/nonexistent-workflow.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning"* ]] || [[ "$output" == *"not found"* ]]
}
