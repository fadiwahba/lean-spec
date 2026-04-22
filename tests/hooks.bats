#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/features/test-feature"
  # Create a valid workflow.json in specifying phase
  cat > "$TMPDIR/features/test-feature/workflow.json" <<'EOF'
{"slug":"test-feature","phase":"specifying","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","history":[{"phase":"specifying","entered_at":"2026-01-01T00:00:00Z"}],"artifacts":{"spec":"spec.md","notes":"notes.md","review":"review.md"}}
EOF
  # Make scripts executable
  chmod +x "$BATS_TEST_DIRNAME/../hooks/"*.sh
  HOOKS="$BATS_TEST_DIRNAME/../hooks"
}

teardown() {
  rm -rf "$TMPDIR"
}

# Helper: build hook input JSON
hook_input() {
  local event="$1"
  shift
  echo "{\"hook_event_name\":\"$event\",\"cwd\":\"$TMPDIR\",$*}"
}

# ─── session-start.sh ───

@test "session-start: outputs additionalContext with active feature" {
  run bash -c "echo '{\"hook_event_name\":\"SessionStart\",\"cwd\":\"$TMPDIR\"}' | $HOOKS/session-start.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null
  [[ "$output" == *"test-feature"* ]]
}

@test "session-start: no features outputs usage hint" {
  run bash -c "echo '{\"hook_event_name\":\"SessionStart\",\"cwd\":\"/tmp\"}' | $HOOKS/session-start.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No in-progress features"* ]] || [[ "$output" == *"start-spec"* ]]
}

@test "session-start: closed features not shown" {
  echo '{"slug":"test-feature","phase":"closed","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","history":[],"artifacts":{}}' > "$TMPDIR/features/test-feature/workflow.json"
  run bash -c "echo '{\"hook_event_name\":\"SessionStart\",\"cwd\":\"$TMPDIR\"}' | $HOOKS/session-start.sh"
  [ "$status" -eq 0 ]
  # Should not mention test-feature since it's closed
  [[ "$output" != *"test-feature: [closed]"* ]]
}

# ─── user-prompt-submit.sh ───

@test "user-prompt-submit: allows non-lean-spec prompt" {
  run bash -c "echo '{\"hook_event_name\":\"UserPromptSubmit\",\"cwd\":\"$TMPDIR\",\"prompt\":\"write me a function\"}' | $HOOKS/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
}

@test "user-prompt-submit: blocks submit-implementation when phase is not specifying" {
  # Set phase to implementing
  echo '{"slug":"test-feature","phase":"implementing","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","history":[],"artifacts":{}}' > "$TMPDIR/features/test-feature/workflow.json"
  run bash -c "echo '{\"hook_event_name\":\"UserPromptSubmit\",\"cwd\":\"$TMPDIR\",\"prompt\":\"/lean-spec:submit-implementation test-feature\"}' | $HOOKS/user-prompt-submit.sh"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.decision == "block"' > /dev/null
}

@test "user-prompt-submit: allows submit-implementation when phase is specifying" {
  run bash -c "echo '{\"hook_event_name\":\"UserPromptSubmit\",\"cwd\":\"$TMPDIR\",\"prompt\":\"/lean-spec:submit-implementation test-feature\"}' | $HOOKS/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
}

@test "user-prompt-submit: blocks submit-review when phase is not implementing" {
  # phase is specifying, not implementing
  run bash -c "echo '{\"hook_event_name\":\"UserPromptSubmit\",\"cwd\":\"$TMPDIR\",\"prompt\":\"/lean-spec:submit-review test-feature\"}' | $HOOKS/user-prompt-submit.sh"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.decision == "block"' > /dev/null
}

@test "user-prompt-submit: allows submit-review when phase is implementing" {
  echo '{"slug":"test-feature","phase":"implementing","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","history":[],"artifacts":{}}' > "$TMPDIR/features/test-feature/workflow.json"
  run bash -c "echo '{\"hook_event_name\":\"UserPromptSubmit\",\"cwd\":\"$TMPDIR\",\"prompt\":\"/lean-spec:submit-review test-feature\"}' | $HOOKS/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
}

