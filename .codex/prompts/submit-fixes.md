# lean-spec — submit-fixes (Codex)

## Inputs

- **Slug**: <kebab-case-feature-name>

## Steps

### 1. Phase-gate + rollback

```bash
SLUG="<paste slug>"
WF="features/$SLUG/workflow.json"

[ -f "$WF" ] || { echo "Feature '$SLUG' not found"; exit 1; }
[ "$(jq -r '.phase' "$WF")" = "reviewing" ] || { echo "Phase gate: expected reviewing"; exit 1; }
[ -f "features/$SLUG/review.md" ] || { echo "review.md missing"; exit 1; }

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

### 2. Apply fixes

Read `features/<slug>/review.md` — every Critical and Important finding must be addressed. Honour the hard-forbidden edits list.

### 3. APPEND to notes.md (don't rewrite — post-experiment fix #80)

Count existing `## Cycle \d+ fixes` headings in `features/<slug>/notes.md`. Compute `N = count + 1`. Append:

```markdown

## Cycle <N> fixes

### Addressing review.md findings

| Finding | Severity | Fix | File:line |
|---|---|---|---|
| <paraphrase> | Critical/Important/Minor | <one-line summary> | `path/to/file.ts:L-L` |

### Other notes (if any)
```

Preserve the prior `## What was built`, `## How to verify`, etc. sections above.

### 4. Hand off

Tell the user: "Fixes applied. Paste the `submit-review` prompt to re-review."
