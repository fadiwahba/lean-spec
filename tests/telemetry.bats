#!/usr/bin/env bats
#
# telemetry.bats — verify lib/telemetry.sh opt-in behavior + idempotent sync.

setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TMP="$(mktemp -d)"
  cd "$TMP"
  mkdir -p features/foo

  # Use a scratch telemetry dir so we don't touch the user's real ~/.lean-spec
  export LEAN_SPEC_TELEMETRY_DIR="$TMP/.lean-spec"

  # shellcheck disable=SC1091
  source "$PLUGIN_ROOT/lib/telemetry.sh"
}

teardown() {
  rm -rf "$TMP"
  unset LEAN_SPEC_TELEMETRY LEAN_SPEC_TELEMETRY_DIR
}

write_wf() {
  # write a workflow.json with the given history as tab-separated lines
  local wf="$1"; shift
  local history_entries="["
  local first=1
  while [ "$#" -ge 2 ]; do
    local phase="$1"; local entered="$2"; shift 2
    if [ "$first" -eq 1 ]; then first=0; else history_entries="${history_entries},"; fi
    history_entries="${history_entries}{\"phase\":\"$phase\",\"entered_at\":\"$entered\"}"
  done
  history_entries="${history_entries}]"

  echo "{\"slug\":\"foo\",\"phase\":\"specifying\",\"created_at\":\"2026-04-24T10:00:00Z\",\"updated_at\":\"2026-04-24T10:00:00Z\",\"history\":$history_entries}" > "$wf"
}

# ---------- opt-in gate ----------

@test "telemetry_enabled is false by default" {
  unset LEAN_SPEC_TELEMETRY
  run telemetry_enabled
  [ "$status" -ne 0 ]
}

@test "telemetry_enabled is true with env var set" {
  export LEAN_SPEC_TELEMETRY=1
  run telemetry_enabled
  [ "$status" -eq 0 ]
}

@test "telemetry_enabled is true with marker file set to 'on'" {
  unset LEAN_SPEC_TELEMETRY
  mkdir -p "$LEAN_SPEC_TELEMETRY_DIR"
  echo "on" > "$LEAN_SPEC_TELEMETRY_DIR/telemetry"
  run telemetry_enabled
  [ "$status" -eq 0 ]
}

@test "telemetry_enabled is false with marker file set to 'off'" {
  unset LEAN_SPEC_TELEMETRY
  mkdir -p "$LEAN_SPEC_TELEMETRY_DIR"
  echo "off" > "$LEAN_SPEC_TELEMETRY_DIR/telemetry"
  run telemetry_enabled
  [ "$status" -ne 0 ]
}

# ---------- sync when disabled ----------

@test "telemetry_sync is no-op when telemetry disabled" {
  unset LEAN_SPEC_TELEMETRY
  write_wf features/foo/workflow.json specifying "2026-04-24T10:00:00Z"
  telemetry_sync features/foo/workflow.json
  [ ! -f "$LEAN_SPEC_TELEMETRY_DIR/telemetry.jsonl" ]
}

# ---------- sync writes records ----------

@test "telemetry_sync writes one record per history entry" {
  export LEAN_SPEC_TELEMETRY=1
  write_wf features/foo/workflow.json \
    specifying "2026-04-24T10:00:00Z" \
    implementing "2026-04-24T10:10:00Z" \
    reviewing "2026-04-24T10:20:00Z" \
    closed "2026-04-24T10:30:00Z"

  telemetry_sync features/foo/workflow.json

  [ -f "$LEAN_SPEC_TELEMETRY_DIR/telemetry.jsonl" ]
  run wc -l < "$LEAN_SPEC_TELEMETRY_DIR/telemetry.jsonl"
  [ "${output// /}" = "4" ]

  # First record: specifying, prev_phase null, elapsed null
  FIRST=$(head -1 "$LEAN_SPEC_TELEMETRY_DIR/telemetry.jsonl")
  echo "$FIRST" | jq -e '.phase == "specifying"' >/dev/null
  echo "$FIRST" | jq -e '.prev_phase == null' >/dev/null
  echo "$FIRST" | jq -e '.elapsed_prev_ms == null' >/dev/null

  # Last record: closed, prev_phase reviewing, elapsed 10 minutes = 600000 ms
  LAST=$(tail -1 "$LEAN_SPEC_TELEMETRY_DIR/telemetry.jsonl")
  echo "$LAST" | jq -e '.phase == "closed"' >/dev/null
  echo "$LAST" | jq -e '.prev_phase == "reviewing"' >/dev/null
  echo "$LAST" | jq -e '.elapsed_prev_ms == 600000' >/dev/null
}

# ---------- idempotence ----------

@test "telemetry_sync is idempotent — no duplicate records on re-run" {
  export LEAN_SPEC_TELEMETRY=1
  write_wf features/foo/workflow.json \
    specifying "2026-04-24T10:00:00Z" \
    implementing "2026-04-24T10:10:00Z"

  telemetry_sync features/foo/workflow.json
  local first_count
  first_count=$(wc -l < "$LEAN_SPEC_TELEMETRY_DIR/telemetry.jsonl" | tr -d ' ')
  [ "$first_count" = "2" ]

  telemetry_sync features/foo/workflow.json
  telemetry_sync features/foo/workflow.json
  local after_count
  after_count=$(wc -l < "$LEAN_SPEC_TELEMETRY_DIR/telemetry.jsonl" | tr -d ' ')
  [ "$after_count" = "2" ]
}

# ---------- sync_all across multiple features ----------

@test "telemetry_sync_all walks features/*/workflow.json" {
  export LEAN_SPEC_TELEMETRY=1
  mkdir -p features/bar
  write_wf features/foo/workflow.json specifying "2026-04-24T10:00:00Z"
  write_wf features/bar/workflow.json \
    specifying "2026-04-24T11:00:00Z" \
    implementing "2026-04-24T11:15:00Z"

  telemetry_sync_all "$PWD"
  run wc -l < "$LEAN_SPEC_TELEMETRY_DIR/telemetry.jsonl"
  [ "${output// /}" = "3" ]
}

# ---------- report ----------

@test "telemetry_report on empty log prints opt-in hint" {
  run telemetry_report
  [ "$status" -eq 0 ]
  [[ "$output" == *"No telemetry records"* ]]
}

@test "telemetry_report prints per-feature summary" {
  export LEAN_SPEC_TELEMETRY=1
  write_wf features/foo/workflow.json \
    specifying "2026-04-24T10:00:00Z" \
    implementing "2026-04-24T10:10:00Z" \
    closed "2026-04-24T10:15:00Z"
  telemetry_sync features/foo/workflow.json

  run telemetry_report
  [ "$status" -eq 0 ]
  [[ "$output" == *"foo"* ]]
  [[ "$output" == *"specifying"* ]]
  [[ "$output" == *"implementing"* ]]
  [[ "$output" == *"closed"* ]]
}

@test "telemetry_report filters by slug when given an arg" {
  export LEAN_SPEC_TELEMETRY=1
  mkdir -p features/bar
  write_wf features/foo/workflow.json specifying "2026-04-24T10:00:00Z"
  write_wf features/bar/workflow.json specifying "2026-04-24T11:00:00Z"
  telemetry_sync features/foo/workflow.json
  telemetry_sync features/bar/workflow.json

  run telemetry_report "foo"
  [[ "$output" == *"foo"* ]]
  [[ "$output" != *"bar  "* ]]  # "bar" as a feature row, not substring match
}
