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

The `lean-spec/` folder contains:
- framework docs
- feature templates
- portable Claude starter files

## Standard Flow

Use this sequence for most work:

1. Run `/plan <slug>`
2. Review `spec.md`
3. Run `/implement <slug>`
4. Run `/review <slug>`
5. Run `/status <slug>` or `/resume <slug>` when you need state inspection or recovery
6. If review findings remain, run `/implement <slug>` again
7. Run `/end <slug>` when you want to stop with a final status summary

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
- `spec.md` is authored by the `architect` agent
- `notes.md` and `review.md` are scaffolded
- the workflow stops and waits for you

## Implementing

After the spec is approved, run:

```text
/implement todo-app-zustand
```

Expected result:
- the Coder implements from `spec.md`
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
- the workflow stops and waits for you

If findings remain, run `/implement <slug>` again to address them.

## Ending

When you want a final summary and no automatic next step, run:

```text
/end todo-app-zustand
```

Expected result:
- current status from `spec.md`
- remaining unchecked tasks
- open notes
- open review findings
- a clear indication of whether the feature is actually ready to stop

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
