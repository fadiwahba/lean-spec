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

@test "does not crash on valid JSON that is not an object (top-level array)" {
  run guard '[1,2,3]'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "does not crash when tool_input is valid JSON but not an object" {
  run guard '{"tool_name":"Write","tool_input":["not","a","dict"]}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "does not crash on a bare JSON scalar" {
  run guard '42'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies workflow.json regardless of case (case-insensitive filesystem bypass)" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"features/demo/Workflow.json"}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "denies workflow.json reached via a ./ prefix" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"./features/demo/workflow.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "denies workflow.json reached via a ../ traversal that normalizes back into features/" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"features/demo/../other/workflow.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "allows a ~200KB Write to a normal path without failing open (payload exceeds argv limits)" {
  payload_file="$(mktemp "${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}/payloadXXXXXX")"
  python3 -c "
import json
content = 'x' * 200000
print(json.dumps({'tool_name': 'Write', 'tool_input': {'file_path': 'README.md', 'content': content}}))
" > "$payload_file"
  run bash -c "cat '${payload_file}' | bash '${LEAN_SPEC_HOOKS}/pre-tool-use-guard.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rm -f "$payload_file"
}

@test "still denies a ~200KB Write targeting features/x/workflow.json (does not fail open)" {
  payload_file="$(mktemp "${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}/payloadXXXXXX")"
  python3 -c "
import json
content = 'x' * 200000
print(json.dumps({'tool_name': 'Write', 'tool_input': {'file_path': 'features/x/workflow.json', 'content': content}}))
" > "$payload_file"
  run bash -c "cat '${payload_file}' | bash '${LEAN_SPEC_HOOKS}/pre-tool-use-guard.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
  rm -f "$payload_file"
}
