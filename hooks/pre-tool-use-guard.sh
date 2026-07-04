#!/usr/bin/env bash
# PreToolUse hook: blocks direct hand-edits of features/*/workflow.json.
# workflow.json is mutated exclusively by bin/lean-spec (see CONSTITUTION
# principle 2). Reads the hook JSON payload from stdin, checks tool_name +
# file_path (or MultiEdit's file_path), and emits a permissionDecision deny
# when the target matches. Any other input: allow silently (exit 0, no
# output) so the hook stays invisible on the happy path.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

payload="$(cat)"

# NOTE: pass payload on stdin, not argv — a Write/Edit tool_input.content
# can be arbitrarily large, and Linux caps a single argv string at roughly
# 128KB (MAX_ARG_STRLEN). A large payload passed as an argument makes
# python3 abort with Argument list too long, which under set -euo pipefail
# kills this hook (no JSON output, fails OPEN). Stdin has no such limit.
decision="$(printf '%s' "$payload" | python3 -c '
import json
import re
import sys

try:
    data = json.loads(sys.stdin.read())
except (json.JSONDecodeError, ValueError):
    print("allow")
    sys.exit(0)

tool_name = data.get("tool_name", "")
tool_input = data.get("tool_input", {}) or {}

guarded_tools = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
if tool_name not in guarded_tools:
    print("allow")
    sys.exit(0)

file_path = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
pattern = re.compile(r"(^|/)features/[^/]+/workflow\.json$")
if pattern.search(file_path):
    print("deny")
else:
    print("allow")
')"

if [ "$decision" = "deny" ]; then
  cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "workflow.json is mutated only by bin/lean-spec (ensure/advance) — never hand-edited. Use \`${PLUGIN_ROOT}/bin/lean-spec advance <slug> <from> <to>\` instead."
  }
}
JSON
  exit 0
fi

exit 0
