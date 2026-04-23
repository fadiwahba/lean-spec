---
description: Verify APPROVE verdict and close the feature lifecycle
argument-hint: <slug>
allowed-tools: Bash, Read
---

# /lean-spec:close-spec

Verify the review verdict is `APPROVE`, then close the feature.

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Read `features/$ARGUMENTS/workflow.json` and verify current phase is `reviewing`. If not, say: "Phase gate: expected 'reviewing', got '<phase>'."
4. Read `features/$ARGUMENTS/review.md`. Verify verdict is `APPROVE`. If not, say: "Cannot close: verdict is '<verdict>'. Resolve before closing."

## Steps

1. Advance phase to `closed`:
```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "closed" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp" && mv -f "$tmp" "$WF"
```

2. Confirm to the user:
   "Feature '$ARGUMENTS' is closed. Artifacts preserved at features/$ARGUMENTS/. Lifecycle complete."
   Print a summary:
   - Spec: features/$ARGUMENTS/spec.md
   - Notes: features/$ARGUMENTS/notes.md
   - Review: features/$ARGUMENTS/review.md
   - Verdict: APPROVE
