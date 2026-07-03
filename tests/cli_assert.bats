#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
  lean_spec ensure demo
}

teardown() {
  lean_spec_teardown_repo
}

@test "assert succeeds when phase matches" {
  lean_spec assert demo specifying
  [ "$status" -eq 0 ]
}

@test "assert exits 2 on phase mismatch" {
  lean_spec assert demo implementing
  [ "$status" -eq 2 ]
  [[ "$output" == *"assert failed"* ]]
}

@test "assert fails loudly on missing feature" {
  lean_spec assert ghost specifying
  [ "$status" -eq 1 ]
}

@test "assert requires exactly two arguments" {
  lean_spec assert demo
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}