@test "user-prompt-submit: blocks submit-fixes when phase is not reviewing" {
  run bash -c "echo '{\"hook_event_name\":\"UserPromptSubmit\",\"cwd\":\"$TMPDIR\",\"prompt\":\"/lean-spec:submit-fixes test-feature\"}' | $HOOKS/user-prompt-submit.sh"
  [ "$status" -eq 2 ]
}

@test "user-prompt-submit: blocks close-spec when phase is not reviewing" {
  run bash -c "echo '{\"hook_event_name\":\"UserPromptSubmit\",\"cwd\":\"$TMPDIR\",\"prompt\":\"/lean-spec:close-spec test-feature\"}' | $HOOKS/user-prompt-submit.sh"
  [ "$status" -eq 2 ]
}

@test "user-prompt-submit: blocks when feature not found" {
  run bash -c "echo '{\"hook_event_name\":\"UserPromptSubmit\",\"cwd\":\"$TMPDIR\",\"prompt\":\"/lean-spec:submit-implementation nonexistent-slug\"}' | $HOOKS/user-prompt-submit.sh"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.decision == "block"' > /dev/null
}

# ─── pre-tool-use-workflow.sh ───

@test "pre-tool-use: blocks Write on workflow.json" {
  INPUT="{\"hook_event_name\":\"PreToolUse\",\"cwd\":\"$TMPDIR\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"features/test-feature/workflow.json\"}}"
  run bash -c "echo '$INPUT' | $HOOKS/pre-tool-use-workflow.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' > /dev/null
}

@test "pre-tool-use: blocks Edit on workflow.json" {
  INPUT="{\"hook_event_name\":\"PreToolUse\",\"cwd\":\"$TMPDIR\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"features/test-feature/workflow.json\"}}"
  run bash -c "echo '$INPUT' | $HOOKS/pre-tool-use-workflow.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' > /dev/null
}

@test "pre-tool-use: allows Write on non-workflow.json files" {
  INPUT="{\"hook_event_name\":\"PreToolUse\",\"cwd\":\"$TMPDIR\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"features/test-feature/spec.md\"}}"
  run bash -c "echo '$INPUT' | $HOOKS/pre-tool-use-workflow.sh"
  [ "$status" -eq 0 ]
  # Output should be empty (allow, silent)
  [ -z "$output" ] || ! echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' > /dev/null
}

# ─── stop-guard.sh ───

@test "stop-guard: allows stop when no in-progress features" {
  # No features exist
  run bash -c "echo '{\"hook_event_name\":\"Stop\",\"cwd\":\"/tmp\"}' | $HOOKS/stop-guard.sh"
  [ "$status" -eq 0 ]
}

@test "stop-guard: blocks stop when implementing but notes.md missing" {
  echo '{"slug":"test-feature","phase":"implementing","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","history":[],"artifacts":{}}' > "$TMPDIR/features/test-feature/workflow.json"
  run bash -c "echo '{\"hook_event_name\":\"Stop\",\"cwd\":\"$TMPDIR\"}' | $HOOKS/stop-guard.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"' > /dev/null
}

@test "stop-guard: allows stop when notes.md exists" {
  echo '{"slug":"test-feature","phase":"implementing","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","history":[],"artifacts":{}}' > "$TMPDIR/features/test-feature/workflow.json"
  touch "$TMPDIR/features/test-feature/notes.md"
  run bash -c "echo '{\"hook_event_name\":\"Stop\",\"cwd\":\"$TMPDIR\"}' | $HOOKS/stop-guard.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ] || ! echo "$output" | jq -e '.decision == "block"' > /dev/null
}

