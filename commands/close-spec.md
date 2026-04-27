---
description: Verify APPROVE verdict and close the feature lifecycle
argument-hint: <slug>
allowed-tools: Bash, Read
---

# /lean-spec:close-spec

Verify the review verdict is `APPROVE`, then advance the phase to `closed` using jq via Bash. **Do not use the Write or Edit tools — the PreToolUse hook blocks them on workflow.json. Do not run any `lean-spec`, `npm`, or `npx` command — no such CLI exists.**

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Read `features/$ARGUMENTS/workflow.json` and verify current phase is `reviewing`. If not, say: "Phase gate: expected 'reviewing', got '<phase>'."
4. Read `features/$ARGUMENTS/review.md`. Verify verdict is `APPROVE`. If not, say: "Cannot close: verdict is '<verdict>'. Resolve before closing."

## Steps

1. Advance phase to `closed` using jq. **If this block exits non-zero, STOP and report the error verbatim.**

```bash
set -e
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"
CURRENT=$(jq -r '.phase // ""' "$WF" 2>/dev/null)
if [ "$CURRENT" != "reviewing" ]; then
  echo "Phase gate: expected 'reviewing', got '$CURRENT'" >&2; exit 1
fi
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg now "$NOW" \
  '.phase = "closed" | .updated_at = $now | .history += [{"phase": "closed", "entered_at": $now}]' \
  "$WF" > "$tmp"
mv -f "$tmp" "$WF" || { echo "ERROR: mv failed — workflow.json not updated. Orphan tmp: $tmp" >&2; exit 1; }
NEW_PHASE=$(jq -r '.phase // ""' "$WF" 2>/dev/null)
if [ "$NEW_PHASE" != "closed" ]; then
  echo "ERROR: phase did not advance — expected 'closed', still '$NEW_PHASE'." >&2; exit 1
fi
echo "phase advanced: reviewing → closed"
```

2. Confirm to the user:
   "Feature '$ARGUMENTS' is closed. Artifacts preserved at features/$ARGUMENTS/. Lifecycle complete."
   Print a summary:
   - Spec: features/$ARGUMENTS/spec.md
   - Notes: features/$ARGUMENTS/notes.md
   - Review: features/$ARGUMENTS/review.md
   - Verdict: APPROVE
