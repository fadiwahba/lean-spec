---
description: List all non-closed features and the auto command for each (no auto-driver in OpenCode — run each manually)
---

Arguments: `$ARGUMENTS` (`--gates-on` accepted but ignored in degraded mode).

```bash
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
FEATURES_DIR="$PROJ/features"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "No features/ directory found. Run /lean-spec:decompose-prd first."
  exit 1
fi

echo "lean-spec:auto-all (OpenCode degraded mode)"
echo "No auto-driver available. Run each feature manually:"
echo ""

FOUND=0
while IFS= read -r wf; do
  PHASE=$(jq -r '.phase' "$wf")
  SLUG=$(jq -r '.slug' "$wf")
  if [ "$PHASE" != "closed" ]; then
    FOUND=1
    echo "  /lean-spec:auto $SLUG"
  fi
done < <(find "$FEATURES_DIR" -name "workflow.json" 2>/dev/null)

[ "$FOUND" = "0" ] && echo "  All features are already closed."
```
