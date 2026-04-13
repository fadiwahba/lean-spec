---
name: review
description: Run the review phase for a lean-spec feature using the Architect agent.
---

Run the manual lean-spec review phase for the feature slug in `$ARGUMENTS`.

Rules:
- Require a slug. If no slug is provided, ask for one.
- Read:
  - `lean-spec/features/<slug>/spec.md`
  - `lean-spec/features/<slug>/notes.md`
  - `lean-spec/features/<slug>/review.md`
  - relevant changed source files
- The Architect agent owns `review.md`.
- The Architect agent must review against `spec.md`, `notes.md`, and the implementation diff.
- The Architect agent must write concrete findings, risks, regressions, and missing tests into `review.md`.
- The Architect agent must not implement code changes in this workflow.
- Stop after the review pass is complete.
- Do not continue to fixes automatically. The human decides whether to run `/implement` again or `/end`.

Tasks:
1. Confirm the feature folder exists.
2. Read the current spec, notes, review ledger, and relevant code changes.
3. Delegate formal review to `architect`.
4. Update `review.md` with findings and dispositions.
5. Report concise phase status back to the human, including:
   - number of open findings
   - whether the review is clean
   - whether `notes.md` suggests follow-up work
   - the likely next manual command: `/implement <slug>` or `/end <slug>`
