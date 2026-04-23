#!/usr/bin/env bats
#
# prd-parser.bats — verify lib/prd-parser.sh extracts feature sections from
# a project-level PRD.md.

setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TMP="$(mktemp -d)"
  PRD="$TMP/PRD.md"

  # shellcheck disable=SC1091
  source "$PLUGIN_ROOT/lib/prd-parser.sh"
}

teardown() {
  rm -rf "$TMP"
}

# ---------- list_feature_slugs ----------

@test "list_feature_slugs emits slugs in document order" {
  cat > "$PRD" <<'EOF'
# Sample

## 4. Features

### 4.1 Add Task Input
Text input.

### 4.2 Stats Bar
Two counters.

### 4.3 Task List
Cards.

## 5. State Model
EOF
  run list_feature_slugs "$PRD"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "add-task-input" ]
  [ "${lines[1]}" = "stats-bar" ]
  [ "${lines[2]}" = "task-list" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "list_feature_slugs handles '## Features' without a section number" {
  cat > "$PRD" <<'EOF'
# Sample

## Features

### Login Form
Stuff.

### Profile Page
Stuff.

## Other
EOF
  run list_feature_slugs "$PRD"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "login-form" ]
  [ "${lines[1]}" = "profile-page" ]
}

@test "list_feature_slugs returns empty on PRD with no Features section" {
  cat > "$PRD" <<'EOF'
# Sample

## Overview
No features here.

## Conclusion
EOF
  run list_feature_slugs "$PRD"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "list_feature_slugs fails on missing file" {
  run list_feature_slugs "/nonexistent/PRD.md"
  [ "$status" -ne 0 ]
}

@test "list_feature_slugs strips punctuation and collapses spaces" {
  cat > "$PRD" <<'EOF'
## 4. Features

### 4.1 "Group Completed" Toggle!
Stuff.

### 4.2 Task List / Grouping
Stuff.
EOF
  run list_feature_slugs "$PRD"
  [ "${lines[0]}" = "group-completed-toggle" ]
  [ "${lines[1]}" = "task-list-grouping" ]
}

# ---------- feature_section_title ----------

@test "feature_section_title returns the full heading for a known slug" {
  cat > "$PRD" <<'EOF'
## 4. Features

### 4.1 Add Task Input
Body.

### 4.2 Stats Bar
Body.
EOF
  run feature_section_title "$PRD" "add-task-input"
  [ "$output" = "4.1 Add Task Input" ]
}

@test "feature_section_title returns empty for an unknown slug" {
  cat > "$PRD" <<'EOF'
## 4. Features

### 4.1 Foo
EOF
  run feature_section_title "$PRD" "bar"
  [ -z "$output" ]
}

# ---------- feature_scope ----------

@test "feature_scope returns the opening paragraph of the feature" {
  cat > "$PRD" <<'EOF'
## 4. Features

### 4.1 Add Task Input
Text input with a submit button. Accepts non-empty input only.

### 4.2 Stats Bar
Two counters.
EOF
  run feature_scope "$PRD" "add-task-input"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Text input"* ]]
  [[ "$output" != *"Two counters"* ]]
}

@test "feature_scope returns empty for an unknown slug" {
  cat > "$PRD" <<'EOF'
## 4. Features

### 4.1 Foo
Body.
EOF
  run feature_scope "$PRD" "missing"
  [ -z "$output" ]
}

@test "feature_scope stops at next ### heading" {
  cat > "$PRD" <<'EOF'
## 4. Features

### 4.1 Foo
Para one of Foo.

### 4.2 Bar
Para one of Bar. Must not appear in Foo scope.
EOF
  run feature_scope "$PRD" "foo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Para one of Foo"* ]]
  [[ "$output" != *"Para one of Bar"* ]]
}

# ---------- end-to-end against templates/PRD.md as a sanity check ----------

@test "parser runs on the canonical template without crashing" {
  # templates/PRD.md has placeholder features but the structure is valid.
  # We're just verifying the parser doesn't error; it may return zero or more slugs.
  run list_feature_slugs "$PLUGIN_ROOT/templates/PRD.md"
  [ "$status" -eq 0 ]
}
