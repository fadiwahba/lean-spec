---
description: Verify APPROVE verdict and close the feature lifecycle
argument-hint: <slug>
allowed-tools: Read
---

# /lean-spec:close-spec

The `UserPromptSubmit` hook has already validated the verdict and advanced `workflow.json` to `closed` before this command runs. Your job is to confirm the outcome to the user.

## Steps

1. Check the hook's injected context (from `additionalContext`):
   - If it says the feature has been closed: proceed to Step 2.
   - If it says an error occurred: relay the error verbatim and stop.

2. Confirm to the user:

   > "Feature '$ARGUMENTS' is closed. Lifecycle complete."

   Print a summary:
   - Spec:   `features/$ARGUMENTS/spec.md`
   - Notes:  `features/$ARGUMENTS/notes.md`
   - Review: `features/$ARGUMENTS/review.md`
   - Verdict: APPROVE
