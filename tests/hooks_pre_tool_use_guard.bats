#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

guard() {
  echo "$1" | bash "${LEAN_SPEC_HOOKS}/pre-tool-use-guard.sh"
}

@test "denies Write to features/<slug>/workflow.json" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"features/demo/workflow.json"}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "denies Edit to features/<slug>/workflow.json" {
  run guard '{"tool_name":"Edit","tool_input":{"file_path":"features/demo/workflow.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "denies MultiEdit to features/<slug>/workflow.json" {
  run guard '{"tool_name":"MultiEdit","tool_input":{"file_path":"features/demo/workflow.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "denies nested-path workflow.json (absolute path)" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"/repo/features/demo/workflow.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "allows Write to spec.md" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"features/demo/spec.md"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows Write to unrelated files" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"README.md"}}'
  [ -z "$output" ]
}

@test "allows non-guarded tools even on workflow.json" {
  run guard '{"tool_name":"Read","tool_input":{"file_path":"features/demo/workflow.json"}}'
  [ -z "$output" ]
}

@test "allows a file merely named workflowXjson.json (no false-positive substring match)" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"features/demo/workflowXjson.json"}}'
  [ -z "$output" ]
}

@test "does not crash on malformed JSON input (fails safe: allow)" {
  run guard 'not json at all'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "does not crash on empty input" {
  run guard ''
  [ "$status" -eq 0 ]
}
