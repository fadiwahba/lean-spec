#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
  mkdir -p .lean-spec
}

teardown() {
  lean_spec_teardown_repo
}

write_project_docs() {
  cat > .lean-spec/PRD.md <<'EOF'
# Demo

## Problem & Users

Build a demo.

## Features

Add one safe change.

## Constraints

Use the current stack.

## Quality Bar

Run the test suite.

## Existing System & Behaviour

No product behaviour exists yet; this repository is a framework scaffold only.

## Compatibility & Migration

No compatibility or data migration is required.

## Regression Checks

Run .tools/bin/bats tests.

## Non-Goals

None.
EOF
  cat > .lean-spec/CONSTITUTION.md <<'EOF'
# Demo constitution

## Stack

Python.

## Principles

Use CLI gates.

## Delegation

One owner per phase.

## Quality Bars

Tests pass.

## Process

Use git.

## Non-Goals

None.
EOF
}

@test "readiness returns one project NEEDS_INPUT object for a missing compatibility decision" {
  write_project_docs
  sed -i.bak '/## Compatibility & Migration/,/## Regression Checks/d' .lean-spec/PRD.md
  rm .lean-spec/PRD.md.bak

  lean_spec readiness --no-confirm --json

  [ "$status" -eq 0 ]
  run python3 -c '
import json, sys
result = json.loads(sys.stdin.read())
assert result["schema_version"] == 1
assert result["outcome"] == "NEEDS_INPUT"
assert result["input_scope"] == "project"
assert result["slug"] is None
assert result["resume_step"] == "plan"
assert result["question"].count("?") == 1
' <<< "$output"
  [ "$status" -eq 0 ]
}

@test "readiness returns READY when project decisions are explicit" {
  write_project_docs

  lean_spec readiness --no-confirm --json

  [ "$status" -eq 0 ]
  run python3 -c '
import json, sys
result = json.loads(sys.stdin.read())
assert result == {
    "schema_version": 1,
    "outcome": "READY",
    "step": "spec",
    "slug": None,
    "owner": "architect",
    "artifact": "spec.md",
    "gate": "project-readiness-valid",
}
' <<< "$output"
  [ "$status" -eq 0 ]
}
