---
description: Roll reviewing feature back to implementing and dispatch the coder to address reviewer findings
agent: coder
subtask: true
---

Arguments: `$ARGUMENTS` (the feature slug).

## Step 1 — Phase gate + rollback

```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"

[ -f "$WF" ] || { echo "Feature '$SLUG' not found."; exit 1; }
[ "$(jq -r '.phase' "$WF")" = "reviewing" ] || { echo "Phase gate: expected 'reviewing'"; exit 1; }
[ -f "features/$SLUG/review.md" ] || { echo "review.md not found."; exit 1; }

V=$(awk '/^verdict:/ { gsub(/[[:space:]]/, ""); sub(/^verdict:/, ""); print; exit }' "features/$SLUG/review.md")
[ "$V" = "NEEDS_FIXES" ] || { echo "Verdict is '$V' — submit-fixes only valid on NEEDS_FIXES"; exit 1; }

set -e
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "implementing" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp"
mv -f "$tmp" "$WF"
echo "phase rolled back: reviewing → implementing"
```

## Step 2 — Apply fixes

Act as the Coder. Read `features/<slug>/review.md` — every Critical and Important finding must be addressed. Honour hard-forbidden edits.

## Step 3 — APPEND to notes.md (don't rewrite)

Count existing `## Cycle \d+ fixes` headings in `notes.md`, compute `N = count + 1`. Append a new `## Cycle N fixes` section with a findings→fix→file:line table. Preserve prior content (post-experiment fix #80).

## Step 4 — Hand off

Tell the user: "Fixes applied. Run `/lean-spec:submit-review <slug>` to re-review."
