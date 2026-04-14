# lean-spec v0.5

A lightweight, spec-driven workflow for day-to-day development tasks in Claude Code and Gemini CLI.

## Overview

lean-spec is now a manual, human-controlled workflow built around three roles inside one overall system:

- `Default session agent`: orchestrator
- `Architect agent`: planner / architect / reviewer
- `Coder agent`: implementer / coder

The human explicitly controls phase progression with slash commands:

- Claude Code: `/lean-spec:start-spec <slug>`, `/lean-spec:implement-spec <slug>`, `/lean-spec:review-spec <slug>`, `/lean-spec:spec-status <slug>`, `/lean-spec:resume-spec <slug>`, `/lean-spec:close-spec <slug>`
- Gemini CLI: `/lean-spec:start-spec <slug>`, `/lean-spec:implement-spec <slug>`, `/lean-spec:review-spec <slug>`, `/lean-spec:spec-status <slug>`, `/lean-spec:resume-spec <slug>`, `/lean-spec:close-spec <slug>`

There are no automatic gates. The workflow advances only when the human runs the next command.

## Agent Roles

### Default Session Agent

The default session agent is the main orchestrator.

Responsibilities:
- accept slash command inputs from the human
- resolve the target feature folder from the feature slug
- scaffold or locate workflow files
- route work to the correct specialist role or session
- collect completion status from the current role/session
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
- `lean-spec/claude/commands/lean-spec/start-spec.md`
- `lean-spec/claude/commands/lean-spec/implement-spec.md`
- `lean-spec/claude/commands/lean-spec/review-spec.md`
- `lean-spec/claude/commands/lean-spec/spec-status.md`
- `lean-spec/claude/commands/lean-spec/resume-spec.md`
- `lean-spec/claude/commands/lean-spec/close-spec.md`
- `lean-spec/claude/settings.example.json`
- `lean-spec/claude/settings.stop-ui.example.json`
- `lean-spec/claude/hooks/lean-spec/remind-manual-workflow.sh`
- `lean-spec/claude/hooks/lean-spec/enforce-manual-workflow.sh`
- `lean-spec/claude/hooks/lean-spec/remind-ui-validation-on-stop.sh`
- `lean-spec/claude/lean-spec/templates/spec.md`
- `lean-spec/claude/lean-spec/templates/notes.md`
- `lean-spec/claude/lean-spec/templates/review.md`
- `lean-spec/claude/LEAN_SPEC_INSTRUCTIONS.md`

Portable Gemini assets live in:

- `lean-spec/gemini/GEMINI.example.md`
- `lean-spec/gemini/LEAN_SPEC_INSTRUCTIONS.md`
- `lean-spec/gemini/settings.example.json`
- `lean-spec/gemini/settings.strict.example.json`
- `lean-spec/gemini/settings.pro.example.json`
- `lean-spec/gemini/settings.flash.example.json`
- `lean-spec/gemini/geminiignore.example`
- `lean-spec/gemini/hooks/lean-spec/remind-manual-workflow.sh`
- `lean-spec/gemini/hooks/lean-spec/enforce-manual-workflow.sh`
- `lean-spec/gemini/hooks/lean-spec/validate-final-response.sh`
- `lean-spec/gemini/commands/lean-spec/start-spec.toml`
- `lean-spec/gemini/commands/lean-spec/implement-spec.toml`
- `lean-spec/gemini/commands/lean-spec/review-spec.toml`
- `lean-spec/gemini/commands/lean-spec/spec-status.toml`
- `lean-spec/gemini/commands/lean-spec/resume-spec.toml`
- `lean-spec/gemini/commands/lean-spec/close-spec.toml`
- `lean-spec/gemini/lean-spec/templates/spec.md`
- `lean-spec/gemini/lean-spec/templates/notes.md`
- `lean-spec/gemini/lean-spec/templates/review.md`

Portable OpenCode assets live in:

- `lean-spec/opencode/AGENTS.md`
- `lean-spec/opencode/AGENTS.example.md`
- `lean-spec/opencode/LEAN_SPEC_INSTRUCTIONS.md`
- `lean-spec/opencode/opencode.example.json`
- `lean-spec/opencode/agents/lean-spec-architect.md`
- `lean-spec/opencode/agents/lean-spec-coder.md`
- `lean-spec/opencode/commands/lean-spec/start-spec.md`
- `lean-spec/opencode/commands/lean-spec/implement-spec.md`
- `lean-spec/opencode/commands/lean-spec/review-spec.md`
- `lean-spec/opencode/commands/lean-spec/spec-status.md`
- `lean-spec/opencode/commands/lean-spec/resume-spec.md`
- `lean-spec/opencode/commands/lean-spec/close-spec.md`
- `lean-spec/opencode/skills/lean-spec-workflow/SKILL.md`
- `lean-spec/opencode/lean-spec/templates/spec.md`
- `lean-spec/opencode/lean-spec/templates/notes.md`
- `lean-spec/opencode/lean-spec/templates/review.md`

