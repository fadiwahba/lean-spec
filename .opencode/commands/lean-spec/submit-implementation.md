---
description: Advance to implementing and dispatch the coder to produce notes.md
agent: coder
subtask: true
---

Arguments: `$ARGUMENTS` — the feature slug. Pass `--no-rules` to skip rules.yaml validation for this invocation.

## Step 1 — Phase gate + advance

```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"

[ -f "$WF" ] || { echo "Feature '$SLUG' not found."; exit 1; }
CURRENT=$(jq -r '.phase // ""' "$WF")
if [ "$CURRENT" != "specifying" ]; then
  echo "Phase gate: expected 'specifying', got '$CURRENT'"; exit 1
fi
[ -f "features/$SLUG/spec.md" ] || { echo "spec.md not found."; exit 1; }

set -e
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "implementing" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp"
mv -f "$tmp" "$WF"
echo "phase advanced: specifying → implementing"
```

## Step 2 — Implement

Act as the Coder (per your agent definition). Read `features/<slug>/spec.md` and implement it. Honour:
<!-- Note: model overrides in rules.yaml do not apply in OpenCode (fixed model). -->
- Coder Guardrails in the spec
- Hard-forbidden edits list (package.json, lockfiles, framework configs, root layout.tsx, tests)
- Run Playwright smoke-test if MCP available (see agent definition)

## Step 3 — Write notes.md

Produce `features/<slug>/notes.md` per the canonical shape in your agent definition.

## Step 4 — Hand off

Tell the user: "Implementation done. Run `/lean-spec:submit-review <slug>`."
