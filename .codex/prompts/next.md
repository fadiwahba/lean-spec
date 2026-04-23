# lean-spec — next (Codex)

Resolves the next prompt to paste for the most-recently-updated open feature.

## Inputs

- **Slug** (optional): if empty, auto-picks most-recently-updated non-closed feature

## Steps

```bash
SLUG="<paste slug or leave empty>"
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

if [ -z "$SLUG" ]; then
  best=""; best_time=""
  while IFS= read -r wf; do
    phase=$(jq -r '.phase // ""' "$wf")
    [ "$phase" = "closed" ] || [ -z "$phase" ] && continue
    updated=$(jq -r '.updated_at // ""' "$wf")
    if [ -z "$best_time" ] || [[ "$updated" > "$best_time" ]]; then
      best="$wf"; best_time="$updated"
    fi
  done < <(find "$PROJ/features" -name "workflow.json" 2>/dev/null)
  [ -z "$best" ] && { echo "No in-progress features. Paste start-spec to begin."; exit 0; }
  WF="$best"; SLUG=$(jq -r '.slug' "$WF")
else
  WF="$PROJ/features/$SLUG/workflow.json"
  [ -f "$WF" ] || { echo "Feature '$SLUG' not found"; exit 1; }
fi

PHASE=$(jq -r '.phase' "$WF")
echo "Feature: $SLUG  |  Phase: $PHASE"

case "$PHASE" in
  specifying)   echo "Next prompt: .codex/prompts/submit-implementation.md (slug: $SLUG)" ;;
  implementing) echo "Next prompt: .codex/prompts/submit-review.md (slug: $SLUG)" ;;
  reviewing)
    R="$PROJ/features/$SLUG/review.md"
    if [ -f "$R" ]; then
      V=$(awk '/^verdict:/ { gsub(/[[:space:]]/, ""); sub(/^verdict:/, ""); print; exit }' "$R")
      case "$V" in
        APPROVE)     echo "Next prompt: .codex/prompts/close-spec.md (slug: $SLUG)" ;;
        NEEDS_FIXES) echo "Next prompt: .codex/prompts/submit-fixes.md (slug: $SLUG)" ;;
        BLOCKED)     echo "BLOCKED — human intervention required" ;;
      esac
    else
      echo "Next: paste submit-review (reviewer hasn't produced review.md yet)"
    fi
    ;;
  closed) echo "No next step — feature is closed." ;;
esac
```
