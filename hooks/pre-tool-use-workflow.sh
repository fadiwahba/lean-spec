#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Extract file path from tool input (Write uses file_path, Edit uses file_path)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Normalize to absolute path for matching
if [[ "$FILE_PATH" != /* ]]; then
  FILE_PATH="$CWD/$FILE_PATH"
fi

# Block if the file is a workflow.json inside features/
if [[ "$FILE_PATH" =~ /features/[^/]+/workflow\.json$ ]]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Direct edits to workflow.json are blocked. Use /lean-spec:* commands to advance the lifecycle. If the state is wedged, edit the file manually via your terminal (not through Claude)."
    }
  }'
  exit 0
fi

exit 0
