---
description: Print current phase, last activity, and the next command for one or all features
---

Arguments: `$ARGUMENTS` (optional — a slug, or empty for all features).

```bash
SLUG="$ARGUMENTS"
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

if [ -n "$SLUG" ]; then
  WF="$PROJ/features/$SLUG/workflow.json"
  [ -f "$WF" ] || { echo "Feature '$SLUG' not found."; exit 1; }
  echo "Slug:    $(jq -r '.slug' "$WF")"
  echo "Phase:   $(jq -r '.phase' "$WF")"
  echo "Updated: $(jq -r '.updated_at' "$WF")"
  echo ""
  echo "History:"
  jq -r '.history[] | "  - \(.phase)  (entered \(.entered_at))"' "$WF"
  echo ""
  PHASE=$(jq -r '.phase' "$WF")
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
          *)           echo "Next: # verdict unclear; inspect review.md" ;;
        esac
      else
        echo "Next: /lean-spec:submit-review $SLUG  # review.md not yet produced"
      fi
      ;;
    closed) echo "No next step — feature is closed." ;;
  esac
else
  find "$PROJ/features" -name "workflow.json" 2>/dev/null | sort | while read wf; do
    echo "$(jq -r '.slug' "$wf")  [$(jq -r '.phase' "$wf")]  last updated: $(jq -r '.updated_at' "$wf")"
  done
fi
```
