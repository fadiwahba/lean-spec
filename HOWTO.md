# lean-spec HOWTO

This guide shows the normal way to use `lean-spec` in Claude Code and Gemini CLI.

lean-spec is intentionally manual:
- the human chooses when each phase starts
- the default session agent orchestrates but does not auto-advance
- each artifact has one clear owner

## Before You Start

For an active Claude Code project, the meaningful runtime files are:
- `.claude/agents/lean-spec/*.md`
- `.claude/commands/lean-spec/*.md`
- `.claude/hooks/lean-spec/*.sh`
- `.claude/lean-spec/templates/*.md`
- `.claude/settings.json`

The `lean-spec/` folder contains:
- framework docs
- feature templates
- portable Claude starter files
- portable hook assets
- portable Gemini starter files
- portable OpenCode starter files

## Install Into a Project

This framework is not a Claude plugin.

To install it into a target project, copy these files into the target project's `.claude/` tree:

- `lean-spec/claude/agents/lean-spec/architect.md` -> `.claude/agents/lean-spec/architect.md`
- `lean-spec/claude/agents/lean-spec/coder.md` -> `.claude/agents/lean-spec/coder.md`
- `lean-spec/claude/commands/lean-spec/*.md` -> `.claude/commands/lean-spec/*.md`
- `lean-spec/claude/hooks/lean-spec/*.sh` -> `.claude/hooks/lean-spec/*.sh`
- `lean-spec/claude/lean-spec/templates/*.md` -> `.claude/lean-spec/templates/*.md`
- `lean-spec/claude/LEAN_SPEC_INSTRUCTIONS.md` -> `.claude/LEAN_SPEC_INSTRUCTIONS.md`

Then merge:

- `lean-spec/claude/settings.example.json` -> `.claude/settings.json`
- optional: `lean-spec/claude/settings.stop-ui.example.json` -> `.claude/settings.json`

Do not make lean-spec the default contents of the target project's root `CLAUDE.md` unless that repo is dedicated to lean-spec-only work.
In a normal repo, keep `CLAUDE.md` generic and project-focused. The lean-spec runtime should stay opt-in through `.claude/commands/lean-spec/`.
Use `lean-spec/claude/CLAUDE.example.md` only when you intentionally want lean-spec to be the default workflow for that repo.

Also make sure the project-visible artifact root exists:

- `lean-spec/features/`

The hook commands in `settings.example.json` assume the hooks are copied to:

- `.claude/hooks/lean-spec/remind-manual-workflow.sh`
- `.claude/hooks/lean-spec/enforce-manual-workflow.sh`
- optional: `.claude/hooks/lean-spec/remind-ui-validation-on-stop.sh`

## Install Into a Gemini Project

To install lean-spec into a Gemini CLI project, copy these files into the target project's `.gemini/` tree:

- `lean-spec/gemini/commands/lean-spec/*.toml` -> `.gemini/commands/lean-spec/*.toml`
- `lean-spec/gemini/hooks/lean-spec/*.sh` -> `.gemini/hooks/lean-spec/*.sh`
- `lean-spec/gemini/lean-spec/templates/*.md` -> `.gemini/lean-spec/templates/*.md`
- `lean-spec/gemini/LEAN_SPEC_INSTRUCTIONS.md` -> `.gemini/LEAN_SPEC_INSTRUCTIONS.md`

Then merge:

- `lean-spec/gemini/settings.example.json` -> `.gemini/settings.json`
- optional stricter response validation: `lean-spec/gemini/settings.strict.example.json` -> `.gemini/settings.json`
- optional: `lean-spec/gemini/settings.pro.example.json`
- optional: `lean-spec/gemini/settings.flash.example.json`
- `lean-spec/gemini/geminiignore.example` -> `.geminiignore`

Do not make lean-spec the default contents of the target project's root `GEMINI.md` unless that repo is dedicated to lean-spec-only work.
In a normal repo, keep `GEMINI.md` generic and project-focused. The lean-spec runtime should stay opt-in through `.gemini/commands/lean-spec/`.
Use `lean-spec/gemini/GEMINI.example.md` only when you intentionally want lean-spec to be the default workflow for that repo.

