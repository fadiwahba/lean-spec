---
description: Advance to reviewing phase and dispatch the reviewer subagent (two-skill sequence)
argument-hint: <slug>
allowed-tools: Bash, Read
---

# /lean-spec:submit-review

Advance a feature from `implementing` to `reviewing` and dispatch the reviewer subagent.

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Source lib/workflow.sh, verify current phase is `implementing`. If not, say: "Phase gate: expected 'implementing', got '<phase>'."
4. Verify `features/$ARGUMENTS/notes.md` exists. If not, say: "notes.md not found. The coder subagent must produce notes.md before review can proceed."

## Steps

1. Advance phase to `reviewing`:
```bash
SLUG="$ARGUMENTS"
PLUGIN_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Error: must run from within a git repository" >&2; exit 1; }
cd "$PLUGIN_ROOT" 2>/dev/null || true
source "$PLUGIN_ROOT/lib/workflow.sh"
set_phase "features/$SLUG/workflow.json" "reviewing"
```

2. Read `features/$SLUG/spec.md` and `features/$SLUG/notes.md`.

3. Dispatch the reviewer subagent using `agents/reviewer-prompt.md` as the prompt template. The reviewer runs two skills in sequence:
   - `lean-spec:reviewing-spec-compliance`
   - `lean-spec:reviewing-code-quality`
   Expected output: `features/$SLUG/review.md` with verdict `APPROVE | NEEDS_FIXES | BLOCKED`.

4. Tell the user: "Dispatching reviewer subagent for '$ARGUMENTS'. Expected output: features/$ARGUMENTS/review.md with verdict APPROVE | NEEDS_FIXES | BLOCKED."
