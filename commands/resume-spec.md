---
description: Re-enter an in-flight phase after a session break
argument-hint: <slug>
allowed-tools: Bash, Read
---

# /lean-spec:resume-spec

Resume an in-progress feature after a session break. Re-primes the agent's context from `workflow.json` and existing artifacts.

## Steps

1. Check `$ARGUMENTS` provided.
2. Read `features/$ARGUMENTS/workflow.json`. If not found, say "Feature '$ARGUMENTS' not found."
3. Load current phase, history, and artifact paths.
4. Read each existing artifact (`spec.md`, `notes.md` if exists, `review.md` if exists).
5. Print a resume summary:
   - "Resuming feature: $ARGUMENTS"
   - "Current phase: <phase>"
   - "Phase history: <list>"
   - "Artifacts loaded: <list>"
   - "Next command: /lean-spec:<appropriate-next-command>"

The appropriate next command per phase:
- `specifying` → `/lean-spec:submit-implementation $ARGUMENTS`
- `implementing` → `/lean-spec:submit-review $ARGUMENTS`
- `reviewing` → `/lean-spec:submit-fixes $ARGUMENTS` (if NEEDS_FIXES) or `/lean-spec:close-spec $ARGUMENTS` (if APPROVE)
- `closed` → "Feature is already closed."
