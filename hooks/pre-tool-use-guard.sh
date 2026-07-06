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
import os
import re
import sys

# Any input we cannot positively identify as a guarded write is allowed
# (this hook only ever DENIES the one narrow case). Valid-but-non-object
# JSON (a bare array/scalar) must reach this same allow path, not crash
# under set -euo pipefail with no decision emitted (that would fail OPEN).
try:
    data = json.loads(sys.stdin.read())
except (json.JSONDecodeError, ValueError):
    print("allow")
    sys.exit(0)
if not isinstance(data, dict):
    print("allow")
    sys.exit(0)

tool_name = data.get("tool_name", "")
tool_input = data.get("tool_input")
if not isinstance(tool_input, dict):
    print("allow")
    sys.exit(0)

guarded_tools = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
if tool_name not in guarded_tools:
    print("allow")
    sys.exit(0)

file_path = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
if not isinstance(file_path, str):
    print("allow")
    sys.exit(0)

# Normalize `.`/`..` segments so a traversal that resolves back into
# features/<slug>/workflow.json is still caught, and match case-insensitively
# so the plugin dev platform (case-preserving APFS) cannot dodge the guard
# with Workflow.json / WORKFLOW.JSON landing on the same on-disk file.
normalized = os.path.normpath(file_path)
pattern = re.compile(r"(^|/)features/[^/]+/workflow\.json$", re.IGNORECASE)
if pattern.search(normalized):
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
