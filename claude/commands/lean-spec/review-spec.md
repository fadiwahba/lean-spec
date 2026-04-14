---
name: review-spec
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
- Use `Context7` before review when external APIs, libraries, frameworks, or tool behavior matter.
- Use `sequential-thinking` before review when the work is multi-step, risky, or ambiguous.
- The Architect agent must review against `spec.md`, `notes.md`, and the implementation diff.
- For frontend/UI review, use Playwright or equivalent browser validation before reporting the review complete, unless it is explicitly unavailable.
- If Playwright is used, close any opened browser, context, or page before ending the phase.
- Do not save Playwright screenshots into the project root. Save any screenshots or captures only under `lean-spec/features/<slug>/artifacts/`.
- If you start a local dev server or open a validation port, stop it before ending the phase. Use a project-approved cleanup command such as `npx kill-port 3000` when needed.
- The Architect agent must write concrete findings, risks, regressions, and missing tests into `review.md`.
- The Architect agent must also reconcile `spec.md` during review so the checklist and status stay aligned with the reviewed implementation state.
- Non-defect process notes or coverage notes must not remain as open findings. Record them as accepted/deferred dispositions or as neutral notes instead.
- The Architect agent must not implement code changes in this workflow.
- Stop after the review pass is complete.
- Do not continue to fixes automatically. The human decides whether to run `/lean-spec:implement-spec` again or, after a clean/dispositioned review, `/lean-spec:close-spec`.
- Do not claim review complete unless the required tool usage above was satisfied.

Tasks:
1. Confirm the feature folder exists.
2. Read the current spec, notes, review ledger, and relevant code changes.
3. Delegate formal review to `architect`.
4. Update `review.md` with findings and dispositions.
5. Reconcile `spec.md`:
   - check completed checklist items
   - leave incomplete or still-failing items unchecked
   - update `Updated At`
   - keep status aligned with the reviewed state
6. Report concise phase status back to the human, including:
   - number of open findings
   - whether the review is clean
   - whether `Context7`, `sequential-thinking`, and Playwright were used or unavailable
   - whether `notes.md` suggests follow-up work
   - the likely next manual command:
     - `/lean-spec:implement-spec <slug>` when real open findings remain
     - `/lean-spec:close-spec <slug>` only when no open findings remain after resolution or disposition
