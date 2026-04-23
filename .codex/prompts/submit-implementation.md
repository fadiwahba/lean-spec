# lean-spec — submit-implementation (Codex)

## Inputs

- **Slug**: <kebab-case-feature-name>

## Steps

### 1. Phase-gate + advance

```bash
SLUG="<paste slug>"
WF="features/$SLUG/workflow.json"

[ -f "$WF" ] || { echo "Feature '$SLUG' not found"; exit 1; }
CURRENT=$(jq -r '.phase' "$WF")
[ "$CURRENT" = "specifying" ] || { echo "Phase gate: expected specifying, got $CURRENT"; exit 1; }
[ -f "features/$SLUG/spec.md" ] || { echo "spec.md missing"; exit 1; }

set -e
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "implementing" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp"
mv -f "$tmp" "$WF"
echo "phase advanced: specifying → implementing"
```

### 2. Act as coder

Read `features/<slug>/spec.md`. Every AC must be satisfied — no more, no less. Honor the `Coder Guardrails` section as hard constraints.

**HARD-FORBIDDEN EDITS** (treated as Critical scope violation by the reviewer): never modify these without an explicit spec mention:

- `package.json` + lockfiles (INCLUDING `scripts` fields)
- `next.config.*`, `tsconfig.json`, `eslint.config.*`, `postcss.config.*`, `tailwind.config.*`
- Root `app/layout.tsx` metadata / `<head>` / global providers
- Existing tests

If you need a different dev port, start a temporary server and kill its process group on exit (use `ps -o pgid=` + `kill -TERM -$PGID`). DO NOT edit the project `dev` script.

### 3. Write notes.md

```markdown
---
slug: <slug>
phase: implementing
handoffs:
  next_command: /lean-spec:submit-review <slug>
  blocks_on: []
  consumed_by: [reviewer]
---

# Implementation Notes: <slug>

## What was built
<!-- 3–5 bullets: files/functions created or modified -->

## How to verify
<!-- Step-by-step mapped to each AC -->

## Decisions made
## Known limitations
```

### 4. Hand off

Tell the user: "Implementation done. Paste the `submit-review` prompt."
