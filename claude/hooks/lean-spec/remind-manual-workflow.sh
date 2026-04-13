#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"

PROMPT_TEXT="$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)

for key in ("prompt", "text", "message"):
    value = data.get(key)
    if isinstance(value, str):
        print(value)
        break
else:
    print("")
')"

PROMPT_LOWER="$(printf '%s' "$PROMPT_TEXT" | tr '[:upper:]' '[:lower:]')"
COMMAND_HINT=""

case "$PROMPT_LOWER" in
  *"/plan "*|"/plan")
    COMMAND_HINT="This is the planning phase: scaffold or locate the feature folder, delegate spec authoring to architect, and stop when spec.md is ready."
    ;;
  *"/implement "*|"/implement")
    COMMAND_HINT="This is the implementation phase: delegate code work and notes.md updates to coder, then stop after the implementation pass."
    ;;
  *"/review "*|"/review")
    COMMAND_HINT="This is the review phase: delegate review.md authoring to architect, then stop after the review pass."
    ;;
  *"/status "*|"/status")
    COMMAND_HINT="This is a status check: read only spec.md, notes.md, and review.md, then report the current manual workflow state."
    ;;
  *"/resume "*|"/resume")
    COMMAND_HINT="This is a resume request: rebuild state from spec.md, review.md, and notes.md, then either stop with the report or proceed only if the human explicitly asked."
    ;;
  *"/end "*|"/end")
    COMMAND_HINT="This is the end phase: summarize the artifact state and stop. Do not invent completion or approval."
    ;;
esac

/usr/bin/python3 - "$COMMAND_HINT" <<'PY'
import json, sys

command_hint = sys.argv[1]

base = (
    "Lean-spec manual workflow is active. The default session agent is the orchestrator only: "
    "it owns scaffolding, command routing, and concise status reporting. "
    "Do not auto-advance phases. "
    "Delegate planning and review to architect. "
    "Delegate implementation and notes.md ownership to coder. "
    "architect owns spec.md and review.md. "
    "coder owns notes.md and implementation work. "
    "Workflow state is derived only from spec.md, notes.md, and review.md; there is no separate active-state file. "
    "Tooling discipline: use Context7 before implementation or review when external APIs, libraries, frameworks, or tool behavior matter. "
    "Use sequential-thinking before multi-step or risky planning, implementation, or review work when the task is ambiguous. "
    "For frontend and UI work, use Playwright or equivalent browser validation when available and treat visible regressions, broken layout, or spec mismatch as real review issues."
)

message = base if not command_hint else f"{base} {command_hint}"

print(json.dumps({
    "continue": True,
    "suppressOutput": False,
    "systemMessage": message
}))
PY
