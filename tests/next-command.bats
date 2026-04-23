#!/usr/bin/env bats
#
# next-command.bats — verify lib/next-command.sh resolves the correct next
# slash command for each (phase, verdict) combination.

setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TMP="$(mktemp -d)"
  cd "$TMP"
  mkdir -p features

  # shellcheck disable=SC1091
  source "$PLUGIN_ROOT/lib/next-command.sh"
}

teardown() {
  rm -rf "$TMP"
}

# Helper: create a feature at a given phase (and optional verdict).
make_feature() {
  local slug="$1" phase="$2" verdict="${3:-}"
  local updated="${4:-2026-04-24T10:00:00Z}"
  mkdir -p "features/$slug"
  cat > "features/$slug/workflow.json" <<EOF
{
  "slug": "$slug",
  "phase": "$phase",
  "updated_at": "$updated",
  "history": []
}
EOF
  if [ -n "$verdict" ]; then
    cat > "features/$slug/review.md" <<EOF
---
slug: $slug
verdict: $verdict
---
# Review
EOF
  fi
}

# ---------- next_command_for ----------

@test "next_command_for specifying → submit-implementation" {
  make_feature foo specifying
  run next_command_for features/foo/workflow.json
  [ "$status" -eq 0 ]
  [ "$output" = "/lean-spec:submit-implementation foo" ]
}

@test "next_command_for implementing → submit-review" {
  make_feature foo implementing
  run next_command_for features/foo/workflow.json
  [ "$output" = "/lean-spec:submit-review foo" ]
}

@test "next_command_for reviewing + APPROVE → close-spec" {
  make_feature foo reviewing APPROVE
  run next_command_for features/foo/workflow.json
  [ "$output" = "/lean-spec:close-spec foo" ]
}

@test "next_command_for reviewing + NEEDS_FIXES → submit-fixes" {
  make_feature foo reviewing NEEDS_FIXES
  run next_command_for features/foo/workflow.json
  [ "$output" = "/lean-spec:submit-fixes foo" ]
}

@test "next_command_for reviewing + BLOCKED → human intervention" {
  make_feature foo reviewing BLOCKED
  run next_command_for features/foo/workflow.json
  [[ "$output" == *"BLOCKED"* ]]
  [[ "$output" == *"foo"* ]]
}

@test "next_command_for reviewing without review.md → spec-status (awaiting)" {
  make_feature foo reviewing
  # no verdict → no review.md
  run next_command_for features/foo/workflow.json
  [[ "$output" == *"/lean-spec:spec-status foo"* ]]
  [[ "$output" == *"awaiting reviewer"* ]]
}

@test "next_command_for closed → empty (no advance)" {
  make_feature foo closed
  run next_command_for features/foo/workflow.json
  [ -z "$output" ]
}

@test "next_command_for with missing workflow.json → empty, no crash" {
  run next_command_for "/nonexistent/workflow.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "next_command_for with unknown phase → empty, no crash" {
  mkdir -p features/bar
  cat > features/bar/workflow.json <<'EOF'
{"slug":"bar","phase":"mystery","updated_at":"2026-04-24T10:00:00Z","history":[]}
EOF
  run next_command_for features/bar/workflow.json
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------- active_feature ----------

@test "active_feature empty features dir → empty" {
  run active_feature features
  [ -z "$output" ]
}

@test "active_feature single open feature → returns its workflow.json" {
  make_feature foo specifying
  run active_feature features
  [[ "$output" == *"features/foo/workflow.json"* ]]
}

@test "active_feature picks most-recently-updated non-closed feature" {
  make_feature older implementing "" "2026-04-24T08:00:00Z"
  make_feature newer specifying "" "2026-04-24T12:00:00Z"
  run active_feature features
  [[ "$output" == *"features/newer/workflow.json"* ]]
}

@test "active_feature skips closed features even if most-recently-updated" {
  make_feature closed-but-recent closed "" "2026-04-24T12:00:00Z"
  make_feature open-but-older implementing "" "2026-04-24T08:00:00Z"
  run active_feature features
  [[ "$output" == *"features/open-but-older/workflow.json"* ]]
}

@test "active_feature returns empty when all features closed" {
  make_feature a closed
  make_feature b closed
  run active_feature features
  [ -z "$output" ]
}