Also make sure the project-visible artifact root exists:

- `lean-spec/features/`

Recommended session split:
- `gemini -m gemini-3-pro-preview` for `/lean-spec:start-spec`, `/lean-spec:review-spec`, `/lean-spec:spec-status`, `/lean-spec:resume-spec`, `/lean-spec:close-spec`
- `gemini -m gemini-3-flash-preview` for `/lean-spec:implement-spec`

Gemini-specific note:
- `Architect` and `Coder` are session roles, not native spawned subagents
- if a phase is started in the wrong session, stop and rerun it in the intended model session

## Install Into an OpenCode Project

Use this installation when you want OpenCode to participate in lean-spec, either as:
- a Coder companion only
- or a full lean-spec host with separate Architect and Coder agents

Copy these files into the target project:

- `lean-spec/opencode/LEAN_SPEC_INSTRUCTIONS.md` -> `.opencode/LEAN_SPEC_INSTRUCTIONS.md`
- `lean-spec/opencode/opencode.example.json` -> merge into the target project's root `opencode.json`
- `lean-spec/opencode/agents/lean-spec-architect.md` -> `.opencode/agents/lean-spec-architect.md`
- `lean-spec/opencode/agents/lean-spec-coder.md` -> `.opencode/agents/lean-spec-coder.md`
- `lean-spec/opencode/commands/lean-spec/start-spec.md` -> `.opencode/commands/lean-spec/start-spec.md`
- `lean-spec/opencode/commands/lean-spec/implement-spec.md` -> `.opencode/commands/lean-spec/implement-spec.md`
- `lean-spec/opencode/commands/lean-spec/review-spec.md` -> `.opencode/commands/lean-spec/review-spec.md`
- `lean-spec/opencode/commands/lean-spec/spec-status.md` -> `.opencode/commands/lean-spec/spec-status.md`
- `lean-spec/opencode/commands/lean-spec/resume-spec.md` -> `.opencode/commands/lean-spec/resume-spec.md`
- `lean-spec/opencode/commands/lean-spec/close-spec.md` -> `.opencode/commands/lean-spec/close-spec.md`
- `lean-spec/opencode/skills/lean-spec-workflow/SKILL.md` -> `.opencode/skills/lean-spec-workflow/SKILL.md`
- `lean-spec/opencode/lean-spec/templates/*.md` -> `.opencode/lean-spec/templates/*.md`

Also make sure the canonical artifact root exists:

- `lean-spec/features/`

Do not make lean-spec the default contents of the target project's root `AGENTS.md` unless that repo is dedicated to lean-spec-only work.
In a normal repo, keep `AGENTS.md` generic and project-focused. The lean-spec runtime should stay opt-in through `.opencode/commands/lean-spec/`.
Use `lean-spec/opencode/AGENTS.example.md` only when you intentionally want lean-spec to be the default workflow for that repo.

If you are running mixed mode:
- `/lean-spec:implement-spec <slug>`
- `/lean-spec:spec-status <slug>`
- `/lean-spec:resume-spec <slug>`

Keep these phases in Claude Code:
- `/lean-spec:start-spec <slug>`
- `/lean-spec:review-spec <slug>`
- `/lean-spec:close-spec <slug>`

If you are running full OpenCode mode:
- use `/lean-spec:start-spec`, `/lean-spec:implement-spec`, `/lean-spec:review-spec`, `/lean-spec:spec-status`, `/lean-spec:resume-spec`, and `/lean-spec:close-spec` in OpenCode
- assign different models to `.opencode/agents/lean-spec-architect.md` and `.opencode/agents/lean-spec-coder.md` if you want different Architect and Coder behavior

## Standard Flow

Use this sequence for most work:

1. Run `/lean-spec:start-spec <slug>`
2. Review `spec.md`
3. If requirements change, run `/lean-spec:update-spec <slug>`
4. Run `/lean-spec:implement-spec <slug>`
5. Run `/lean-spec:review-spec <slug>`
6. Run `/lean-spec:spec-status <slug>` or `/lean-spec:resume-spec <slug>` when you need state inspection or recovery
7. If review findings remain, run `/lean-spec:implement-spec <slug>` again
8. Run `/lean-spec:close-spec <slug>` when review is clean and you want the framework to reconcile and close the feature

