---
description: Roll phase back to implementing and re-dispatch coder with review feedback
argument-hint: <slug>
allowed-tools: Bash, Read, Task
---

# /lean-spec:submit-fixes

When a review's verdict is `NEEDS_FIXES`, roll the phase from `reviewing` back to `implementing` and re-dispatch the coder with `spec.md + review.md`.

**The command ends in `implementing` phase**, not `reviewing`. After the coder produces updated `notes.md`, the user (or orchestrator) runs `/lean-spec:submit-review <slug>` to re-enter the review — the exact same path as the initial review. One codepath for "start a review," no special cases.

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Read `features/$ARGUMENTS/workflow.json` and verify current phase is `reviewing`. If not, say: "Phase gate: expected 'reviewing', got '<phase>'."
4. Read `features/$ARGUMENTS/review.md`. Verify it contains `NEEDS_FIXES`. If verdict is `APPROVE`, say: "Verdict is APPROVE — run /lean-spec:close-spec $ARGUMENTS instead." If `BLOCKED`, say: "Verdict is BLOCKED — human intervention required before fixes can proceed."

## Steps

1. Roll phase back to `implementing`. **If this block exits non-zero, STOP — do not dispatch the subagent. Report the error verbatim to the user.**
```bash
set -e
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "implementing" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp"
mv -f "$tmp" "$WF" || { echo "ERROR: mv failed — workflow.json not updated. Orphan tmp: $tmp" >&2; exit 1; }
NEW_PHASE=$(jq -r '.phase // ""' "$WF" 2>/dev/null)
if [ "$NEW_PHASE" != "implementing" ]; then
  echo "ERROR: phase did not advance — expected 'implementing', still '$NEW_PHASE'. Aborting before subagent dispatch." >&2
  exit 1
fi
echo "phase rolled back: reviewing → implementing"
```

2. Dispatch the **coder subagent** using the `Task` tool:

   - `subagent_type`: `"lean-spec:coder"`
   - `description`: `"Apply review fixes for <slug>"`
   - `prompt`: build a fresh invocation payload like this (the coder's system prompt comes from `agents/coder.md`; do not include it yourself):

     ```
     Slug: <slug>
     Spec path: features/<slug>/spec.md
     Notes path: features/<slug>/notes.md
     Review path: features/<slug>/review.md
     Mode: fixes

     (The coder should read spec.md and review.md with its own Read tool, address every finding in review.md, then overwrite notes.md to enumerate what was fixed per reviewer item.)
     ```

3. Tell the user: "Fix cycle complete. Feature is in `implementing` phase with updated `notes.md`. Run `/lean-spec:submit-review $ARGUMENTS` to re-review."

## Notes

- **Do NOT auto-advance the phase to `reviewing`** after the coder finishes. The reviewer is dispatched only by `/lean-spec:submit-review`, which expects `implementing`. Auto-advancing here would wedge the workflow (reviewer's phase gate would block).
- If the user wants to inspect the fix before re-review, they can — the phase stays at `implementing` indefinitely. `/lean-spec:submit-review` is explicit, not automatic.
