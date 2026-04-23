---
description: Re-prime conversation context for an in-progress feature
---

Arguments: `$ARGUMENTS` (the feature slug).

```bash
SLUG="$ARGUMENTS"
[ -n "$SLUG" ] || { echo "Usage: /lean-spec:resume-spec <slug>"; exit 1; }
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
WF="$PROJ/features/$SLUG/workflow.json"
[ -f "$WF" ] || { echo "Feature '$SLUG' not found."; exit 1; }

echo "=== workflow.json ==="
cat "$WF" | jq .
for f in spec.md notes.md review.md; do
  [ -f "$PROJ/features/$SLUG/$f" ] && { echo ""; echo "=== $f ==="; cat "$PROJ/features/$SLUG/$f"; }
done
```

After reading the artifacts above, tell the user:
- Current phase
- A one-sentence summary of where we are (e.g. "spec drafted, awaiting /submit-implementation")
- The exact next command (same mapping as `/lean-spec:spec-status`)
