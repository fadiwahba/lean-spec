#!/usr/bin/env bash
# PreToolUse hook: blocks direct hand-edits of the two state files that have a
# designated CLI writer (CONSTITUTION principle 2):
#   * .lean-spec/features/*/workflow.json -> written only by `bin/lean-spec advance/ensure`
#   * .lean-spec/auto.json      -> written only by `bin/lean-spec auto arm/disarm`
#   * .lean-spec/dispatch.json  -> written only by `bin/lean-spec dispatch`
# Reads the hook JSON payload from stdin, checks tool_name + file_path (or
# MultiEdit's file_path), and emits a permissionDecision deny when the target
# matches. Any other input: allow silently (exit 0, no output) so the hook
# stays invisible on the happy path.
#
# The auto.json case (issue #21) matters most: once that file exists, the Stop
# hook drives phases whose skills are all `disable-model-invocation: true`, so
# writing it by hand is equivalent to self-granting the authorization that gate
# exists to withhold. Denying the write removes the discretion instead of
# policing it with prose the model reads in the same channel it must obey.
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

# Normalize `.`/`..` segments so a traversal that resolves back into
# .lean-spec/features/<slug>/workflow.json is still caught, and match case-insensitively
# so the plugin dev platform (case-preserving APFS) cannot dodge the guard
# with Workflow.json / WORKFLOW.JSON landing on the same on-disk file.
workflow = re.compile(r"(^|/)\.lean-spec/features/[^/]+/workflow\.json$", re.IGNORECASE)
auto = re.compile(r"(^|/)\.lean-spec/auto\.json$", re.IGNORECASE)
dispatch = re.compile(r"(^|/)\.lean-spec/dispatch\.json$", re.IGNORECASE)

if tool_name == "apply_patch":
    # Codex sends the full patch in `command`. Keep `patch` as a
    # compatibility fallback for hosts that use the older shape.
    patch = tool_input.get("command") or tool_input.get("patch", "")
    if not isinstance(patch, str):
        print("allow")
        sys.exit(0)
    paths = re.findall(r"^\*\*\* (?:Add|Delete|Update) File: (.+)$", patch, re.MULTILINE)
elif tool_name in {"Write", "Edit", "MultiEdit", "NotebookEdit"}:
    file_path = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
    paths = [file_path] if isinstance(file_path, str) else []
elif tool_name == "Bash":
    command = tool_input.get("command", "")
    if not isinstance(command, str):
        print("allow")
        sys.exit(0)
    # Shell syntax and embedded interpreters cannot be parsed safely enough
    # to distinguish every direct write. The designated CLI never needs a
    # state-file path, so deny any command that refers to one.
    command = command.replace(chr(39), " ")
    shell_workflow = re.compile(r"(^|[\s\"/])\.lean-spec/features/[^\s\"/]+/workflow\.json(?=$|[\s\";|&])", re.IGNORECASE)
    shell_auto = re.compile(r"(^|[\s\"/])\.lean-spec/auto\.json(?=$|[\s\";|&])", re.IGNORECASE)
    shell_dispatch = re.compile(r"(^|[\s\"/])\.lean-spec/dispatch\.json(?=$|[\s\";|&])", re.IGNORECASE)
    if shell_workflow.search(command):
        print("deny:workflow")
        sys.exit(0)
    if shell_auto.search(command):
        print("deny:auto")
        sys.exit(0)
    if shell_dispatch.search(command):
        print("deny:dispatch")
        sys.exit(0)
    paths = []
else:
    print("allow")
    sys.exit(0)

for file_path in paths:
    normalized = os.path.normpath(file_path)
    if workflow.search(normalized):
        print("deny:workflow")
        sys.exit(0)
    if auto.search(normalized):
        print("deny:auto")
        sys.exit(0)
    if dispatch.search(normalized):
        print("deny:dispatch")
        sys.exit(0)
print("allow")
')"

# Build the decision with json.dumps, NEVER string interpolation into a JSON
# heredoc: the reason embeds CLAUDE_PLUGIN_ROOT, and a path containing a
# double-quote, backslash or newline would emit malformed JSON. Claude Code
# could not then parse the decision, so the deny would be lost and the guard
# would FAIL OPEN — the exact failure class this hook exists to prevent.
emit_deny() {
  python3 -c '
import json, sys
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": sys.argv[1],
    }
}, ensure_ascii=False, indent=2))
' "$1"
  exit 0
}

if [ "$decision" = "deny:workflow" ]; then
  emit_deny "workflow.json is mutated only by bin/lean-spec (ensure/advance) — never hand-edited. Use \`${PLUGIN_ROOT}/bin/lean-spec advance <slug> <from> <to>\` instead."
fi

if [ "$decision" = "deny:auto" ]; then
  emit_deny ".lean-spec/auto.json is owned by the auto-driver — never hand-written. Use \`${PLUGIN_ROOT}/bin/lean-spec auto arm <slug> [--chain-all] [--no-confirm]\` (or \`auto disarm\`), or ask the user to run /lean-spec:auto (one feature) or /lean-spec:auto-all (every non-closed feature). Arming a run the user did not ask for is not yours to decide."
fi

if [ "$decision" = "deny:dispatch" ]; then
  emit_deny ".lean-spec/dispatch.json is owned by the dispatch bridge — never hand-written. Let the active host adapter bind the explicit work identity through \`bin/lean-spec dispatch\`."
fi

exit 0
