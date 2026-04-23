# lean-spec — spec-status (Codex)

## Inputs

- **Slug** (optional): if omitted, prints all features

## Steps

```bash
SLUG="<paste slug or leave empty>"
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

if [ -n "$SLUG" ]; then
  WF="$PROJ/features/$SLUG/workflow.json"
  [ -f "$WF" ] || { echo "Feature '$SLUG' not found"; exit 1; }
  echo "Slug:    $(jq -r '.slug' "$WF")"
  echo "Phase:   $(jq -r '.phase' "$WF")"
  echo "Updated: $(jq -r '.updated_at' "$WF")"
  echo ""
  echo "History:"
  jq -r '.history[] | "  - \(.phase)  (entered \(.entered_at))"' "$WF"
  echo ""
  PHASE=$(jq -r '.phase' "$WF")
  case "$PHASE" in
    specifying)   echo "Next: submit-implementation" ;;
    implementing) echo "Next: submit-review" ;;
    reviewing)
      R="$PROJ/features/$SLUG/review.md"
      if [ -f "$R" ]; then
        V=$(awk '/^verdict:/ { gsub(/[[:space:]]/, ""); sub(/^verdict:/, ""); print; exit }' "$R")
        case "$V" in
          APPROVE)     echo "Next: close-spec" ;;
          NEEDS_FIXES) echo "Next: submit-fixes" ;;
          BLOCKED)     echo "Next: (BLOCKED — human intervention)" ;;
        esac
      else
        echo "Next: (awaiting reviewer output)"
      fi
      ;;
    closed) echo "No next step — feature is closed." ;;
  esac
else
  find "$PROJ/features" -name "workflow.json" 2>/dev/null | sort | while read wf; do
    echo "$(jq -r '.slug' "$wf")  [$(jq -r '.phase' "$wf")]  $(jq -r '.updated_at' "$wf")"
  done
fi
```
