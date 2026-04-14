# Lean-Spec Instructions

This project uses `lean-spec` for feature delivery in Gemini CLI.

## Workflow Model

This is a Gemini-native, human-controlled workflow.

Gemini CLI does not provide a Claude-style named subagent system in this workflow.
`Architect` and `Coder` are operating roles tied to the session and model you launch.

Roles:
- default Gemini session: orchestrator
- Architect role: planning / architecture / review
- Coder role: implementation / fixes

Recommended session split:
- run planning, review, status, resume, and end in a Pro session:
  - `gemini -m gemini-3-pro-preview`
- run implementation in a Flash session:
  - `gemini -m gemini-3-flash-preview`

Session discipline:
- `/lean-spec:start-spec`, `/lean-spec:review-spec`, and `/lean-spec:close-spec` should run only in the Pro session
- `/lean-spec:implement-spec` should run only in the Flash session
- `/lean-spec:spec-status` and `/lean-spec:resume-spec` prefer Pro, but may be used operationally in another session if they remain read-only
- if the human runs a phase in the wrong session, do not improvise around it; tell the human to switch sessions and rerun the command

The human advances phases explicitly with:
- `/lean-spec:start-spec <slug>`
- `/lean-spec:implement-spec <slug>`
- `/lean-spec:review-spec <slug>`
- `/lean-spec:spec-status <slug>`
- `/lean-spec:resume-spec <slug>`
- `/lean-spec:close-spec <slug>`

There are no automatic gates or automatic phase transitions.

## Source of Truth

For each feature, the canonical artifacts live in:

- `lean-spec/features/<slug>/spec.md`
- `lean-spec/features/<slug>/notes.md`
- `lean-spec/features/<slug>/review.md`
- `lean-spec/features/<slug>/artifacts/`

Template sources live in:

- `.gemini/lean-spec/templates/spec.md`
- `.gemini/lean-spec/templates/notes.md`
- `.gemini/lean-spec/templates/review.md`

## Orchestrator Rules

The default Gemini session owns:
- workflow control
- file scaffolding
- command routing
- concise progress reporting

The default Gemini session does not own the substantive contents of:
- `spec.md`
- `notes.md`
- `review.md`

There is no separate active-state file in this workflow.
Current workflow state must be derived from:
- `spec.md`
- `notes.md`
- `review.md`

The orchestrator must:
- accept slash command inputs from the human
- resolve the target feature folder from the slug
- scaffold or locate workflow files
- enforce the intended session role for the current phase
- route planning and review work to the Architect role
- route implementation and review-fix work to the Coder role
- collect completion status from the current session role
- stop at the end of each phase and wait for the next human command

The orchestrator must not:
- auto-advance to the next phase
- author the real implementation plan in `spec.md`
- do the primary implementation work when the human intended a Flash Coder session
- do the primary formal review when the human intended a Pro Architect session
- bypass role boundaries during `/lean-spec:implement-spec`, even for "small", "trivial", or one-line fixes
- present ad hoc workaround options inside a phase when required verification is incomplete; report the incomplete verification and stop

## Strict Ownership

Architect role owns:
- `spec.md`
- `review.md`

Coder role owns:
- `notes.md`
- code implementation work

## Command Semantics

### `/lean-spec:start-spec <slug>`

Use when:
- starting a new feature
- revisiting planning for an existing feature

Expected outcome:
- feature folder exists
- scaffold files are copied from `.gemini/lean-spec/templates/`
- `spec.md` is created or updated by the Architect role
- `notes.md` and `review.md` exist
- the phase stops and waits for the human

### `/lean-spec:implement-spec <slug>`

Use when:
- the spec is approved
- review findings need fixes

Expected outcome:
- the Coder role implements from `spec.md`
- `notes.md` captures blockers, deviations, and partial completion notes
- the phase stops and waits for the human

### `/lean-spec:review-spec <slug>`

Use when:
- implementation is ready for review
- you want a fresh review pass after fixes

Expected outcome:
- the Architect role reviews against `spec.md`, `notes.md`, and code changes
- `review.md` is updated with findings and dispositions
- `spec.md` is reconciled during review so checklist progress and status stay aligned with the reviewed implementation
- the phase stops and waits for the human

### `/lean-spec:close-spec <slug>`

Use when:
- review is clean or all findings are dispositioned
- you want the workflow to perform final reconciliation and close cleanly

Expected outcome:
- `spec.md`, `notes.md`, and `review.md` are reconciled with the final clean state
- `spec.md` status is `completed`
- task checklist items in `spec.md` are marked complete
- timestamps are refreshed from a shell-backed runtime source
- clear signal about whether closure actually completed or was blocked

