#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

@test "ensure creates workflow.json with phase specifying" {
  lean_spec ensure demo
  [ "$status" -eq 0 ]
  [ -f features/demo/workflow.json ]
  run python3 -c "import json; d=json.load(open('features/demo/workflow.json')); print(d['phase'])"
  [ "$output" = "specifying" ]
}

@test "ensure sets created_at, updated_at and empty history" {
  lean_spec ensure demo
  run python3 -c "
import json
d = json.load(open('features/demo/workflow.json'))
assert d['history'] == []
assert d['created_at']
assert d['updated_at']
print('ok')
"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "ensure is idempotent: re-running does not error or reset state" {
  lean_spec ensure demo
  mkdir -p features/demo
  echo "# spec" > features/demo/spec.md
  lean_spec advance demo specifying implementing
  lean_spec ensure demo
  [ "$status" -eq 0 ]
  run python3 -c "import json; print(json.load(open('features/demo/workflow.json'))['phase'])"
  [ "$output" = "implementing" ]
}

@test "ensure fails outside a git repo" {
  cd "${LEAN_SPEC_TESTDIR}"
  rm -rf .git
  lean_spec ensure demo
  [ "$status" -ne 0 ]
  [[ "$output" == *"git repo"* ]]
}

@test "ensure requires a slug argument" {
  lean_spec ensure
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}
