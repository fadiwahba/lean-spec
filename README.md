# lean-spec v0.2

A lightweight, Claude-only, spec-driven workflow for day-to-day development tasks.

## Overview

lean-spec is now a manual, human-controlled workflow built around three Claude roles inside one overall system:

- `Default session agent`: orchestrator
- `Architect agent`: planner / architect / reviewer
- `Coder agent`: implementer / coder

The human explicitly controls phase progression with slash commands:

- `/plan <slug>`
- `/implement <slug>`
- `/review <slug>`
- `/status <slug>`
- `/resume <slug>`
- `/end <slug>`

There are no automatic gates. The workflow advances only when the human runs the next command.

## Agent Roles

### Default Session Agent

The default session agent is the main orchestrator.

Responsibilities:
- accept slash command inputs from the human
- resolve the target feature folder from the feature slug
- scaffold or locate workflow files
- route work to the correct specialist agent
- collect completion status from spawned agents
- report concise phase status back to the human

The default session agent does not own the content of `spec.md`, `notes.md`, or `review.md`.

### Architect Agent

The Architect agent is used in two roles:

1. planner / architect
2. reviewer

Responsibilities as planner:
- read the feature request description
- explore relevant code context
- produce the implementation plan in `spec.md`

Responsibilities as reviewer:
- read `spec.md`
- read `notes.md`
- inspect changed files and diff
- write review findings into `review.md`

The Architect agent owns:
- `spec.md`
- `review.md`

The Architect agent does not implement code changes directly in this workflow.

### Coder Agent

The Coder agent is the implementer.

Responsibilities:
- read `spec.md`
- read `review.md` when review findings exist
- implement the approved plan
- address code review findings in later iterations
- record blockers, deviations, partial completion notes, and reviewer guidance in `notes.md`

The Coder agent owns:
- `notes.md`
- code implementation work

The Coder agent does not rewrite `spec.md` or `review.md`.

## File Ownership

### `spec.md`

Owner: Architect agent

Purpose:
- architecture
- implementation plan
- assumptions
- scoped tasks
- completion checklist

Only the Architect agent should create or fill this file.

### `notes.md`

Owner: Coder agent

Purpose:
- implementation notes
- blockers
- deviations from plan
- partial completion status
- reviewer guidance
- follow-up work

Only the Coder agent should create or fill this file.

### `review.md`

Owner: Architect agent

Purpose:
- code review findings
- risks
- regressions
- missing tests
- approval or remaining concerns

Only the Architect agent should create or fill this file.

## Folder Structure

Each feature gets its own folder, based on the feature slug.

```txt
features/
  <feature-slug>/
    spec.md
    notes.md
    review.md
```

## Runtime Assets

Portable Claude assets live in:

- `lean-spec/claude/agents/lean-spec/architect.md`
- `lean-spec/claude/agents/lean-spec/coder.md`
- `lean-spec/claude/commands/lean-spec/plan.md`
- `lean-spec/claude/commands/lean-spec/implement.md`
- `lean-spec/claude/commands/lean-spec/review.md`
- `lean-spec/claude/commands/lean-spec/status.md`
- `lean-spec/claude/commands/lean-spec/resume.md`
- `lean-spec/claude/commands/lean-spec/end.md`
- `lean-spec/claude/LEAN_SPEC_INSTRUCTIONS.md`

Templates live in:

- `lean-spec/templates/spec.md`
- `lean-spec/templates/notes.md`
- `lean-spec/templates/review.md`

## Core Rules

1. The human controls phase progression by running the next slash command.
2. `spec.md` is owned by the `architect` agent.
3. `notes.md` is owned by the `coder` agent.
4. `review.md` is owned by the `architect` agent.
5. The orchestrator owns scaffolding, routing, and concise status reporting.
6. The Coder agent must not silently change scope.
7. The Architect agent must not implement code in this workflow.
8. The default session agent should not auto-advance after `/plan`, `/implement`, or `/review`.
9. There is no separate active-state file; workflow state is derived from `spec.md`, `notes.md`, and `review.md`.

## Typical Flow

1. Run `/plan <slug>` to scaffold the feature and have the `architect` agent write `spec.md`.
2. Review the spec manually.
3. Run `/implement <slug>` to have the `coder` agent implement from the approved spec.
4. Run `/review <slug>` to have the `architect` agent review the implementation and write findings.
5. Run `/status <slug>` or `/resume <slug>` when you need to inspect or rebuild workflow state.
6. If review findings exist, run `/implement <slug>` again for fixes.
7. Run `/end <slug>` when you want a final artifact-state summary and stop.
