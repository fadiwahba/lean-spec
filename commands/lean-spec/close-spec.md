---
description: Verify APPROVE verdict and close the feature lifecycle
argument-hint: <slug>
allowed-tools: Bash, Read
---

# /lean-spec:close-spec

Verify the review verdict is `APPROVE`, then close the feature.

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Source lib/workflow.sh, verify current phase is `reviewing`. If not, say: "Phase gate: expected 'reviewing', got '<phase>'."
4. Read `features/$ARGUMENTS/review.md`. Verify verdict is `APPROVE`. If not, say: "Cannot close: verdict is '<verdict>'. Resolve before closing."

## Steps

1. Advance phase to `closed`:
```bash
SLUG="$ARGUMENTS"
PLUGIN_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Error: must run from within a git repository" >&2; exit 1; }
cd "$PLUGIN_ROOT" 2>/dev/null || true
source "$PLUGIN_ROOT/lib/workflow.sh"
set_phase "features/$SLUG/workflow.json" "closed"
```

2. Confirm to the user:
   "Feature '$ARGUMENTS' is closed. Artifacts preserved at features/$ARGUMENTS/. Lifecycle complete."
   Print a summary:
   - Spec: features/$ARGUMENTS/spec.md
   - Notes: features/$ARGUMENTS/notes.md
   - Review: features/$ARGUMENTS/review.md
   - Verdict: APPROVE
