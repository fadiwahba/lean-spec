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
  *"/lean-spec:start-spec "*|"/lean-spec:start-spec")
    COMMAND_HINT="This is the planning phase: scaffold or locate the feature folder, delegate spec authoring to architect, and stop when spec.md is ready."
    ;;
  *"/lean-spec:implement-spec "*|"/lean-spec:implement-spec")
    COMMAND_HINT="This is the implementation phase: delegate code work and notes.md updates to coder, never edit spec.md or review.md in this phase, never update spec.md status, checklist items, or timestamps in this phase, never bypass delegation for small or one-line fixes, use Context7 before implementation when library or framework behavior matters, use sequential-thinking before multi-step or risky work, use Playwright for frontend/UI validation before reporting implementation complete unless it is unavailable, close any opened Playwright browser, context, or page before ending the phase, never save Playwright screenshots into the project root, and if required verification is incomplete, report that and stop instead of offering ad hoc workaround choices."
    ;;
  *"/lean-spec:review-spec "*|"/lean-spec:review-spec")
    COMMAND_HINT="This is the review phase: delegate review.md authoring to architect, reconcile spec.md during review, use Context7 when library or framework behavior matters, use sequential-thinking for multi-step or risky review work, use Playwright for frontend/UI review before reporting the review complete unless it is unavailable, close any opened Playwright browser, context, or page before ending the phase, and never save Playwright screenshots into the project root."
    ;;
  *"/lean-spec:spec-status "*|"/lean-spec:spec-status")
    COMMAND_HINT="This is a status check: read only spec.md, notes.md, and review.md, then report the current manual workflow state."
    ;;
  *"/lean-spec:resume-spec "*|"/lean-spec:resume-spec")
    COMMAND_HINT="This is a resume request: rebuild state from spec.md, review.md, and notes.md, then either stop with the report or proceed only if the human explicitly asked."
    ;;
  *"/lean-spec:close-spec "*|"/lean-spec:close-spec")
    COMMAND_HINT="This is the end phase: summarize the artifact state and stop. Do not invent completion or approval. Close only when spec.md, notes.md, and review.md support it."
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
    "coder must not edit spec.md or review.md during implement. "
    "coder must not update spec.md status, checklist items, or timestamps during implement. "
    "The orchestrator must not bypass delegation during implement-spec, even for small or one-line fixes. "
    "Workflow state is derived only from spec.md, notes.md, and review.md; there is no separate active-state file. "
    "Tooling discipline: use Context7 before implementation or review when external APIs, libraries, frameworks, or tool behavior matter. "
    "Use sequential-thinking before multi-step or risky planning, implementation, or review work when the task is ambiguous or materially risky. "
    "For frontend and UI work, use Playwright or equivalent browser validation before claiming implementation or review completion unless it is unavailable. "
    "When Playwright is used, close any opened browser, context, or page before ending the phase. "
    "Do not save Playwright screenshots or captures into the project root; use a dedicated artifact folder when captures are needed. "
    "If required verification is incomplete, report it and stop instead of offering ad hoc workaround choices inside the phase. "
    "When a phase starts a local dev server or opens a validation port, stop it before ending the phase. "
    "Use a project-approved cleanup command such as `npx kill-port 3000` when port cleanup is needed. "
    "Do not claim implementation or review complete unless the required tool usage is satisfied or explicit unavailability is reported."
)

message = base if not command_hint else f"{base} {command_hint}"

print(json.dumps({
    "continue": True,
    "suppressOutput": False,
    "systemMessage": message
}))
PY
