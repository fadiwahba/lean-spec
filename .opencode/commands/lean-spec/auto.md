---
description: Resolve the next phase command for a feature (no auto-driver in OpenCode — dispatch each command manually)
---

Arguments: `$ARGUMENTS` (slug; `--unattended` flag accepted but ignored in degraded mode).

```bash
SLUG=""
for tok in $ARGUMENTS; do
  case "$tok" in --*) ;; *) [ -z "$SLUG" ] && SLUG="$tok" ;; esac
done

PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
WF="$PROJ/features/$SLUG/workflow.json"

if [ -z "$SLUG" ]; then
  echo "Usage: /lean-spec:auto <slug>"
  echo "(In OpenCode, auto-driver dispatch is unavailable — run each command manually.)"
  exit 1
fi

[ -f "$WF" ] || { echo "Feature '$SLUG' not found. Run /lean-spec:start-spec $SLUG first."; exit 1; }

PHASE=$(jq -r '.phase' "$WF")
echo "Feature: $SLUG  |  Phase: $PHASE"
echo ""
echo "OpenCode note: no auto-driver. Run the next command manually:"
echo ""
case "$PHASE" in
  specifying)   echo "  /lean-spec:submit-implementation $SLUG" ;;
  implementing) echo "  /lean-spec:submit-review $SLUG" ;;
  reviewing)
    R="$PROJ/features/$SLUG/review.md"
    if [ -f "$R" ]; then
      V=$(awk '/^verdict:/ { gsub(/[[:space:]]/, ""); sub(/^verdict:/, ""); print; exit }' "$R")
      case "$V" in
        APPROVE)     echo "  /lean-spec:close-spec $SLUG" ;;
        NEEDS_FIXES) echo "  /lean-spec:submit-fixes $SLUG" ;;
        BLOCKED)     echo "  # BLOCKED — human intervention required" ;;
        *)           echo "  /lean-spec:spec-status $SLUG  # verdict unclear" ;;
      esac
    else
      echo "  /lean-spec:spec-status $SLUG  # awaiting reviewer output"
    fi
    ;;
  closed) echo "  # No next step — feature is closed." ;;
esac
```
