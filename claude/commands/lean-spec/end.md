---
name: end
description: End a lean-spec feature by reconciling the final artifact state and closing the workflow when it is truly clean.
---

Run the manual lean-spec end phase for the feature slug in `$ARGUMENTS`.

Rules:
- Require a slug. If no slug is provided, ask for one.
- Read:
  - `lean-spec/features/<slug>/spec.md`
  - `lean-spec/features/<slug>/notes.md`
  - `lean-spec/features/<slug>/review.md`
- The default session agent owns workflow closure and status reporting.
- The human running `/end <slug>` is the explicit request to perform final closure cleanup.
- `/end` must not close a feature that still has open notes or open review findings.
- Before writing closure updates, retrieve the current timestamp from the shell with a command such as `date "+%Y-%m-%d %H:%M %Z"`.
- Use the shell-fetched timestamp for all final artifact updates in the same closure pass.
- Do not invent, estimate, hardcode, or round timestamps.

Tasks:
1. Confirm the feature folder exists.
2. Read the current `spec.md`, `notes.md`, and `review.md`.
3. If open notes or open findings remain, stop and report that closure is blocked.
4. If the feature is clean:
   - update `spec.md`:
     - verify the checklist and status are already mostly reconciled from prior review passes
     - set `Status` to `completed`
     - complete only any remaining closure-safe checklist reconciliation
     - update `Updated At`
     - append a final change-log line
   - update `notes.md` and `review.md`:
     - update `Updated At`
5. Report the final reconciled state back to the human.

Report:
- final feature status from `spec.md`
- remaining unchecked tasks
- open notes
- open review findings
- whether closure was completed
- any follow-up command only if closure was blocked

Keep the response compact and operational.
