#!/usr/bin/env bats
#
# decompose-prd.bats — integration test for /lean-spec:decompose-prd.
#
# The command lives as a markdown body in commands/decompose-prd.md. This test
# replays the critical bash steps (source prd-parser, iterate slugs, write
# workflow.json + spec.md skeletons) and asserts the resulting tree.

setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TMP="$(mktemp -d)"
  cd "$TMP"
  mkdir -p docs

  # shellcheck disable=SC1091
  source "$PLUGIN_ROOT/lib/prd-parser.sh"
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
}

teardown() {
  rm -rf "$TMP"
}

# Helper: minimal but realistic PRD with a Features section.
write_prd() {
  cat > docs/PRD.md <<'EOF'
# Todo App PRD

**Design reference:** docs/ux-design.png

## 1. Overview

A minimal todo app.

## 4. Features

### 4.1 Add Task Input
Text input with submit. Validates non-empty input.

### 4.2 Stats Bar
Counters for active and completed tasks.

### 4.3 Task List
Renders tasks with checkbox + strikethrough for completed.

## 5. State Model

Stuff.

## 8. Out of Scope

Other stuff.
EOF
}

# Helper: replay the critical portion of commands/decompose-prd.md against the PRD.
run_decompose() {
  local prd="${1:-docs/PRD.md}"
  local slugs
  slugs=$(list_feature_slugs "$prd")
  [ -z "$slugs" ] && return 1

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    local dir="features/$slug"
    [ -d "$dir" ] && continue
    mkdir -p "$dir"

    local title scope
    title=$(feature_section_title "$prd" "$slug")
    scope=$(feature_scope "$prd" "$slug")

    cat > "$dir/workflow.json" <<EOF
{
  "slug": "$slug",
  "phase": "specifying",
  "created_at": "$now",
  "updated_at": "$now",
  "history": [{ "phase": "specifying", "entered_at": "$now" }],
  "artifacts": { "spec": "spec.md", "notes": "notes.md", "review": "review.md" }
}
EOF

    cat > "$dir/spec.md" <<EOF
---
slug: $slug
phase: specifying
handoffs:
  next_command: /lean-spec:submit-implementation $slug
  blocks_on: []
  consumed_by: [coder, reviewer]
---

# $title

## Scope
$scope

## Acceptance Criteria
(fill via /lean-spec:update-spec $slug)
EOF
  done <<< "$slugs"
}

# ---------- tests ----------

@test "decompose creates one features/<slug>/ per feature in the PRD" {
  write_prd
  run_decompose
  [ -d features/add-task-input ]
  [ -d features/stats-bar ]
  [ -d features/task-list ]
}

@test "each feature dir has a valid workflow.json in specifying phase" {
  write_prd
  run_decompose
  for slug in add-task-input stats-bar task-list; do
    wf="features/$slug/workflow.json"
    [ -f "$wf" ]
    run jq -r '.phase' "$wf"
    [ "$output" = "specifying" ]
    run jq -r '.slug' "$wf"
    [ "$output" = "$slug" ]
    run jq -r '.history | length' "$wf"
    [ "$output" = "1" ]
  done
}

@test "each feature dir has a spec.md with valid frontmatter + populated Scope" {
  write_prd
  run_decompose
  spec="features/stats-bar/spec.md"
  [ -f "$spec" ]
  grep -q "^slug: stats-bar" "$spec"
  grep -q "^phase: specifying" "$spec"
  grep -qE "^[[:space:]]+next_command: /lean-spec:submit-implementation stats-bar" "$spec"
  # Scope populated from the PRD paragraph
  grep -q "Counters for active and completed tasks" "$spec"
}

@test "decompose is idempotent — re-running skips existing directories" {
  write_prd
  run_decompose
  # Mutate one spec to a marker; re-running must not clobber it
  echo "USER-EDIT-MARKER" >> features/add-task-input/spec.md
  run_decompose
  grep -q "USER-EDIT-MARKER" features/add-task-input/spec.md
}

@test "decompose produces skeletons that pass the pre-tool-use-workflow safety (hook would not fire — bash writes)" {
  # The pre-tool-use-workflow hook blocks Write/Edit TOOL calls on workflow.json.
  # This command uses bash heredocs, so the hook's matcher does not apply.
  # This test just documents that invariant for future readers.
  write_prd
  run_decompose
  [ -f features/add-task-input/workflow.json ]
}

@test "decompose fails gracefully when the PRD has no Features section" {
  cat > docs/PRD.md <<'EOF'
# Not a feature list
## Overview
## Conclusion
EOF
  run run_decompose
  [ "$status" -ne 0 ]
}
