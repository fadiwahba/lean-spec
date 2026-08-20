#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
  lean_spec ensure demo
}

teardown() {
  lean_spec_teardown_repo
}

# advance now validates the artifact of the phase being left (CONSTITUTION
# principle 4), so any advance driven from these tests needs a valid
# spec.md/notes.md first.
write_valid_spec() {
  lean_spec_write_artifact demo spec.md <<'EOF'
# spec
EOF
}

write_valid_notes() {
  lean_spec_write_artifact demo notes.md <<'EOF'
## What was built
stuff

## TDD
red/green
EOF
}

@test "next: specifying phase routes to implement" {
  lean_spec next demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"/lean-spec:implement demo"* ]]
}

@test "next: implementing phase routes to review" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  lean_spec next demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"/lean-spec:review demo"* ]]
}

@test "next: reviewing + verdict APPROVE routes to close" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: APPROVE
EOF
  lean_spec next demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"/lean-spec:close demo"* ]]
}

@test "next: reviewing + verdict APPROVE with trailing text routes to close" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: APPROVE — LGTM
EOF
  lean_spec next demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"/lean-spec:close demo"* ]]
}

@test "next: reviewing + verdict NEEDS_FIXES routes to fix" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: NEEDS_FIXES
EOF
  lean_spec next demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"/lean-spec:fix demo"* ]]
}

@test "next: reviewing + verdict BLOCKED reports blocked (exit 3)" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: BLOCKED
EOF
  lean_spec next demo
  [ "$status" -eq 3 ]
  [[ "$output" == *"blocked"* ]] || [[ "$output" == *"BLOCKED"* ]]
}

@test "next: reviewing with missing review.md reports blocked (exit 3)" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec next demo
  [ "$status" -eq 3 ]
}

@test "next: closed phase reports nothing to do (exit 0)" {
  write_valid_spec
  lean_spec advance demo specifying implementing
  write_valid_notes
  lean_spec advance demo implementing reviewing
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: APPROVE
EOF
  lean_spec advance demo reviewing closed
  lean_spec next demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"closed"* ]]
}

@test "next --json emits parseable JSON with action/skill/slug" {
  lean_spec next demo --json
  [ "$status" -eq 0 ]
  run python3 -c "
import json
d = json.loads('''$output''')
assert d['slug'] == 'demo'
assert d['action'] == 'skill'
assert d['skill'] == '/lean-spec:implement'
print('ok')
"
  [ "$output" = "ok" ]
}

@test "next --all reports every feature and never fails on individual blocks" {
  lean_spec ensure second
  lean_spec next --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"demo"* ]]
  [[ "$output" == *"second"* ]]
}

@test "next --all with no features reports gracefully" {
  rm -rf .lean-spec/features
  lean_spec next --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"no features"* ]]
}

@test "next fails loudly on missing feature" {
  lean_spec next ghost
  [ "$status" -eq 1 ]
}

@test "next with no arguments prints usage and exits 1" {
  lean_spec next
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}