## Core Rules

- `spec.md` is authored only by the Architect role
- `notes.md` is authored only by the Coder role
- `review.md` is authored only by the Architect role
- the Coder role must not silently change scope
- the Coder role must not edit `spec.md` status, checklist items, or `review.md`
- the Architect role must not implement code in this workflow
- the default Gemini session must stop after each phase until the human runs the next command
- `/close-spec` is the explicit final reconciliation phase and should clean up artifact state when closure is valid
- review passes should progressively reconcile `spec.md`; `/close-spec` should finalize closure, not perform the first meaningful checklist reconciliation
- a feature must not close with open notes, open findings, stale `spec.md` status, or unchecked completed tasks

## Timestamp Discipline

When creating a lean-spec artifact:
- set `Created At` and `Updated At` to the current timestamp

When editing an existing lean-spec artifact:
- update `Updated At`
- do not change `Created At`

Applies to:
- `spec.md`
- `notes.md`
- `review.md`

Timestamp rules:
- retrieve timestamps from the environment at write time; do not invent, estimate, or hardcode them
- use a shell command such as `date "+%Y-%m-%d %H:%M %Z"` or an equivalent environment-backed source
- for scaffold creation, fetch the timestamp once from the shell and reuse that exact value for every created field in that scaffold pass
- placeholder values such as `YYYY-MM-DD HH:MM TZ` and fabricated values such as `00:00 UTC` are invalid
- use the timestamp format `YYYY-MM-DD HH:MM TZ`

## Tooling Discipline

Use `context7` before implementation or review when external APIs, libraries, frameworks, or tool behavior matter.

Use `sequential_thinking` before multi-step or risky planning, implementation, or review work when the task is ambiguous or materially risky.

For frontend/UI work:
- use `playwright` or equivalent browser validation before declaring implementation or review complete, unless it is explicitly unavailable
- treat visible regressions, broken layout, or spec mismatch as real review issues

Playwright hygiene:
- when browser validation is used, close any opened browser, context, or page before ending the phase
- do not leave long-lived Playwright sessions running across lean-spec phases unless the human explicitly asks
- if Playwright fails due to connection or stale-session errors, report it explicitly as unavailable for that phase
- do not save Playwright screenshots or captures into the project root
- if screenshots or captures are needed, store them only under `lean-spec/features/<slug>/artifacts/`
- do not create sibling screenshot folders or save screenshots directly under the feature root

Dev server hygiene:
- when a phase starts a local dev server or opens a validation port, stop it before ending the phase
- do not leave long-lived local servers running across lean-spec phases unless the human explicitly asks
- if port cleanup is needed, use a project-approved command such as `npx kill-port 3000`

Required completion discipline:
- do not report implementation or review complete when `context7` was required but not used, unless it was explicitly unavailable
- do not report implementation or review complete when `sequential_thinking` was required but not used, unless it was explicitly unavailable
- do not report implementation complete for frontend/UI work when `playwright` validation was required but not used, unless it was explicitly unavailable
- every implementation or review summary should state whether `context7`, `sequential_thinking`, and `playwright` were used when relevant
- if a required tool was unavailable, say so explicitly and treat that as an incomplete verification step

Required artifact discipline:
- during `/lean-spec:implement-spec`, the Coder role may update `notes.md` and implementation code only
- during `/lean-spec:implement-spec`, do not edit `spec.md` or `review.md`
- during `/lean-spec:implement-spec`, do not update `spec.md` status, task checklists, or timestamps
- only the Architect role may reconcile `spec.md` status, checklists, and closure state during review or end
- the default Gemini session must not edit implementation files directly during `/lean-spec:implement-spec`, even for one-line fixes
- create `lean-spec/features/<slug>/artifacts/` during scaffold and reuse it for any screenshots, images, audio, PDFs, or other lean-spec evidence files

## Hook Guidance

Hooks are appropriate for reducing orchestration drift in this workflow.

Use:
- `BeforeAgent` to remind the default Gemini session of the manual workflow before it plans a turn
- `BeforeTool` to reinforce delegation and artifact ownership before tool execution
- optional `AfterAgent` to validate final responses and request a correction when the session claims completion incorrectly

Do not use hooks to create or maintain a second workflow state file.
Hook logic must derive lean-spec state from the canonical feature artifacts.

Hook expectations:
- hooks should remind and enforce workflow discipline
- hooks should not pretend to switch models or fabricate role state
- if a hook cannot prove the current session is correct, it should bias toward a reminder, not invented certainty
