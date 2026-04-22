#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  WORKFLOW="$TMPDIR/workflow.json"
  cat > "$WORKFLOW" <<'EOF'
{
  "slug": "test-feature",
  "phase": "specifying",
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-01T00:00:00Z",
  "history": [
    { "phase": "specifying", "entered_at": "2026-01-01T00:00:00Z" }
  ],
  "artifacts": { "spec": "spec.md", "notes": "notes.md", "review": "review.md" }
}
EOF
  source "$(dirname "$BATS_TEST_FILENAME")/../lib/workflow.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

# --- read_phase ---

@test "read_phase returns current phase" {
  run read_phase "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" = "specifying" ]
}

@test "read_phase on a missing file exits 1" {
  run read_phase "$TMPDIR/nonexistent.json"
  [ "$status" -eq 1 ]
}

# --- validate_transition: legal ---

@test "validate_transition specifying implementing exits 0" {
  run validate_transition "specifying" "implementing"
  [ "$status" -eq 0 ]
}

@test "validate_transition implementing reviewing exits 0" {
  run validate_transition "implementing" "reviewing"
  [ "$status" -eq 0 ]
}

@test "validate_transition reviewing implementing exits 0" {
  run validate_transition "reviewing" "implementing"
  [ "$status" -eq 0 ]
}

@test "validate_transition reviewing closed exits 0" {
  run validate_transition "reviewing" "closed"
  [ "$status" -eq 0 ]
}

# --- validate_transition: illegal ---

@test "validate_transition specifying reviewing exits 1" {
  run validate_transition "specifying" "reviewing"
  [ "$status" -eq 1 ]
}

@test "validate_transition specifying closed exits 1" {
  run validate_transition "specifying" "closed"
  [ "$status" -eq 1 ]
}

@test "validate_transition implementing closed exits 1 (skip review)" {
  run validate_transition "implementing" "closed"
  [ "$status" -eq 1 ]
}

@test "validate_transition implementing specifying exits 1 (backwards)" {
  run validate_transition "implementing" "specifying"
  [ "$status" -eq 1 ]
}

@test "validate_transition reviewing specifying exits 1 (backwards)" {
  run validate_transition "reviewing" "specifying"
  [ "$status" -eq 1 ]
}

@test "validate_transition closed specifying exits 1 (terminal)" {
  run validate_transition "closed" "specifying"
  [ "$status" -eq 1 ]
}

@test "validate_transition closed implementing exits 1 (terminal)" {
  run validate_transition "closed" "implementing"
  [ "$status" -eq 1 ]
}

# --- set_phase ---

@test "set_phase legal transition updates the phase field" {
  run set_phase "$WORKFLOW" "implementing"
  [ "$status" -eq 0 ]
  run read_phase "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" = "implementing" ]
}

@test "set_phase legal transition appends to history" {
  set_phase "$WORKFLOW" "implementing"
  run jq '.history | length' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
  run jq -r '.history[-1].phase' "$WORKFLOW"
  [ "$output" = "implementing" ]
}

@test "set_phase illegal transition exits non-zero and does not modify the file" {
  local before
  before=$(cat "$WORKFLOW")
  run set_phase "$WORKFLOW" "reviewing"
  [ "$status" -ne 0 ]
  local after
  after=$(cat "$WORKFLOW")
  [ "$before" = "$after" ]
}

@test "read_phase exits 1 on malformed JSON" {
  echo "{invalid json}" > "$WORKFLOW"
  run read_phase "$WORKFLOW"
  [ "$status" -eq 1 ]
}

@test "read_phase exits 1 when phase field is null" {
  jq '.phase = null' "$WORKFLOW" > "$WORKFLOW.tmp" && mv "$WORKFLOW.tmp" "$WORKFLOW"
  run read_phase "$WORKFLOW"
  [ "$status" -eq 1 ]
}

@test "read_phase exits 1 when phase field is missing" {
  jq 'del(.phase)' "$WORKFLOW" > "$WORKFLOW.tmp" && mv "$WORKFLOW.tmp" "$WORKFLOW"
  run read_phase "$WORKFLOW"
  [ "$status" -eq 1 ]
}
