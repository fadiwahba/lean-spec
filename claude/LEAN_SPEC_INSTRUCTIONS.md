# Lean-Spec Instructions

This project uses `lean-spec` for feature delivery.

## Workflow Model

This is a Claude-only, human-controlled workflow.

Roles:
- default session agent: orchestrator
- `architect`: planner / architect / reviewer
- `coder`: implementer / coder

The human advances phases explicitly with:
- `/plan <slug>`
- `/implement <slug>`
- `/review <slug>`
- `/status <slug>`
- `/resume <slug>`
- `/end <slug>`

There are no automatic gates or automatic phase transitions.

## Source of Truth

For each feature, the canonical artifacts live in:

- `lean-spec/features/<slug>/spec.md`
- `lean-spec/features/<slug>/notes.md`
- `lean-spec/features/<slug>/review.md`

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

### `/plan <slug>`

Use when:
- starting a new feature
- revisiting planning for an existing feature

Expected outcome:
- feature folder exists
- `spec.md` is created or updated by `architect`
- `notes.md` and `review.md` exist
- the phase stops and waits for the human

### `/implement <slug>`

Use when:
- the spec is approved
- review findings need fixes

Expected outcome:
- `coder` implements from `spec.md`
- `notes.md` captures blockers, deviations, and partial completion notes
- the phase stops and waits for the human

### `/review <slug>`

Use when:
- implementation is ready for review
- you want a fresh review pass after fixes

Expected outcome:
- `architect` reviews against `spec.md`, `notes.md`, and code changes
- `review.md` is updated with findings and dispositions
- the phase stops and waits for the human

### `/end <slug>`

Use when:
- you want a final artifact-state summary
- you want to stop without auto-continuing

Expected outcome:
- concise summary of current `spec.md`, `notes.md`, and `review.md`
- clear signal about whether the feature is actually ready to stop

## Core Rules

- `spec.md` is authored only by `architect`
- `notes.md` is authored only by `coder`
- `review.md` is authored only by `architect`
- `coder` must not silently change scope
- `architect` must not implement code in this workflow
- the default session agent must stop after each phase until the human runs the next command

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
- use the timestamp format `YYYY-MM-DD HH:MM TZ`

## Tooling Discipline

Use `Context7` before implementation or review when external APIs, libraries, frameworks, or tool behavior matter.

Use `sequential-thinking` before multi-step or risky planning, implementation, or review work when the task is ambiguous.

For frontend/UI work:
- use Playwright or equivalent browser validation when available
- treat visible regressions, broken layout, or spec mismatch as real review issues
