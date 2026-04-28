# lean-spec — auto (Codex)

Resolves the next phase command for a feature. No auto-driver in Codex — paste each command manually in order.

## Inputs

- **Slug**: the feature slug to check

## Steps

```bash
SLUG="<paste slug>"
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
WF="$PROJ/features/$SLUG/workflow.json"

[ -f "$WF" ] || { echo "Feature '$SLUG' not found. Paste start-spec to begin."; exit 1; }

PHASE=$(jq -r '.phase' "$WF")
echo "Feature: $SLUG  |  Phase: $PHASE"
echo ""
echo "Codex note: no auto-driver (no SlashCommand dispatch). Run the next prompt manually:"
echo ""
case "$PHASE" in
  specifying)   echo "  .codex/prompts/submit-implementation.md  (slug: $SLUG)" ;;
  implementing) echo "  .codex/prompts/submit-review.md  (slug: $SLUG)" ;;
  reviewing)
    R="$PROJ/features/$SLUG/review.md"
    if [ -f "$R" ]; then
      V=$(awk '/^verdict:/ { gsub(/[[:space:]]/, ""); sub(/^verdict:/, ""); print; exit }' "$R")
      case "$V" in
        APPROVE)     echo "  .codex/prompts/close-spec.md  (slug: $SLUG)" ;;
        NEEDS_FIXES) echo "  .codex/prompts/submit-fixes.md  (slug: $SLUG)" ;;
        BLOCKED)     echo "  # BLOCKED — human intervention required" ;;
        *)           echo "  .codex/prompts/spec-status.md  (slug: $SLUG)  # verdict unclear" ;;
      esac
    else
      echo "  .codex/prompts/submit-review.md  (slug: $SLUG)  # reviewer hasn't written review.md yet"
    fi
    ;;
  closed) echo "  # No next step — feature is closed." ;;
esac
```

## Note

The full auto-driver (phase iteration with optional human checkpoints) requires Claude Code's `SlashCommand` tool, which is unavailable in Codex. Use this prompt to check your current position in the lifecycle, then paste the indicated prompt to advance.
