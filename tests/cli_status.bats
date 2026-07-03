#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

@test "status with no features reports gracefully" {
  lean_spec status
  [ "$status" -eq 0 ]
  [[ "$output" == *"no features"* ]]
}

@test "status lists all features with phase" {
  lean_spec ensure demo
  lean_spec ensure second
  lean_spec advance second specifying implementing
  lean_spec status
  [ "$status" -eq 0 ]
  [[ "$output" == *"demo: specifying"* ]]
  [[ "$output" == *"second: implementing"* ]]
}

@test "status <slug> reports detailed fields" {
  lean_spec ensure demo
  lean_spec status demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"phase: specifying"* ]]
  [[ "$output" == *"history_len: 0"* ]]
}

@test "status <slug> --json is parseable" {
  lean_spec ensure demo
  lean_spec status demo --json
  [ "$status" -eq 0 ]
  run python3 -c "
import json
d = json.loads('''$output''')
assert d['slug'] == 'demo'
assert d['phase'] == 'specifying'
print('ok')
"
  [ "$output" = "ok" ]
}

@test "status <slug> in reviewing phase reports verdict field" {
  lean_spec ensure demo
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing reviewing
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: APPROVE
EOF
  lean_spec status demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict: APPROVE"* ]]
}

@test "status fails loudly on missing feature" {
  lean_spec status ghost
  [ "$status" -eq 1 ]
}
