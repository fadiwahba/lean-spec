#!/usr/bin/env bats
# /lean-spec:implement --no-tdd is a documented per-invocation opt-out for a
# spike, but the notes.md TDD gate read only the GLOBAL rules.toml default,
# so with the default tdd=true a --no-tdd notes.md (no ## TDD) was rejected
# by the very validate the skill runs. The decision must persist per-feature
# in workflow.json (set at advance time) and be honored by validate + gate.

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
  lean_spec ensure demo
  mkdir -p features/demo
  echo "# spec" > features/demo/spec.md
}

teardown() {
  lean_spec_teardown_repo
}

@test "advance --no-tdd records tdd:false in workflow.json" {
  lean_spec advance demo specifying implementing --no-tdd
  [ "$status" -eq 0 ]
  run python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['tdd'])"
  [ "$output" = "False" ]
}

@test "validate notes.md without a TDD section passes when the feature opted out via --no-tdd" {
  lean_spec advance demo specifying implementing --no-tdd
  printf '## What was built\nstuff\n' > features/demo/notes.md
  lean_spec validate demo notes.md
  [ "$status" -eq 0 ]
}

@test "the phase gate lets a --no-tdd feature leave implementing without a TDD section" {
  lean_spec advance demo specifying implementing --no-tdd
  printf '## What was built\nstuff\n' > features/demo/notes.md
  lean_spec advance demo implementing reviewing
  [ "$status" -eq 0 ]
}

@test "default (no --no-tdd) still requires a TDD section in notes.md" {
  lean_spec advance demo specifying implementing
  printf '## What was built\nstuff\n' > features/demo/notes.md
  lean_spec validate demo notes.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"TDD"* ]]
}

@test "advance --tdd records tdd:true and re-enforces the TDD section" {
  lean_spec advance demo specifying implementing --tdd
  printf '## What was built\nstuff\n' > features/demo/notes.md
  lean_spec validate demo notes.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"TDD"* ]]
}
