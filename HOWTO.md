# lean-spec HOWTO

This guide shows the normal way to use `lean-spec` in Claude Code.

lean-spec is intentionally manual:
- the human chooses when each phase starts
- the default session agent orchestrates but does not auto-advance
- each artifact has one clear owner

## Before You Start

For an active Claude Code project, the meaningful runtime files are:
- root `CLAUDE.md`
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

## Install Into a Project

This framework is not a Claude plugin.

To install it into a target project, copy these files into the target project's `.claude/` tree:

- `lean-spec/claude/agents/lean-spec/architect.md` -> `.claude/agents/lean-spec/architect.md`
- `lean-spec/claude/agents/lean-spec/coder.md` -> `.claude/agents/lean-spec/coder.md`
- `lean-spec/claude/commands/lean-spec/*.md` -> `.claude/commands/lean-spec/*.md`
- `lean-spec/claude/hooks/lean-spec/*.sh` -> `.claude/hooks/lean-spec/*.sh`
- `lean-spec/claude/lean-spec/templates/*.md` -> `.claude/lean-spec/templates/*.md`
- `lean-spec/claude/LEAN_SPEC_INSTRUCTIONS.md` -> `.claude/LEAN_SPEC_INSTRUCTIONS.md`
- `lean-spec/claude/CLAUDE.example.md` -> use as a merge example for the target project's root `CLAUDE.md`

Then merge:

- `lean-spec/claude/settings.example.json` -> `.claude/settings.json`
- optional: `lean-spec/claude/settings.stop-ui.example.json` -> `.claude/settings.json`

Then update the target project's root `CLAUDE.md` so it points to:

- `.claude/LEAN_SPEC_INSTRUCTIONS.md`

Also make sure the project-visible artifact root exists:

- `lean-spec/features/`

The hook commands in `settings.example.json` assume the hooks are copied to:

- `.claude/hooks/lean-spec/remind-manual-workflow.sh`
- `.claude/hooks/lean-spec/enforce-manual-workflow.sh`
- optional: `.claude/hooks/lean-spec/remind-ui-validation-on-stop.sh`

## Standard Flow

Use this sequence for most work:

1. Run `/plan <slug>`
2. Review `spec.md`
3. Run `/implement <slug>`
4. Run `/review <slug>`
5. Run `/status <slug>` or `/resume <slug>` when you need state inspection or recovery
6. If review findings remain, run `/implement <slug>` again
7. Run `/end <slug>` when review is clean and you want the framework to reconcile and close the feature

Strict ownership:
- scaffold and routing -> default session agent
- `spec.md` -> Architect agent
- implementation and `notes.md` -> Coder agent
- `review.md` -> Architect agent

## Starting a New Feature

Run:

```text
/plan todo-app-zustand
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

The expected result of `/plan` is:
- feature folder exists
- the scaffold is copied from `.claude/lean-spec/templates/`
- `spec.md` is authored by the `architect` agent
- `notes.md` and `review.md` are scaffolded
- the workflow stops and waits for you

## Implementing

After the spec is approved, run:

```text
/implement todo-app-zustand
```

Expected result:
- the `coder` agent implements from `spec.md`
- blockers, deviations, and partial completion notes go into `notes.md`
- the workflow stops and waits for you

## Reviewing

When the implementation is ready for review, run:

```text
/review todo-app-zustand
```

Expected result:
- the `architect` agent reviews against `spec.md`, `notes.md`, and the implementation
- findings are written into `review.md`
- `spec.md` checklist and status are reconciled to match the reviewed implementation state
- the workflow stops and waits for you

If findings remain, run `/implement <slug>` again to address them.

## Hook Strategy

Use hooks to reduce orchestrator drift, not to create a second lifecycle state machine.

Recommended events:
- `UserPromptSubmit` for a concise reminder before Claude processes each human prompt
- `PreToolUse` for ownership and delegation reminders before agent spawning or file edits
- optional `Stop` for a lightweight UI-validation reminder before the turn concludes

Do not add a separate active-state file just for hooks.
Current workflow state should continue to come from:
- `spec.md`
- `notes.md`
- `review.md`

The hook files in `lean-spec/claude/hooks/lean-spec/` are project-copy assets.
Wire them through the target project's `.claude/settings.json` using the example in `lean-spec/claude/settings.example.json`.
If you want the extra end-of-turn UI reminder, merge `lean-spec/claude/settings.stop-ui.example.json` as well.

## Ending

When review is clean and you want the framework to perform final cleanup, run:

```text
/end todo-app-zustand
```

Expected result:
- `spec.md` status is reconciled to `completed`
- checklist items in `spec.md` are marked complete
- `Updated At` fields are refreshed from a shell-backed timestamp
- open notes and open review findings must be zero, or closure is blocked

`/end` should be the final cleanup pass, not the first time the spec checklist catches up with reality.

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

- Running `/implement` before `spec.md` is ready
- Expecting the default session agent to continue automatically after a phase
- Letting the Coder rewrite `spec.md`
- Letting the Architect implement fixes directly
- Treating `notes.md` as a second spec instead of implementation context
