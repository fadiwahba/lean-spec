---
name: using-lean-spec
description: Auto-invoke at session start whenever a features/ directory exists — loads lifecycle state for all active features and determines the correct next command for each
---

## When to Auto-Invoke

At session start, if the working directory contains a `features/` directory, invoke this skill unconditionally before responding to the user. Do not wait for the user to mention lean-spec.

Also invoke when the user asks about a feature's status, what to do next, or which phase something is in.

## Discovery Protocol

Run this command to find all active features:

```bash
find features -name "workflow.json" 2>/dev/null | sort
```

For each `workflow.json` found:
1. Read the file and extract `slug` and `phase`.
2. Read `features/<slug>/spec.md` to load the feature's acceptance criteria and scope into context.
3. Determine the correct next command using the lifecycle table below.
4. Report status for each feature.

## Lifecycle Reference

| Current Phase | Sub-state | Next Action | Command |
|---|---|---|---|
| `specifying` | — | Submit implementation | `/lean-spec:submit-implementation <slug>` |
| `implementing` | — | Submit for review | `/lean-spec:submit-review <slug>` |
| `reviewing` | `NEEDS_FIXES` | Submit fixes | `/lean-spec:submit-fixes <slug>` |
| `reviewing` | `APPROVE` | Close the spec | `/lean-spec:close-spec <slug>` |
| `closed` | — | Feature complete | — |

For a feature in `reviewing` phase, determine sub-state by reading `features/<slug>/review.md` and checking whether it contains `NEEDS_FIXES` or `APPROVE`. The verdict lives in `review.md`, not `workflow.json`.

## Phase Gates Summary

- **specifying**: Spec is being written/refined by the **Architect subagent** (dispatched via `/lean-spec:start-spec` or `/lean-spec:update-spec`). No implementation work yet.
- **implementing**: Spec is locked. The **Coder subagent** (dispatched via `/lean-spec:submit-implementation`) builds against the acceptance criteria in `spec.md`. No spec changes allowed.
- **reviewing (NEEDS_FIXES)**: **Reviewer subagent** found gaps. The Coder subagent fixes and resubmits via `/lean-spec:submit-fixes`. Do not re-review until fixes are submitted.
- **reviewing (APPROVE)**: All criteria passed. Ready to close. No further implementation needed.
- **closed**: Done. No further action.

## Orchestrator vs Subagents

You (the session running this skill) are the **orchestrator**. You route commands, read `workflow.json`, relay status, and mediate the user's conversation. You do **not** write `spec.md`, code, `notes.md`, or `review.md` directly — those artifacts are produced by dispatched subagents with pinned model tiers:

| Role | Dispatched by | subagent_type | Plugin definition | Model pin |
|---|---|---|---|---|
| Architect | `/start-spec`, `/update-spec` | `lean-spec:architect` | `agents/architect.md` | `opus` |
| Coder | `/submit-implementation`, `/submit-fixes` | `lean-spec:coder` | `agents/coder.md` | `sonnet` |
| Reviewer | `/submit-review` | `lean-spec:reviewer` | `agents/reviewer.md` | `opus` |

If the user asks you to "just write the spec" or "just edit the AC directly", refuse and re-dispatch via the appropriate slash command. The tier pinning is a runtime guarantee the plugin provides; bypassing it silently defeats the plugin's primary value prop.

## Status Report Format

After discovery, report each feature concisely:

```
Feature: <slug>
  Phase: <phase>
  Spec: <one-line summary of what the feature does>
  Next: <next command to run>
```

If no `workflow.json` files are found, state: "No active lean-spec features found."

## Multi-Feature Projects

Process every discovered feature independently. Report all of them before asking the user what they want to work on. If features are in different phases, list them in this order: `reviewing` → `implementing` → `specifying` → `closed`.

## What Not to Do

- Do not guess the phase from filenames or directory structure — always read `workflow.json`.
- Do not suggest implementation work if the phase is `specifying`.
- Do not suggest spec changes if the phase is `implementing` or later.
- Do not invoke the `writing-specs`, `reviewing-spec-compliance`, or `reviewing-code-quality` skills from here — those are invoked by the respective subagents, not by the orchestrator.
- Do not write `spec.md`, `notes.md`, or `review.md` yourself, even if asked. Dispatch the appropriate slash command so the subagent produces the artifact with the enforced model tier.
