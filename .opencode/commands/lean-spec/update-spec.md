---
description: Revise an existing spec.md (specifying phase only)
agent: architect
subtask: true
---

Arguments: `$ARGUMENTS` — first token = slug; remaining = what to change.

## Step 1 — Validate phase

```bash
ARGS="$ARGUMENTS"
SLUG="${ARGS%% *}"
BRIEF="${ARGS#$SLUG}"; BRIEF="${BRIEF# }"

[ -n "$SLUG" ] || { echo "Usage: /lean-spec:update-spec <slug> [what to change]"; exit 1; }
WF="features/$SLUG/workflow.json"
[ -f "$WF" ] || { echo "Feature '$SLUG' not found."; exit 1; }
PHASE=$(jq -r '.phase' "$WF")
[ "$PHASE" = "specifying" ] || {
  echo "/lean-spec:update-spec only works in 'specifying' phase. Current: '$PHASE'."
  exit 1
}

echo "Existing spec:"
cat "features/$SLUG/spec.md" 2>/dev/null || echo "(spec.md missing)"
echo ""
echo "Change request: $BRIEF"
```

## Step 2 — Revise

<!-- Note: model overrides in rules.yaml do not apply in OpenCode (fixed model). -->
Act as the Architect. Revise `features/<slug>/spec.md` per the change request. Preserve the ~80-line cap and the V1/V2 table rule for visual ACs. If the change would break an AC, flag it for user confirmation before silently removing.

## Step 3 — Hand off

Tell the user: "Spec updated. Review and run `/lean-spec:submit-implementation <slug>` when ready."
