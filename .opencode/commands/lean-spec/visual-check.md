---
description: Run a standalone Playwright visual-fidelity check and append findings to review.md
---

Arguments: `$ARGUMENTS` (slug)

```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"

if [ ! -f "$WF" ]; then
  echo "Feature '$SLUG' not found."
  exit 1
fi

PHASE=$(jq -r '.phase' "$WF")
if [ "$PHASE" != "reviewing" ] && [ "$PHASE" != "closed" ]; then
  echo "Phase gate: visual-check requires 'reviewing' or 'closed', got '$PHASE'."
  echo "Run /lean-spec:submit-review $SLUG first."
  exit 1
fi

if [ ! -f "features/$SLUG/review.md" ]; then
  echo "review.md not found. Run /lean-spec:submit-review $SLUG first."
  exit 1
fi

echo "Feature: $SLUG | Phase: $PHASE"
echo ""
echo "Visual ACs from spec.md:"
grep -A 50 "Acceptance Criteria" "features/$SLUG/spec.md" 2>/dev/null | head -30 || echo "(spec.md not found)"
```

Run a Playwright visual-fidelity check for the feature:

1. Verify or start the dev server at `http://localhost:3000`.
2. Use Playwright to navigate and capture a full-page screenshot to `.playwright-mcp/<slug>-visual-check.png`.
3. Compare against the visual contract (referenced in spec.md) and each visual AC.
4. List each visual AC with PASS / FAIL and notes.
5. Append a `## Visual Fidelity (standalone check)` section to `features/<slug>/review.md`.
6. Report overall PASS / FAIL.

If Playwright is not available in this environment, report: "Playwright not available. Use /lean-spec:submit-review <slug> --visual in a session with Playwright MCP enabled."