## Core Rules

1. The human controls phase progression by running the next slash command.
2. `spec.md` is owned by the `architect` agent.
3. `notes.md` is owned by the `coder` agent.
4. `review.md` is owned by the `architect` agent.
5. The orchestrator owns scaffolding, routing, and concise status reporting.
6. The Coder agent must not silently change scope.
7. The Architect agent must not implement code in this workflow.
8. The default session agent should not auto-advance after `/lean-spec:start-spec`, `/lean-spec:implement-spec`, or `/lean-spec:review-spec`.
9. There is no separate active-state file; workflow state is derived from `spec.md`, `notes.md`, and `review.md`.
10. Artifact timestamps must come from a shell-backed runtime source such as `date "+%Y-%m-%d %H:%M %Z"`; fabricated or placeholder timestamps are invalid.
11. `/lean-spec:close-spec` is a real cleanup phase: when the feature is clean, it should reconcile `spec.md`, refresh artifact timestamps, and close the workflow coherently.
12. Review passes should keep `spec.md` reconciled as work progresses; `/lean-spec:close-spec` should only finalize closure, not backfill the entire checklist for the first time.

## Hooks

Hooks are the right place to reduce orchestrator drift, but only if they are used narrowly:

- `UserPromptSubmit` should remind the default session agent of the lean-spec manual workflow before it reasons over each human prompt.
- `PreToolUse` should reinforce delegation and file ownership before agent spawning or file edits.
- Hooks should not introduce a second workflow state file.
- Canonical workflow state should remain in `spec.md`, `notes.md`, and `review.md`.

The provided hook assets follow that model:

- `settings.example.json` shows the project-level hook wiring for `.claude/settings.json`
- `settings.stop-ui.example.json` shows an optional Stop-hook wiring for UI validation reminders
- `remind-manual-workflow.sh` injects a concise lifecycle reminder on every human prompt
- `enforce-manual-workflow.sh` injects targeted ownership and delegation reminders before specialist-agent spawning and file edits
- `remind-ui-validation-on-stop.sh` is an optional end-of-turn reminder for UI-heavy tasks

This framework is not a Claude plugin.
To use it in a project, copy the assets into that project's `.claude/` folder and merge `settings.example.json` into the target project's `.claude/settings.json`.
If you want the extra end-of-turn UI reminder, also merge `settings.stop-ui.example.json`.

The template source belongs under the target project's hidden Claude config:
- `.claude/lean-spec/templates/spec.md`
- `.claude/lean-spec/templates/notes.md`
- `.claude/lean-spec/templates/review.md`

Feature artifacts remain project-visible and should be scaffolded into:
- `lean-spec/features/<slug>/`

Gemini follows the same lifecycle model, but maps onto:
- `GEMINI.md`
- `.gemini/settings.json`
- `.gemini/commands/lean-spec/*.toml`
- `.gemini/hooks/lean-spec/*.sh`
- `.gemini/lean-spec/templates/*.md`

Gemini-specific note:
- `Architect` and `Coder` are session roles, not native spawned subagents
- use `gemini -m gemini-3-pro-preview` for planning, review, status, resume, and end
- use `gemini -m gemini-3-flash-preview` for implementation
- hooks should remind and enforce workflow discipline, but they should not pretend to switch the current model session

OpenCode-specific note:
- OpenCode can be used either as a Coder companion or as a full lean-spec host with separate Architect and Coder agents
- root `AGENTS.md` is the primary instruction surface
- `opencode.json` can include `.opencode/LEAN_SPEC_INSTRUCTIONS.md` via the `instructions` field
- OpenCode has native agents and subagents, so the lean-spec Coder maps naturally to a dedicated subagent
- the workflow here is enforced through `AGENTS.md`, agent prompts, commands, skills, and permissions

Recommended Gemini session split:
- `gemini -m gemini-3-pro-preview` for planning, review, status, resume, and end
- `gemini -m gemini-3-flash-preview` for implementation

## Typical Flow

1. Run `/lean-spec:start-spec <slug>` to scaffold the feature and have the `architect` role write `spec.md`.
2. Review the spec manually.
3. Run `/lean-spec:implement-spec <slug>` to have the `coder` role implement from the approved spec.
4. Run `/lean-spec:review-spec <slug>` to have the `architect` role review the implementation and write findings.
5. Run `/lean-spec:spec-status <slug>` or `/lean-spec:resume-spec <slug>` when you need to inspect or rebuild workflow state.
6. If review findings exist, run `/lean-spec:implement-spec <slug>` again for fixes.
7. Run `/lean-spec:close-spec <slug>` when review is clean and you want to reconcile the final artifact state and close the feature.
