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

- **specifying**: Spec is being written/refined. No implementation work yet. The Architect owns this phase.
- **implementing**: Spec is locked. The Implementer builds against the acceptance criteria in `spec.md`. No spec changes allowed.
- **reviewing (NEEDS_FIXES)**: Reviewer found gaps. The Implementer fixes and resubmits. Do not re-review until fixes are submitted.
- **reviewing (APPROVE)**: All criteria passed. Ready to close. No further implementation needed.
- **closed**: Done. No further action.

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
- Do not invoke the `writing-specs`, `reviewing-spec-compliance`, or `reviewing-code-quality` skills from here — those are invoked by their respective roles during their phases.
