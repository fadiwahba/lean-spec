#!/usr/bin/env bats
# Guards finding [MEDIUM]: load_workflow only catches JSONDecodeError; a
# valid-JSON-but-non-dict workflow.json (e.g. `[]`) then hits `.get()` and
# crashes with an uncaught AttributeError traceback, violating CONSTITUTION
# principle 8 (fail loudly, one-line actionable message, never a traceback).

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
  lean_spec ensure demo
}

teardown() {
  lean_spec_teardown_repo
}

write_non_dict_workflow() {
  printf '[]' > features/demo/workflow.json
}

@test "status on a non-dict workflow.json fails loudly, no traceback" {
  write_non_dict_workflow
  lean_spec status demo
  [ "$status" -eq 1 ]
  [[ "$output" == *"corrupt workflow.json"* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "advance on a non-dict workflow.json fails loudly, no traceback" {
  write_non_dict_workflow
  lean_spec advance demo specifying implementing
  [ "$status" -eq 1 ]
  [[ "$output" == *"corrupt workflow.json"* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "advance on a dict workflow.json with non-list history fails loudly, no traceback" {
  printf '{"phase":"specifying","history":"oops","created_at":"x","updated_at":"x"}' > features/demo/workflow.json
  mkdir -p features/demo
  echo "# spec" > features/demo/spec.md
  lean_spec advance demo specifying implementing
  [ "$status" -eq 1 ]
  [[ "$output" == *"corrupt workflow.json"* ]]
  [[ "$output" != *"Traceback"* ]]
}