Strict ownership:
- scaffold and routing -> default session agent
- `spec.md` -> Architect agent
- implementation and `notes.md` -> Coder agent
- `review.md` -> Architect agent

## Starting a New Feature

Run:

```text
/lean-spec:start-spec todo-app-zustand
```

Then provide only the feature brief, requirements, design direction, and constraints.

Good prompt:

```text
Build a simple Next.js todo app with Zustand and shadcn/ui.

Requirements:
- add todo
- toggle complete
- delete todo
- filter all, active, completed
- persist locally
- TypeScript
- App Router

Do not implement yet. Stop after the spec is ready.
```

The expected result of `/lean-spec:start-spec` is:
- feature folder exists
- the scaffold is copied from the host CLI template source:
  - Claude: `.claude/lean-spec/templates/`
  - Gemini: `.gemini/lean-spec/templates/`
- `spec.md` is authored by the Architect role
- `notes.md` and `review.md` are scaffolded
- the workflow stops and waits for you

## Implementing

After the spec is approved, run:

```text
/lean-spec:implement-spec todo-app-zustand
```

Expected result:
- the Coder role implements from `spec.md`
- blockers, deviations, and partial completion notes go into `notes.md`
- the workflow stops and waits for you

## Reviewing

When the implementation is ready for review, run:

```text
/lean-spec:review-spec todo-app-zustand
```

Expected result:
- the Architect role reviews against `spec.md`, `notes.md`, and the implementation
- findings are written into `review.md`
- `spec.md` checklist and status are reconciled to match the reviewed implementation state
- the workflow stops and waits for you

If findings remain, run `/lean-spec:implement-spec <slug>` again to address them.

## Updating A Spec

When requirements, UX direction, constraints, or acceptance criteria change after planning, run:

```text
/lean-spec:update-spec todo-app-zustand
```

Expected result:
- the Architect role updates `spec.md`
- the orchestrator does not edit `spec.md` directly
- the workflow stops and waits for the next explicit human command

## Hook Strategy

Use hooks to reduce orchestrator drift, not to create a second lifecycle state machine.

Recommended events:
- Claude: `UserPromptSubmit`, `PreToolUse`, optional `Stop`
- Gemini: `BeforeAgent`, `BeforeTool`, optional `AfterAgent`

Do not add a separate active-state file just for hooks.
Current workflow state should continue to come from:
- `spec.md`
- `notes.md`
- `review.md`

The hook files are project-copy assets.
- Claude: wire `lean-spec/claude/hooks/lean-spec/` through `.claude/settings.json` using `lean-spec/claude/settings.example.json`
- Gemini: wire `lean-spec/gemini/hooks/lean-spec/` through `.gemini/settings.json` using `lean-spec/gemini/settings.example.json`
- optional Gemini stricter response validation: `lean-spec/gemini/settings.strict.example.json`
- optional Claude UI end-of-turn reminder: `lean-spec/claude/settings.stop-ui.example.json`

## Ending

When review is clean and you want the framework to perform final cleanup, run:

```text
/lean-spec:close-spec todo-app-zustand
```

Expected result:
- `spec.md` status is reconciled to `completed`
- checklist items in `spec.md` are marked complete
- `Updated At` fields are refreshed from a shell-backed timestamp
- open notes and open review findings must be zero, or closure is blocked

`/lean-spec:close-spec` should be the final cleanup pass, not the first time the spec checklist catches up with reality.

## Good Prompting Pattern

Good prompts should say:
- which feature slug to work on
- what the feature should do
- whether the request should stop after the current phase
- any important product or visual direction

Avoid vague prompts like:

```text
Build me a todo app.
```

That leaves too much planning ambiguity for the Architect.

## Common Mistakes

- Running `/lean-spec:implement-spec` before `spec.md` is ready
- Expecting the default session agent to continue automatically after a phase
- Letting the Coder rewrite `spec.md`
- Letting the Architect implement fixes directly
- Treating `notes.md` as a second spec instead of implementation context
