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
3. Read `features/$ARGUMENTS/workflow.json` and verify current phase is `specifying`. If not, say: "Phase gate: expected 'specifying', got '<phase>'. Run /lean-spec:resume-spec $ARGUMENTS if you need to re-enter the current phase."

## Steps

1. Advance phase to `implementing`:
```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"
CURRENT=$(jq -r '.phase // ""' "$WF" 2>/dev/null)
if [ "$CURRENT" != "specifying" ]; then
  echo "Phase gate: expected 'specifying', got '$CURRENT'" >&2; exit 1
fi
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "implementing" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp" && mv "$tmp" "$WF"
```

2. Read `features/$SLUG/spec.md` to load the spec.

3. Dispatch the coder subagent using `agents/coder-prompt.md` as the prompt template. Pass:
   - The full content of `features/$SLUG/spec.md`
   - The feature slug
   - The expected output: `features/$SLUG/notes.md`

4. Tell the user: "Dispatching coder subagent for '$ARGUMENTS'. Expected output: features/$ARGUMENTS/notes.md. Once notes.md is produced, run /lean-spec:submit-review $ARGUMENTS."
