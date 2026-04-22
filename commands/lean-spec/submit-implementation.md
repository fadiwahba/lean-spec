---
description: Advance to implementing phase and dispatch the coder subagent
argument-hint: <slug>
allowed-tools: Bash, Read
---

# /lean-spec:submit-implementation

Advance a feature from `specifying` to `implementing` and dispatch the coder subagent.

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Source lib/workflow.sh, verify current phase is `specifying`. If not, say: "Phase gate: expected 'specifying', got '<phase>'. Run /lean-spec:resume-spec $ARGUMENTS if you need to re-enter the current phase."

## Steps

1. Advance phase to `implementing`:
```bash
SLUG="$ARGUMENTS"
PLUGIN_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Error: must run from within a git repository" >&2; exit 1; }
cd "$PLUGIN_ROOT" 2>/dev/null || true
source "$PLUGIN_ROOT/lib/workflow.sh"
set_phase "features/$SLUG/workflow.json" "implementing"
```

2. Read `features/$SLUG/spec.md` to load the spec.

3. Dispatch the coder subagent using `agents/coder-prompt.md` as the prompt template. Pass:
   - The full content of `features/$SLUG/spec.md`
   - The feature slug
   - The expected output: `features/$SLUG/notes.md`

4. Tell the user: "Dispatching coder subagent for '$ARGUMENTS'. Expected output: features/$ARGUMENTS/notes.md. Once notes.md is produced, run /lean-spec:submit-review $ARGUMENTS."
