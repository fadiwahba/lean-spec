---
description: Run a standalone Playwright visual-fidelity check for a feature and append findings to review.md
argument-hint: <slug>
allowed-tools: Bash, Read, Write, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_evaluate
---

# /lean-spec:visual-check

Run a standalone Playwright visual-fidelity check for a feature. Use this after `submit-review` (without `--visual`) to run the Playwright check separately — avoids port conflicts when running multiple reviews in parallel.

Appends a `## Visual Fidelity (standalone check)` section to `features/<slug>/review.md`.

## Pre-flight

```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"
if [ ! -f "$WF" ]; then
  echo "Feature '$SLUG' not found."; exit 1
fi
PHASE=$(jq -r '.phase // ""' "$WF")
if [ "$PHASE" != "reviewing" ] && [ "$PHASE" != "closed" ]; then
  echo "visual-check requires phase 'reviewing' or 'closed'. Current: '$PHASE'."
  echo "Run /lean-spec:submit-review $SLUG first."
  exit 1
fi
if [ ! -f "features/$SLUG/review.md" ]; then
  echo "review.md not found. Run /lean-spec:submit-review $SLUG first."
  exit 1
fi
echo "Feature: $SLUG | Phase: $PHASE"
```

## Steps

1. Read `features/<slug>/spec.md` to find:
   - The visual contract reference (e.g. `docs/ux-design.jpg` or similar)
   - Visual acceptance criteria (colour tokens, typography, layout requirements)

2. Determine the dev server URL — default to `http://localhost:3000`. Check `spec.md` Technical Notes for overrides.

3. Verify the dev server is running:
   ```bash
   curl -sf http://localhost:3000 >/dev/null 2>&1 && echo "server: running" || echo "server: not running — start with npm run dev"
   ```
   If not running, start it: `npm run dev > /tmp/lean-spec-visual-check.log 2>&1 &` and wait ~5s.

4. Navigate to the dev server using Playwright and capture a full-page screenshot:
   - Save to `.playwright-mcp/<slug>-visual-check.png` (explicit relative path)
   - Also capture an accessibility snapshot for structure verification

5. Compare the screenshot against the visual contract and spec ACs:
   - Named elements present? (heading, input, stats row, task list, etc.)
   - Typography matches spec? (font families, sizes)
   - Colour tokens applied? (spot-check the hex values named in ACs)
   - Layout structure correct? (centred column, correct widths)
   - No runtime render bugs? (missing elements, overlapping, broken layout)
   - Browser console errors/warnings?

6. Compile findings with PASS / FAIL per AC. Use the same severity taxonomy as code quality (Critical / Important / Minor).

7. Append to `features/<slug>/review.md`:

   ```markdown
   ## Visual Fidelity (standalone check)

   Screenshot: `.playwright-mcp/<slug>-visual-check.png`

   | Visual AC | Result | Notes |
   |---|---|---|
   | <ac description> | ✅ PASS / ❌ FAIL | details |

   **Overall: PASS / FAIL**
   ```

   If the review.md already contains a `## Visual Fidelity` section, replace it rather than duplicate.

8. Report to the user:
   ```
   Visual check complete for '<slug>'.
   Overall: PASS | FAIL
   Screenshot: .playwright-mcp/<slug>-visual-check.png
   Findings appended to features/<slug>/review.md.
   ```

   If FAIL findings are Critical or Important, suggest: "Run /lean-spec:submit-fixes <slug> to address visual findings before closing."

## Notes

- This command does not change the feature's phase — it only appends to review.md.
- If Playwright tools are not available, report: "Playwright MCP not detected. Start Claude with Playwright MCP enabled to use visual-check."
- Never hard-fail if the dev server won't start — report the issue and explain what to do.
