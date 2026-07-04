#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
  lean_spec ensure demo
}

teardown() {
  lean_spec_teardown_repo
}

# CONSTITUTION principle 4: "an invalid artifact blocks the advance" — since
# advance now validates the artifact of the phase being left (spec.md
# leaving specifying, notes.md leaving implementing), every test below that
# drives a real transition must first write a valid artifact.

write_valid_spec() {
  lean_spec_write_artifact demo spec.md <<'EOF'
# Spec: demo

## Scope
things
EOF
}

write_valid_notes() {
  lean_spec_write_artifact demo notes.md <<'EOF'
## What was built
stuff

## TDD
red/green evidence
EOF
}

@test "advance specifying -> implementing succeeds" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  [ "$status" -eq 0 ]
  run python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['phase'])"
  [ "$output" = "implementing" ]
}

@test "advance specifying -> implementing fails when spec.md is missing (exit 2)" {
  lean_spec advance demo specifying implementing
  [ "$status" -eq 2 ]
  [[ "$output" == *"spec.md"* ]]
  run python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['phase'])"
  [ "$output" = "specifying" ]
}

@test "advance implementing -> reviewing succeeds" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  [ "$status" -eq 0 ]
  run python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['phase'])"
  [ "$output" = "reviewing" ]
}

@test "advance implementing -> reviewing fails when notes.md is missing (exit 2)" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing reviewing
  [ "$status" -eq 2 ]
  [[ "$output" == *"notes.md"* ]]
  run python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['phase'])"
  [ "$output" = "implementing" ]
}

@test "advance reviewing -> closed succeeds when verdict is APPROVE" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: APPROVE
EOF
  lean_spec advance demo reviewing closed
  [ "$status" -eq 0 ]
  run python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['phase'])"
  [ "$output" = "closed" ]
}

@test "advance reviewing -> closed succeeds when verdict has trailing text (APPROVE ...)" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: APPROVE — LGTM
EOF
  lean_spec advance demo reviewing closed
  [ "$status" -eq 0 ]
  run python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['phase'])"
  [ "$output" = "closed" ]
}

@test "advance reviewing -> closed is rejected without an APPROVE verdict" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec advance demo reviewing closed
  [ "$status" -eq 2 ]
  [[ "$output" == *"review.md not found"* ]]
}

@test "advance reviewing -> closed is rejected when verdict is NEEDS_FIXES" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: NEEDS_FIXES
EOF
  lean_spec advance demo reviewing closed
  [ "$status" -eq 2 ]
  [[ "$output" == *"NEEDS_FIXES"* ]]
  run python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['phase'])"
  [ "$output" = "reviewing" ]
}

@test "advance reviewing -> implementing (fix loop) succeeds" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec advance demo reviewing implementing
  [ "$status" -eq 0 ]
  run python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['phase'])"
  [ "$output" = "implementing" ]
}

@test "advance records history entry with from/to/at" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  run python3 -c "
import json
h = json.load(open('features/demo/workflow.json'))['history']
assert len(h) == 1
assert h[0]['from'] == 'specifying'
assert h[0]['to'] == 'implementing'
assert h[0]['at']
print('ok')
"
  [ "$output" = "ok" ]
}

@test "advance rejects mismatched from-phase (exit 2)" {
  lean_spec advance demo implementing reviewing
  [ "$status" -eq 2 ]
  [[ "$output" == *"specifying"* ]]
}

@test "advance rejects illegal transition specifying -> reviewing (exit 2)" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing specifying
  [ "$status" -eq 2 ]
  [[ "$output" == *"illegal transition"* ]]
}

@test "advance rejects illegal transition specifying -> closed (exit 2)" {
  lean_spec advance demo specifying closed
  [ "$status" -eq 2 ]
}

@test "advance rejects transitions out of closed" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: APPROVE
EOF
  lean_spec advance demo reviewing closed
  lean_spec advance demo closed implementing
  [ "$status" -eq 2 ]
}

@test "advance rejects unknown phase names" {
  lean_spec advance demo specifying bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown phase"* ]]
}

@test "advance fails loudly on missing feature" {
  lean_spec advance ghost specifying implementing
  [ "$status" -eq 1 ]
  [[ "$output" == *"ensure"* ]]
}

@test "advance requires exactly three arguments" {
  lean_spec advance demo specifying
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "advance is atomic: workflow.json is never left partially written" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  # simulate re-reading immediately after; file must be valid JSON always
  run python3 -c "import json; json.load(open('features/demo/workflow.json')); print('valid')"
  [ "$output" = "valid" ]
}

@test "advance leaves no stray tmp files behind in the feature directory" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  run bash -c "ls -1 features/demo | grep -c '^\.workflow'"
  [ "$output" = "0" ]
}

@test "a rejected illegal transition leaves workflow.json completely untouched" {
  before_phase="$(python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['phase'])")"
  before_updated="$(python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['updated_at'])")"
  lean_spec advance demo implementing reviewing
  [ "$status" -eq 2 ]
  after_phase="$(python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['phase'])")"
  after_updated="$(python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['updated_at'])")"
  [ "$before_phase" = "$after_phase" ]
  [ "$before_updated" = "$after_updated" ]
}
