# lean-spec — update-spec (Codex)

Revise an existing spec (only valid in `specifying` phase).

## Inputs

- **Slug**: <kebab-case-feature-name>
- **Change request**: <what you want revised>

## Steps

### 1. Phase-gate

```bash
SLUG="<paste slug>"
BRIEF="<paste change request>"
WF="features/$SLUG/workflow.json"
[ -f "$WF" ] || { echo "Feature '$SLUG' not found"; exit 1; }
PHASE=$(jq -r '.phase' "$WF")
[ "$PHASE" = "specifying" ] || { echo "update-spec only valid in specifying. Current: $PHASE"; exit 1; }

echo "=== existing spec.md ==="
cat "features/$SLUG/spec.md" 2>/dev/null || echo "(missing)"
echo ""
echo "Change request: $BRIEF"
```

### 2. Revise

Act as the Architect. Update `features/<slug>/spec.md` per the change request. Preserve:
- The ~80-line cap
- The numbered V1/V2/... visual-checklist table if AC4 is visual
- Existing ACs unless the change explicitly removes one (in which case, flag the removal for user confirmation rather than silent deletion)

### 3. Hand off

Tell the user: "Spec updated. When ready, paste `submit-implementation`."
