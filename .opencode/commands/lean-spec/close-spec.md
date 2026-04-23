---
description: Close a feature after APPROVE verdict
---

Arguments: `$ARGUMENTS` (the feature slug).

```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"

[ -f "$WF" ] || { echo "Feature '$SLUG' not found."; exit 1; }
[ "$(jq -r '.phase' "$WF")" = "reviewing" ] || { echo "Phase gate: expected 'reviewing'"; exit 1; }
[ -f "features/$SLUG/review.md" ] || { echo "review.md not found."; exit 1; }

V=$(awk '/^verdict:/ { gsub(/[[:space:]]/, ""); sub(/^verdict:/, ""); print; exit }' "features/$SLUG/review.md")
[ "$V" = "APPROVE" ] || { echo "Verdict is '$V' — close-spec only succeeds on APPROVE"; exit 1; }

set -e
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "closed" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp"
mv -f "$tmp" "$WF"
echo "phase advanced: reviewing → closed. Feature $SLUG is complete."
```

Tell the user: "Feature closed. Artifacts archived at `features/<slug>/`."
