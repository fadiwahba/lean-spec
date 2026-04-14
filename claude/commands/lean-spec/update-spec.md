---
name: update-spec
description: Amend an existing lean-spec specification with the Architect agent.
---

Run the manual lean-spec spec-update phase for the feature slug in `$ARGUMENTS`.

Rules:
- Require a slug. If no slug is provided, ask for one.
- Read:
  - `lean-spec/features/<slug>/spec.md`
  - `lean-spec/features/<slug>/notes.md`
  - `lean-spec/features/<slug>/review.md`
  - only the minimum relevant repository context needed to update the spec correctly
- The default session agent remains the orchestrator. It owns routing and concise status reporting only.
- The Architect agent owns `spec.md`.
- The orchestrator must not revise `spec.md` directly, even when the requested change looks small or obvious.
- Use this command when scope, constraints, UX direction, acceptance criteria, or requirements changed after the original planning phase.
- `notes.md` and `review.md` should not be rewritten in this phase unless the Architect needs to reference their existing state while updating `spec.md`.
- Before editing `spec.md`, retrieve the current timestamp from the shell with a command such as `date "+%Y-%m-%d %H:%M %Z"`.
- Update `spec.md` so it reflects the new direction honestly:
  - goal and scope
  - constraints
  - implementation notes
  - task checklist
  - acceptance criteria
  - status and change log, if needed
- Stop after the Architect has updated `spec.md`.
- Do not continue to implementation automatically. The human must explicitly run `/lean-spec:implement-spec`, `/lean-spec:review-spec`, `/lean-spec:spec-status`, `/lean-spec:resume-spec`, or `/lean-spec:close-spec` next as needed.

Tasks:
1. Confirm the feature folder exists.
2. Read the current `spec.md`, `notes.md`, and `review.md`.
3. Retrieve the current timestamp from the shell.
4. Delegate the spec amendment to `architect`.
5. Ensure `spec.md` is updated for the new direction without implementation work.
6. Report concise completion status back to the human, including:
   - that `spec.md` was revised by `architect`
   - whether the revised spec implies another `/lean-spec:implement-spec <slug>` pass
   - whether the feature is now waiting on implementation or review
