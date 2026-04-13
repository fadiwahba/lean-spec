# Lean-Spec Instructions

This project uses `lean-spec` for feature delivery.

## Workflow Model

This is a Claude-only, human-controlled workflow.

Roles:
- default session agent: orchestrator
- `architect`: planner / architect / reviewer
- `coder`: implementer / coder

The human advances phases explicitly with:
- `/lean-spec:plan <slug>`
- `/lean-spec:implement <slug>`
- `/lean-spec:review <slug>`
- `/lean-spec:status <slug>`
- `/lean-spec:resume <slug>`
- `/lean-spec:end <slug>`

There are no automatic gates or automatic phase transitions.

## Source of Truth

For each feature, the canonical artifacts live in:

- `lean-spec/features/<slug>/spec.md`
- `lean-spec/features/<slug>/notes.md`
- `lean-spec/features/<slug>/review.md`

Template sources live in:

- `.claude/lean-spec/templates/spec.md`
- `.claude/lean-spec/templates/notes.md`
- `.claude/lean-spec/templates/review.md`

## Orchestrator Rules

The default session agent owns:
- workflow control
- file scaffolding
- command routing
- concise progress reporting

The default session agent does not own the substantive contents of:
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
- route planning and review work to `architect`
- route implementation and review-fix work to `coder`
- collect completion status from specialist agents
- stop at the end of each phase and wait for the next human command

The orchestrator must not:
- auto-advance to the next phase
- author the real implementation plan in `spec.md`
- do the primary implementation work when delegation is available
- do the primary formal review when delegation is available

## Strict Ownership

`architect` owns:
- `spec.md`
- `review.md`

`coder` owns:
- `notes.md`
- code implementation work

## Command Semantics

### `/lean-spec:plan <slug>`

Use when:
- starting a new feature
- revisiting planning for an existing feature

Expected outcome:
- feature folder exists
- scaffold files are copied from `.claude/lean-spec/templates/`
- `spec.md` is created or updated by `architect`
- `notes.md` and `review.md` exist
- the phase stops and waits for the human

### `/lean-spec:implement <slug>`

Use when:
- the spec is approved
- review findings need fixes

Expected outcome:
- `coder` implements from `spec.md`
- `notes.md` captures blockers, deviations, and partial completion notes
- the phase stops and waits for the human

### `/lean-spec:review <slug>`

Use when:
- implementation is ready for review
- you want a fresh review pass after fixes

Expected outcome:
- `architect` reviews against `spec.md`, `notes.md`, and code changes
- `review.md` is updated with findings and dispositions
- `spec.md` is reconciled during review so checklist progress and status stay aligned with the reviewed implementation
- the phase stops and waits for the human

### `/lean-spec:end <slug>`

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

- `spec.md` is authored only by `architect`
- `notes.md` is authored only by `coder`
- `review.md` is authored only by `architect`
- `coder` must not silently change scope
- `coder` must not edit `spec.md` status, checklist items, or `review.md`
- `architect` must not implement code in this workflow
- the default session agent must stop after each phase until the human runs the next command
- `/end` is the explicit final reconciliation phase and should clean up artifact state when closure is valid
- review passes should progressively reconcile `spec.md`; `/end` should finalize closure, not perform the first meaningful checklist reconciliation
- a feature must not close with open notes, open findings, stale `spec.md` status, or unchecked completed tasks

## Context Discipline

Be concise and token-efficient.
Read only the minimum files needed for the current phase.
Keep lean-spec artifacts concise and operational.

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

Use `Context7` before implementation or review when external APIs, libraries, frameworks, or tool behavior matter.

Use `sequential-thinking` before multi-step or risky planning, implementation, or review work when the task is ambiguous or materially risky.

For frontend/UI work:
- use Playwright or equivalent browser validation before declaring implementation or review complete, unless it is explicitly unavailable
- treat visible regressions, broken layout, or spec mismatch as real review issues

Required completion discipline:
- do not report implementation or review complete when `Context7` was required but not used, unless it was explicitly unavailable
- do not report implementation or review complete when `sequential-thinking` was required but not used, unless it was explicitly unavailable
- do not report implementation complete for frontend/UI work when Playwright validation was required but not used, unless it was explicitly unavailable
- every implementation or review summary should state whether `Context7`, `sequential-thinking`, and Playwright were used when relevant
- if a required tool was unavailable, say so explicitly and treat that as an incomplete verification step

Required artifact discipline:
- during `/lean-spec:implement`, `coder` may update `notes.md` and implementation code only
- during `/lean-spec:implement`, do not edit `spec.md` or `review.md`
- during `/lean-spec:implement`, do not update `spec.md` status, task checklists, or timestamps
- only `architect` may reconcile `spec.md` status, checklists, and closure state during review or end

## Hook Guidance

Hooks are appropriate for reducing orchestration drift in this workflow.

Use:
- `UserPromptSubmit` to remind the default session agent of the manual workflow before it handles each human prompt
- `PreToolUse` to reinforce delegation and artifact ownership before agent spawning or file edits
- optional `Stop` hooks to remind the agent about rendered validation for UI-heavy work before ending the turn

Do not use hooks to create or maintain a second workflow state file.
Hook logic must derive lean-spec state from the canonical feature artifacts.
