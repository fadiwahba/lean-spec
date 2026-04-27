---
description: Verify APPROVE verdict and close the feature lifecycle
argument-hint: <slug>
allowed-tools: Read, Write
---

# /lean-spec:close-spec

Verify the review verdict is `APPROVE`, then close the feature by updating `workflow.json` directly with the Write tool. **There is no `lean-spec` CLI — do not search for one, install one, or run any npm/npx command.**

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Read `features/$ARGUMENTS/workflow.json` and verify current phase is `reviewing`. If not, say: "Phase gate: expected 'reviewing', got '<phase>'."
4. Read `features/$ARGUMENTS/review.md`. Verify verdict is `APPROVE`. If not, say: "Cannot close: verdict is '<verdict>'. Resolve before closing."

## Steps

1. Read `features/$ARGUMENTS/workflow.json` to capture the existing content (you have it from pre-flight).

2. Compute the updated workflow object — make these three changes to the existing JSON:
   - `phase` → `"closed"`
   - `updated_at` → current UTC timestamp, format `YYYY-MM-DDTHH:MM:SSZ`
   - `history` → append `{"phase": "closed", "entered_at": "<same timestamp>"}`
   All other fields stay exactly as they are.

3. Write the updated JSON back to `features/$ARGUMENTS/workflow.json` using the **Write tool** (full file replacement). Use 2-space indentation. Example of the shape:
   ```json
   {
     "slug": "...",
     "phase": "closed",
     "created_at": "...",
     "updated_at": "<now>",
     "history": [
       ...,
       {"phase": "closed", "entered_at": "<now>"}
     ],
     "artifacts": { ... }
   }
   ```

4. Read `features/$ARGUMENTS/workflow.json` again and confirm `.phase` is `"closed"`. If not, report: "ERROR: phase did not advance — Write tool may have failed."

5. Confirm to the user:
   "Feature '$ARGUMENTS' is closed. Artifacts preserved at features/$ARGUMENTS/. Lifecycle complete."
   Print a summary:
   - Spec: features/$ARGUMENTS/spec.md
   - Notes: features/$ARGUMENTS/notes.md
   - Review: features/$ARGUMENTS/review.md
   - Verdict: APPROVE