@test "stop-guard: blocks stop when reviewing but review.md missing" {
  echo '{"slug":"test-feature","phase":"reviewing","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","history":[],"artifacts":{}}' > "$TMPDIR/features/test-feature/workflow.json"
  run bash -c "echo '{\"hook_event_name\":\"Stop\",\"cwd\":\"$TMPDIR\"}' | $HOOKS/stop-guard.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"' > /dev/null
}

# ─── subagent-stop-guard.sh ───

@test "subagent-stop-guard: blocks architect when spec.md missing" {
  # phase is specifying (default setup), spec.md does not exist
  run bash -c "echo '{\"hook_event_name\":\"SubagentStop\",\"cwd\":\"$TMPDIR\",\"agent_type\":\"architect\"}' | $HOOKS/subagent-stop-guard.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"' > /dev/null
  [[ "$output" == *"spec.md"* ]]
}

@test "subagent-stop-guard: allows architect when spec.md present" {
  touch "$TMPDIR/features/test-feature/spec.md"
  run bash -c "echo '{\"hook_event_name\":\"SubagentStop\",\"cwd\":\"$TMPDIR\",\"agent_type\":\"architect\"}' | $HOOKS/subagent-stop-guard.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ] || ! echo "$output" | jq -e '.decision == "block"' > /dev/null
}

@test "subagent-stop-guard: architect skipped when feature not in specifying phase" {
  # Move to implementing; architect dispatch would be out of phase, but the hook's phase filter means no block even if spec.md missing
  echo '{"slug":"test-feature","phase":"implementing","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","history":[],"artifacts":{}}' > "$TMPDIR/features/test-feature/workflow.json"
  run bash -c "echo '{\"hook_event_name\":\"SubagentStop\",\"cwd\":\"$TMPDIR\",\"agent_type\":\"architect\"}' | $HOOKS/subagent-stop-guard.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ] || ! echo "$output" | jq -e '.decision == "block"' > /dev/null
}

@test "subagent-stop-guard: blocks coder when notes.md missing" {
  echo '{"slug":"test-feature","phase":"implementing","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","history":[],"artifacts":{}}' > "$TMPDIR/features/test-feature/workflow.json"
  run bash -c "echo '{\"hook_event_name\":\"SubagentStop\",\"cwd\":\"$TMPDIR\",\"agent_type\":\"coder\"}' | $HOOKS/subagent-stop-guard.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"' > /dev/null
}

@test "subagent-stop-guard: allows coder when notes.md present" {
  echo '{"slug":"test-feature","phase":"implementing","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","history":[],"artifacts":{}}' > "$TMPDIR/features/test-feature/workflow.json"
  touch "$TMPDIR/features/test-feature/notes.md"
  run bash -c "echo '{\"hook_event_name\":\"SubagentStop\",\"cwd\":\"$TMPDIR\",\"agent_type\":\"coder\"}' | $HOOKS/subagent-stop-guard.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ] || ! echo "$output" | jq -e '.decision == "block"' > /dev/null
}

@test "subagent-stop-guard: blocks reviewer when review.md missing" {
  echo '{"slug":"test-feature","phase":"reviewing","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","history":[],"artifacts":{}}' > "$TMPDIR/features/test-feature/workflow.json"
  run bash -c "echo '{\"hook_event_name\":\"SubagentStop\",\"cwd\":\"$TMPDIR\",\"agent_type\":\"reviewer\"}' | $HOOKS/subagent-stop-guard.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"' > /dev/null
}

@test "subagent-stop-guard: allows non-lean-spec agent type" {
  run bash -c "echo '{\"hook_event_name\":\"SubagentStop\",\"cwd\":\"$TMPDIR\",\"agent_type\":\"some-other-agent\"}' | $HOOKS/subagent-stop-guard.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ─── pre-compact.sh ───

@test "pre-compact: outputs additionalContext" {
  run bash -c "echo '{\"hook_event_name\":\"PreCompact\",\"cwd\":\"$TMPDIR\"}' | $HOOKS/pre-compact.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null
}
