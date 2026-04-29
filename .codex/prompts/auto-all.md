# lean-spec — auto-all (Codex)

Lists all non-closed features and the prompt file to use for each. No auto-driver in Codex — drive each feature manually by pasting the indicated prompt.

## Steps

```bash
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
FEATURES_DIR="$PROJ/features"

[ -d "$FEATURES_DIR" ] || { echo "No features/ directory. Paste decompose-prd first."; exit 1; }

echo "Non-closed features (paste the indicated prompt for each):"
echo ""

FOUND=0
while IFS= read -r wf; do
  PHASE=$(jq -r '.phase' "$wf")
  SLUG=$(jq -r '.slug' "$wf")
  if [ "$PHASE" != "closed" ]; then
    FOUND=1
    case "$PHASE" in
      specifying)   PROMPT_FILE=".codex/prompts/submit-implementation.md" ;;
      implementing) PROMPT_FILE=".codex/prompts/submit-review.md" ;;
      reviewing)    PROMPT_FILE=".codex/prompts/submit-fixes.md or close-spec.md (check review.md verdict)" ;;
      *)            PROMPT_FILE=".codex/prompts/spec-status.md" ;;
    esac
    echo "  $SLUG  (phase: $PHASE)"
    echo "  → Paste: $PROMPT_FILE  (slug: $SLUG)"
    echo ""
  fi
done < <(find "$FEATURES_DIR" -name "workflow.json" 2>/dev/null)

[ "$FOUND" = "0" ] && echo "  All features are already closed."
```

## Note

The auto-driver requires `SlashCommand` dispatch, which is unavailable in Codex. Use this prompt to locate your features, then paste each feature's prompt file in order.
