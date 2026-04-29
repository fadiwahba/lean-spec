---
description: Advance to reviewing and dispatch the reviewer to produce review.md
agent: reviewer
subtask: true
---

Arguments: `$ARGUMENTS` — first token = slug; remaining = optional extras (`security`, `performance`, `full`). Pass `--no-rules` to skip rules.yaml validation.

## Step 1 — Phase gate + advance (+ archive prior review)

```bash
ARGS="$ARGUMENTS"
SLUG="${ARGS%% *}"
EXTRAS="${ARGS#$SLUG}"; EXTRAS="${EXTRAS# }"
WF="features/$SLUG/workflow.json"

[ -f "$WF" ] || { echo "Feature '$SLUG' not found."; exit 1; }
CURRENT=$(jq -r '.phase // ""' "$WF")
[ "$CURRENT" = "implementing" ] || { echo "Phase gate: expected 'implementing', got '$CURRENT'"; exit 1; }
[ -f "features/$SLUG/notes.md" ] || { echo "notes.md not found."; exit 1; }

# Archive prior review.md (post-experiment fix #81)
REVIEW_DIR="features/$SLUG"
if [ -f "$REVIEW_DIR/review.md" ]; then
  PRIOR=$(ls "$REVIEW_DIR"/review-cycle-*.md 2>/dev/null | wc -l | tr -d ' ')
  NEXT=$((PRIOR + 1))
  mv -f "$REVIEW_DIR/review.md" "$REVIEW_DIR/review-cycle-${NEXT}.md"
fi

set -e
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "reviewing" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp"
mv -f "$tmp" "$WF"
echo "phase advanced: implementing → reviewing (extras: ${EXTRAS:-none})"
```

## Step 2 — Review

Act as the Reviewer (per your agent definition). Run the review pipeline:
- Default skills (always): spec-compliance + code-quality
- Scope-violation sweep (mandatory Critical): `git diff --name-only` against the coder's hard-forbidden list
- Visual fidelity (AUTO if Playwright): screenshot → `.playwright-mcp/<name>.png`
- Extras: parse `$EXTRAS` and run `security` / `performance` / `full` as requested

## Step 3 — Write review.md with verdict

Per the agent definition's template. Update `handoffs.next_command` based on verdict.

## Step 4 — Hand off

Tell the user the verdict + the next command.
