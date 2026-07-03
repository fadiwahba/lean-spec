#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

gate() {
  echo '{}' | bash "${LEAN_SPEC_HOOKS}/subagent-stop-gate.sh"
}

gate_with() {
  echo "$1" | bash "${LEAN_SPEC_HOOKS}/subagent-stop-gate.sh"
}

@test "allows when no features exist at all" {
  run gate
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "blocks when specifying phase's spec.md is missing" {
  lean_spec ensure demo
  run gate
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *"spec.md"* ]]
}

@test "allows when specifying phase's spec.md exists and rules enforce nothing" {
  lean_spec ensure demo
  mkdir -p features/demo
  echo "# spec" > features/demo/spec.md
  run gate
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "blocks when implementing phase's notes.md is missing" {
  lean_spec ensure demo
  lean_spec advance demo specifying implementing
  run gate
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *"notes.md"* ]]
}

@test "blocks when implementing phase's notes.md is missing TDD section (tdd default true)" {
  lean_spec ensure demo
  lean_spec advance demo specifying implementing
  mkdir -p features/demo
  echo "## What was built" > features/demo/notes.md
  run gate
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *"TDD"* ]]
}

@test "allows when implementing phase's notes.md has TDD evidence" {
  lean_spec ensure demo
  lean_spec advance demo specifying implementing
  mkdir -p features/demo
  printf '## What was built\nx\n## TDD\nred/green\n' > features/demo/notes.md
  run gate
  [ -z "$output" ]
}

@test "blocks when reviewing phase's review.md has no verdict" {
  lean_spec ensure demo
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "# review" > features/demo/review.md
  run gate
  [[ "$output" == *'"decision": "block"'* ]]
}

@test "allows when reviewing phase's review.md has a verdict" {
  lean_spec ensure demo
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: NEEDS_FIXES" > features/demo/review.md
  run gate
  [ -z "$output" ]
}

@test "allows silently once phase is closed" {
  lean_spec ensure demo
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  run gate
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "respects stop_hook_active — does not re-block a hook-driven continuation" {
  # The gate blocks an invalid artifact once (one retry for the agent); a
  # continuation that still fails passes through here and is caught by the
  # phase-gate backstop (CONSTITUTION principle 4). Without this, an agent
  # that can never satisfy validation would be re-blocked forever.
  lean_spec ensure demo
  run gate_with '{"stop_hook_active": true}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "resolves active feature from .lean-spec/auto.json when present" {
  lean_spec ensure demo
  lean_spec ensure other
  mkdir -p .lean-spec
  echo '{"slug":"other","gates_on":false,"max_cycles":20,"cycles":0}' > .lean-spec/auto.json
  # demo has no spec.md (would block); other also has none, but auto.json
  # pins "other" as the active feature, so the block message must name it.
  run gate
  [[ "$output" == *"other"* ]]
}
