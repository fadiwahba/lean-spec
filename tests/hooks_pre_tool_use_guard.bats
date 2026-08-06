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

# ── .lean-spec/auto.json (issue #21) ───────────────────────────────────────
# auto.json is the file that, once present, makes the Stop hook drive phases
# whose skills are all disable-model-invocation: true. Writing it is therefore
# equivalent to self-granting the human-authorization the gate withholds.
# `bin/lean-spec auto arm` is its designated writer, exactly as `advance` is
# workflow.json's — so this deny is unconditional.

@test "denies Write to .lean-spec/auto.json" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":".lean-spec/auto.json"}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "denies Edit to .lean-spec/auto.json" {
  run guard '{"tool_name":"Edit","tool_input":{"file_path":".lean-spec/auto.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "denies MultiEdit to .lean-spec/auto.json" {
  run guard '{"tool_name":"MultiEdit","tool_input":{"file_path":".lean-spec/auto.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "denies auto.json via an absolute path" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"/repo/.lean-spec/auto.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "denies auto.json reached via a ./ prefix" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"./.lean-spec/auto.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "denies auto.json reached via a ../ traversal that normalizes back in" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"features/demo/../../.lean-spec/auto.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "denies auto.json regardless of case (case-insensitive filesystem bypass)" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":".lean-spec/Auto.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "auto.json deny message names the CLI remedy" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":".lean-spec/auto.json"}}'
  [[ "$output" == *"auto arm"* ]]
}

@test "auto.json deny message names BOTH user entry points, not just auto-all" {
  # A remedy naming only /lean-spec:auto-all misdirects anyone arming a single
  # feature, whose entry point is /lean-spec:auto (Copilot review, PR #22).
  run guard '{"tool_name":"Write","tool_input":{"file_path":".lean-spec/auto.json"}}'
  [[ "$output" == *"/lean-spec:auto "* ]]
  [[ "$output" == *"/lean-spec:auto-all"* ]]
}

@test "denies NotebookEdit to .lean-spec/auto.json (full guarded tool set)" {
  run guard '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":".lean-spec/auto.json"}}'
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "allows Write to .lean-spec/rules.toml (only auto.json is guarded)" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":".lean-spec/rules.toml"}}'
  [ -z "$output" ]
}

@test "allows a file merely named autoXjson.json under .lean-spec" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":".lean-spec/autoXjson.json"}}'
  [ -z "$output" ]
}

@test "allows Read of .lean-spec/auto.json (non-guarded tool)" {
  run guard '{"tool_name":"Read","tool_input":{"file_path":".lean-spec/auto.json"}}'
  [ -z "$output" ]
}

@test "allows an auto.json NOT under .lean-spec/" {
  run guard '{"tool_name":"Write","tool_input":{"file_path":"config/auto.json"}}'
  [ -z "$output" ]
}

# ── deny payload must be valid JSON regardless of PLUGIN_ROOT ──────────────
# The reason string embeds CLAUDE_PLUGIN_ROOT. Interpolating it into a JSON
# heredoc unescaped means a path containing a double-quote, backslash or
# newline emits MALFORMED JSON — Claude Code cannot parse the decision, and a
# guard whose deny is unparseable FAILS OPEN. That is the exact failure class
# this hook exists to prevent. (Copilot suppressed-comment, PR #22.)

@test "deny payload is valid JSON when PLUGIN_ROOT contains a double quote" {
  run bash -c "CLAUDE_PLUGIN_ROOT='/tmp/pl\"ugin' bash '${LEAN_SPEC_HOOKS}/pre-tool-use-guard.sh' <<< '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\".lean-spec/auto.json\"}}'"
  [ "$status" -eq 0 ]
  run python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d['hookSpecificOutput']['permissionDecision'] == 'deny', d
print('ok')
" <<< "$output"
  [ "$output" = "ok" ]
}

@test "deny payload is valid JSON when PLUGIN_ROOT contains a backslash" {
  run bash -c "CLAUDE_PLUGIN_ROOT='/tmp/pl\\\\ugin' bash '${LEAN_SPEC_HOOKS}/pre-tool-use-guard.sh' <<< '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"features/demo/workflow.json\"}}'"
  [ "$status" -eq 0 ]
  run python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d['hookSpecificOutput']['permissionDecision'] == 'deny', d
print('ok')
" <<< "$output"
  [ "$output" = "ok" ]
}

@test "deny payload is valid JSON when PLUGIN_ROOT contains a newline" {
  run bash -c "CLAUDE_PLUGIN_ROOT=\$'/tmp/pl\nugin' bash '${LEAN_SPEC_HOOKS}/pre-tool-use-guard.sh' <<< '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\".lean-spec/auto.json\"}}'"
  [ "$status" -eq 0 ]
  run python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d['hookSpecificOutput']['permissionDecision'] == 'deny', d
print('ok')
" <<< "$output"
  [ "$output" = "ok" ]
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
