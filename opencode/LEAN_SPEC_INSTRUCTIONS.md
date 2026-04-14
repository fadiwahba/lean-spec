# Lean-Spec OpenCode Instructions

This project uses `lean-spec` in OpenCode.

## Workflow Model

This is a human-controlled, manual workflow.

Roles:
- default OpenCode session: orchestrator
- `lean-spec-architect`: planner / architect / reviewer
- `lean-spec-coder`: implementer / coder

The human advances phases explicitly with:
- `/lean-spec:plan <slug>`
- `/lean-spec:implement <slug>`
- `/lean-spec:review <slug>`
- `/lean-spec:status <slug>`
- `/lean-spec:resume <slug>`
- `/lean-spec:end <slug>`

There are no automatic gates or automatic phase transitions.

## Source of Truth

Canonical feature artifacts live in:
- `lean-spec/features/<slug>/spec.md`
- `lean-spec/features/<slug>/notes.md`
- `lean-spec/features/<slug>/review.md`

Template sources live in:
- `.opencode/lean-spec/templates/spec.md`
- `.opencode/lean-spec/templates/notes.md`
- `.opencode/lean-spec/templates/review.md`

There is no separate active-state file.
State must be inferred from those artifacts.

## Role Modes

You may run lean-spec in two ways:

1. mixed mode
- Claude Code is the Architect
- OpenCode is the Coder

2. full OpenCode mode
- `lean-spec-architect` is the Architect
- `lean-spec-coder` is the Coder

In both modes, ownership rules stay the same.

## Strict Ownership

Architect owns:
- `spec.md`
- `review.md`

Coder owns:
- `notes.md`
- implementation work

The orchestrator owns:
- command routing
- file scaffolding
- concise phase reporting

The orchestrator must not:
- auto-advance to the next phase
- take over substantive ownership of `spec.md`, `notes.md`, or `review.md`

## Command Semantics

### `/lean-spec:plan <slug>`

Use when:
- starting a new feature
- revisiting planning for an existing feature

Expected outcome:
- feature folder exists
- scaffold files are copied from `.opencode/lean-spec/templates/`
- `spec.md` is created or updated by the Architect
- `notes.md` and `review.md` exist
- the phase stops and waits for the human

### `/lean-spec:implement <slug>`

Use when:
- the spec is approved
- review findings need fixes

Expected outcome:
- the Coder implements from `spec.md`
- `notes.md` captures blockers, deviations, and partial completion notes
- the phase stops and waits for the human

### `/lean-spec:review <slug>`

Use when:
- implementation is ready for review
- you want a fresh review pass after fixes

Expected outcome:
- the Architect reviews against `spec.md`, `notes.md`, and code changes
- `review.md` is updated with findings and dispositions
- `spec.md` is reconciled during review so checklist progress and status stay aligned with the reviewed implementation
- the phase stops and waits for the human

### `/lean-spec:end <slug>`

Use when:
- review is clean or all findings are dispositioned
- you want final reconciliation and clean closure

Expected outcome:
- `spec.md`, `notes.md`, and `review.md` are reconciled with the final clean state
- `spec.md` status is `completed`
- task checklist items in `spec.md` are marked complete
- timestamps are refreshed from a shell-backed runtime source
- clear signal about whether closure actually completed or was blocked

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
- use a shell command such as `date "+%Y-%m-%d %H:%M %Z"`
- for scaffold creation, fetch the timestamp once and reuse that exact value for every created field in that scaffold pass
- placeholder values such as `YYYY-MM-DD HH:MM TZ` and fabricated values are invalid

## Mixed Mode Guidance

If you are running mixed mode:
- OpenCode should be used for:
  - `/lean-spec:implement <slug>`
  - `/lean-spec:status <slug>`
  - `/lean-spec:resume <slug>`
- planning, review, and end stay in Claude Code

If the human asks OpenCode to run Architect phases in mixed mode, stop and direct them to Claude Code.

## Full OpenCode Guidance

If you are running full OpenCode mode:
- assign one model to `lean-spec-architect`
- assign another model to `lean-spec-coder`
- keep the same ownership and manual phase rules
- do not let either agent silently take over the other agent's artifact ownership

## Tooling Discipline

- Read only the minimum relevant files before acting.
- Use `context7` before implementation or review when external libraries, frameworks, or tool behavior matter.
- Use `sequential_thinking` before planning, implementation, or review work when the task is multi-step, ambiguous, or materially risky.
- For frontend/UI work, use `playwright` before declaring implementation or review complete, unless it is explicitly unavailable.
- Do not perform destructive shell actions unless the human explicitly asked.

Playwright hygiene:
- when browser validation is used, close any opened browser, context, or page before ending the phase
- do not leave long-lived Playwright sessions running across lean-spec phases unless the human explicitly asks
- if `playwright` fails due to connection or stale-session errors, report it explicitly as unavailable for that phase
- do not save Playwright screenshots or captures into the project root
- if screenshots or captures are needed, store them in a dedicated artifact folder such as `lean-spec/artifacts/playwright/` or another project-approved artifact path

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
- during `/lean-spec:implement`, the Coder may update `notes.md` and implementation code only
- during `/lean-spec:implement`, do not edit `spec.md` or `review.md`
- during `/lean-spec:implement`, do not update `spec.md` status, task checklists, or timestamps
- only the Architect may reconcile `spec.md` status, checklists, and closure state during review or end

## Completion Discipline

At the end of any phase:
- summarize what changed
- note whether canonical artifacts changed
- note whether `context7`, `sequential_thinking`, and `playwright` were used or unavailable when relevant
- note the likely next manual phase

Never claim closure is complete unless the active phase is `/lean-spec:end` and the artifacts support that claim.
