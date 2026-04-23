---
description: Resolve the next lifecycle command for the most-recently-updated open feature
---

Arguments: `$ARGUMENTS` (optional — specific slug, or empty to auto-pick).

```bash
SLUG="$ARGUMENTS"
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

if [ -z "$SLUG" ]; then
  # pick most-recently-updated non-closed feature
  best=""; best_time=""
  while IFS= read -r wf; do
    phase=$(jq -r '.phase // ""' "$wf")
    [ "$phase" = "closed" ] && continue
    [ -z "$phase" ] && continue
    updated=$(jq -r '.updated_at // ""' "$wf")
    if [ -z "$best_time" ] || [[ "$updated" > "$best_time" ]]; then
      best="$wf"; best_time="$updated"
    fi
  done < <(find "$PROJ/features" -name "workflow.json" 2>/dev/null)
  [ -z "$best" ] && { echo "No in-progress features. Run /lean-spec:start-spec <slug>."; exit 0; }
  WF="$best"; SLUG=$(jq -r '.slug' "$WF")
else
  WF="$PROJ/features/$SLUG/workflow.json"
  [ -f "$WF" ] || { echo "Feature '$SLUG' not found."; exit 1; }
fi

PHASE=$(jq -r '.phase' "$WF")
echo "Feature: $SLUG  |  Phase: $PHASE"

case "$PHASE" in
  specifying)   echo "Next: /lean-spec:submit-implementation $SLUG" ;;
  implementing) echo "Next: /lean-spec:submit-review $SLUG" ;;
  reviewing)
    R="$PROJ/features/$SLUG/review.md"
    if [ -f "$R" ]; then
      V=$(awk '/^verdict:/ { gsub(/[[:space:]]/, ""); sub(/^verdict:/, ""); print; exit }' "$R")
      case "$V" in
        APPROVE)     echo "Next: /lean-spec:close-spec $SLUG" ;;
        NEEDS_FIXES) echo "Next: /lean-spec:submit-fixes $SLUG" ;;
        BLOCKED)     echo "Next: # BLOCKED — human intervention required" ;;
      esac
    else
      echo "Next: /lean-spec:spec-status $SLUG  # awaiting reviewer output"
    fi
    ;;
  closed) echo "No next step — feature is closed." ;;
esac
```
