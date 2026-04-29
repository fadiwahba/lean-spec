# lean-spec — visual-check (Codex)

## Inputs

- **Slug**: <kebab-case-feature-name>

## Steps

### 1. Validate

```bash
SLUG="<paste slug>"
WF="features/$SLUG/workflow.json"

[ -f "$WF" ] || { echo "Feature '$SLUG' not found"; exit 1; }
PHASE=$(jq -r '.phase' "$WF")
{ [ "$PHASE" = "reviewing" ] || [ "$PHASE" = "closed" ]; } || {
  echo "Phase gate: visual-check requires reviewing or closed, got '$PHASE'"
  exit 1
}
[ -f "features/$SLUG/review.md" ] || { echo "review.md missing — run submit-review first"; exit 1; }
echo "Feature: $SLUG | Phase: $PHASE"
```

### 2. Read visual ACs from spec.md

Read `features/<slug>/spec.md`. Extract all visual acceptance criteria (colour tokens, typography, layout requirements, named UI elements).

### 3. Run Playwright visual check

1. Verify dev server is running:
   ```bash
   curl -sf http://localhost:3000 >/dev/null 2>&1 && echo "running" || echo "not running"
   ```
   If not running, start: `npm run dev &` and wait ~5s.

2. Use Playwright to navigate to `http://localhost:3000` and capture a screenshot to `.playwright-mcp/<slug>-visual-check.png`.

3. For each visual AC, mark PASS / FAIL with a brief note.

### 4. Append to review.md

```markdown
## Visual Fidelity (standalone check)

Screenshot: `.playwright-mcp/<slug>-visual-check.png`

| Visual AC | Result | Notes |
|---|---|---|
| <ac> | ✅ PASS / ❌ FAIL | details |

**Overall: PASS / FAIL**
```

### 5. Hand off

Report: "Visual check complete — Overall: PASS | FAIL." If FAIL findings are Critical/Important, suggest running the `submit-fixes` prompt.
