---
description: Advance to reviewing phase and dispatch the reviewer subagent (two-skill sequence)
argument-hint: <slug>
allowed-tools: Bash, Read
---

# /lean-spec:submit-review

Advance a feature from `implementing` to `reviewing` and dispatch the reviewer subagent.

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Read `features/$ARGUMENTS/workflow.json` and verify current phase is `implementing`. If not, say: "Phase gate: expected 'implementing', got '<phase>'."
4. Verify `features/$ARGUMENTS/notes.md` exists. If not, say: "notes.md not found. The coder subagent must produce notes.md before review can proceed."

## Steps

1. Advance phase to `reviewing`:
```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"
CURRENT=$(jq -r '.phase // ""' "$WF" 2>/dev/null)
if [ "$CURRENT" != "implementing" ]; then
  echo "Phase gate: expected 'implementing', got '$CURRENT'" >&2; exit 1
fi
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "reviewing" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp" && mv "$tmp" "$WF"
```

2. Read `features/$SLUG/spec.md` and `features/$SLUG/notes.md`.

3. Dispatch the reviewer subagent using `agents/reviewer-prompt.md` as the prompt template. The reviewer runs two skills in sequence:
   - `lean-spec:reviewing-spec-compliance`
   - `lean-spec:reviewing-code-quality`
   Expected output: `features/$SLUG/review.md` with verdict `APPROVE | NEEDS_FIXES | BLOCKED`.

4. Tell the user: "Dispatching reviewer subagent for '$ARGUMENTS'. Expected output: features/$ARGUMENTS/review.md with verdict APPROVE | NEEDS_FIXES | BLOCKED."
