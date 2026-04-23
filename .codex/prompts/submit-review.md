# lean-spec — submit-review (Codex)

## Inputs

- **Slug**: <kebab-case-feature-name>
- **Extras** (optional): `security`, `performance`, or `full`

## Steps

### 1. Phase-gate + archive prior + advance

```bash
SLUG="<paste slug>"
EXTRAS="<paste extras or leave empty>"
WF="features/$SLUG/workflow.json"

[ -f "$WF" ] || { echo "Feature '$SLUG' not found"; exit 1; }
CURRENT=$(jq -r '.phase' "$WF")
[ "$CURRENT" = "implementing" ] || { echo "Phase gate: expected implementing"; exit 1; }
[ -f "features/$SLUG/notes.md" ] || { echo "notes.md missing"; exit 1; }

# Archive prior review (post-experiment fix #81)
if [ -f "features/$SLUG/review.md" ]; then
  PRIOR=$(ls "features/$SLUG"/review-cycle-*.md 2>/dev/null | wc -l | tr -d ' ')
  NEXT=$((PRIOR + 1))
  mv -f "features/$SLUG/review.md" "features/$SLUG/review-cycle-${NEXT}.md"
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

### 2. Act as reviewer

Run the review pipeline:

**Spec compliance**: for each AC in the spec, is it fully satisfied? Missing? Over-implemented? Cite code `file:line`.

**Code quality**: conventions, bugs, security, error handling, complexity. Group findings Critical / Important / Minor.

**Scope-violation sweep (mandatory, Critical when found)**: run `git diff --name-only <base>..HEAD` and flag any coder edit to the hard-forbidden list (package.json, lockfiles, framework configs, layout.tsx, existing tests).

**Visual fidelity (if Playwright MCP available)**: navigate the dev server, save screenshot to `.playwright-mcp/<name>.png`, spot-check tokens via `getComputedStyle`, zero tolerance on console errors.

**Extras** (if requested): `security` → OWASP-lite; `performance` → render hot-paths / N+1 / bundle bloat; `full` → both.

### 3. Write review.md

```markdown
---
slug: <slug>
phase: reviewing
handoffs:
  next_command: /lean-spec:close-spec <slug>   # or submit-fixes if NEEDS_FIXES
  blocks_on: []
  consumed_by: [architect]
verdict: APPROVE | NEEDS_FIXES | BLOCKED
---

# Review: <slug>

## Verdict: APPROVE | NEEDS_FIXES | BLOCKED

## Spec Compliance
| Criterion | Status | Notes |

## Code Quality
### Critical
### Important
### Minor

## Visual Review   (IFF Playwright was available)
## Security Review | Performance Review   (IFF extras requested)

## Summary
```

Update `handoffs.next_command` per verdict:
- `APPROVE` → `/lean-spec:close-spec <slug>`
- `NEEDS_FIXES` → `/lean-spec:submit-fixes <slug>`
- `BLOCKED` → leave blank; human decision required

### 4. Hand off

Tell the user the verdict and the next prompt to paste.
