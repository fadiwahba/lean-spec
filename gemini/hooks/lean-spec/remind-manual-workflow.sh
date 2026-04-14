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
print(data.get("prompt", ""))
')"

PROMPT_LOWER="$(printf '%s' "$PROMPT_TEXT" | tr '[:upper:]' '[:lower:]')"
COMMAND_HINT=""

case "$PROMPT_LOWER" in
  *"/lean-spec:plan "*|*"/plan "*|"/lean-spec:plan"|"/plan")
    COMMAND_HINT="This is the planning phase. It must run in the Gemini Pro session. If you are not in the intended Pro session, stop and tell the human to rerun it there. Use the Architect role, scaffold from .gemini/lean-spec/templates/, and stop when spec.md is ready."
    ;;
  *"/lean-spec:implement "*|*"/implement "*|"/lean-spec:implement"|"/implement")
    COMMAND_HINT="This is the implementation phase. It must run in the Gemini Flash session. If you are not in the intended Flash session, stop and tell the human to rerun it there. Use the Coder role, update notes.md as needed, never edit spec.md or review.md in this phase, never update spec.md status, checklist items, or timestamps in this phase, use context7 before implementation when library or framework behavior matters, use sequential_thinking before multi-step or risky work, use playwright for frontend/UI validation before reporting implementation complete unless it is unavailable, close any opened Playwright browser, context, or page before ending the phase, never save Playwright screenshots into the project root, and stop any local dev server or validation port you started before ending the phase."
    ;;
  *"/lean-spec:review "*|*"/review "*|"/lean-spec:review"|"/review")
    COMMAND_HINT="This is the review phase. It must run in the Gemini Pro session. If you are not in the intended Pro session, stop and tell the human to rerun it there. Use the Architect role, update review.md, reconcile spec.md, use context7 when library or framework behavior matters, use sequential_thinking for multi-step or risky review work, use playwright for frontend/UI review before reporting the review complete unless it is unavailable, close any opened Playwright browser, context, or page before ending the phase, never save Playwright screenshots into the project root, and stop any local dev server or validation port you started before ending the phase."
    ;;
  *"/lean-spec:status "*|*"/status "*|"/lean-spec:status"|"/status")
    COMMAND_HINT="This is a status check. Prefer the Gemini Pro session. Read only spec.md, notes.md, and review.md and report the current manual workflow state."
    ;;
  *"/lean-spec:resume "*|*"/resume "*|"/lean-spec:resume"|"/resume")
    COMMAND_HINT="This is a resume request. Prefer the Gemini Pro session. Rebuild state from spec.md, review.md, and notes.md, then either stop with the report or proceed only if the human explicitly asked."
    ;;
  *"/lean-spec:end "*|*"/end "*|"/lean-spec:end"|"/end")
    COMMAND_HINT="This is the end phase. It must run in the Gemini Pro session. If you are not in the intended Pro session, stop and tell the human to rerun it there. Only finalize closure when review is clean or all findings are dispositioned. Reconcile spec.md and refresh timestamps from the shell."
    ;;
esac

/usr/bin/python3 - "$COMMAND_HINT" <<'PY'
import json, sys
command_hint = sys.argv[1]
base = (
    "Lean-spec manual workflow is active for Gemini CLI. "
    "The default Gemini session is the orchestrator only: it owns scaffolding, command routing, and concise status reporting. "
    "Do not auto-advance phases. "
    "Use Gemini Pro for the Architect role in planning, review, status, resume, and end. "
    "Use Gemini Flash for the Coder role in implementation. "
    "Gemini does not provide native lean-spec subagents here; Architect and Coder are session roles. "
    "Architect owns spec.md and review.md. "
    "Coder owns notes.md and implementation work. "
    "Coder must not edit spec.md or review.md during implement. "
    "Coder must not update spec.md status, checklist items, or timestamps during implement. "
    "Workflow state is derived only from spec.md, notes.md, and review.md; there is no separate active-state file. "
    "Use shell-backed timestamps such as date \"+%Y-%m-%d %H:%M %Z\". "
    "Use context7 before implementation or review when external library or framework behavior matters. "
    "Use sequential_thinking before multi-step or risky work when ambiguity or material risk exists. "
    "Use playwright for frontend or UI validation before claiming implementation or review completion unless it is unavailable. "
    "When Playwright is used, close any opened browser, context, or page before ending the phase. "
    "Do not save Playwright screenshots or captures into the project root; use a dedicated artifact folder when captures are needed. "
    "When a phase starts a local dev server or opens a validation port, stop it before ending the phase. "
    "Use a project-approved cleanup command such as `npx kill-port 3000` when port cleanup is needed. "
    "Do not claim implementation or review complete unless the required tool usage is satisfied or explicit unavailability is reported. "
    "Review passes must reconcile spec.md progressively. "
    "End should only finalize closure, not backfill the entire checklist for the first time."
)
message = base if not command_hint else f"{base} {command_hint}"
print(json.dumps({
    "decision": "allow",
    "continue": True,
    "systemMessage": "lean-spec reminder loaded",
    "hookSpecificOutput": {
        "additionalContext": message
    }
}))
PY
