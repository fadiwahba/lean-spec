---
description: Re-dispatch coder with spec + review feedback, then re-enter reviewing
argument-hint: <slug>
allowed-tools: Bash, Read
---

# /lean-spec:submit-fixes

When review verdict is `NEEDS_FIXES`, re-dispatch the coder with `spec.md + review.md`, then advance back to `reviewing`.

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Source lib/workflow.sh, verify current phase is `reviewing`. If not, say: "Phase gate: expected 'reviewing', got '<phase>'."
4. Read `features/$ARGUMENTS/review.md`. Verify it contains `NEEDS_FIXES`. If verdict is `APPROVE`, say: "Verdict is APPROVE — run /lean-spec:close-spec $ARGUMENTS instead." If `BLOCKED`, say: "Verdict is BLOCKED — human intervention required before fixes can proceed."

## Steps

1. Advance phase back to `implementing`:
```bash
SLUG="$ARGUMENTS"
PLUGIN_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Error: must run from within a git repository" >&2; exit 1; }
cd "$PLUGIN_ROOT" 2>/dev/null || true
source "$PLUGIN_ROOT/lib/workflow.sh"
set_phase "features/$SLUG/workflow.json" "implementing"
```

2. Read `features/$SLUG/spec.md` and `features/$SLUG/review.md`.

3. Dispatch the coder subagent. Pass:
   - Full content of `features/$SLUG/spec.md`
   - Full content of `features/$SLUG/review.md` (the review feedback)
   - Expected output: the coder makes code changes in the target project AND overwrites `features/$SLUG/notes.md` with updated implementation notes.

4. After coder completes, advance phase to `reviewing`:
```bash
SLUG="$ARGUMENTS"
PLUGIN_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Error: must run from within a git repository" >&2; exit 1; }
cd "$PLUGIN_ROOT" 2>/dev/null || true
source "$PLUGIN_ROOT/lib/workflow.sh"
set_phase "features/$SLUG/workflow.json" "reviewing"
```

5. Tell the user: "Fix cycle complete. Run /lean-spec:submit-review $ARGUMENTS to re-review."
