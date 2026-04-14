---
description: Amend an existing lean-spec specification with the Architect agent
agent: lean-spec-architect
subtask: true
---

Follow `AGENTS.md` and `.opencode/LEAN_SPEC_INSTRUCTIONS.md`.

Run the lean-spec spec-update phase for feature slug: `$ARGUMENTS`

Requirements:
- read `lean-spec/features/$ARGUMENTS/spec.md`, `notes.md`, and `review.md`
- use this phase when scope, constraints, UX direction, acceptance criteria, or requirements changed after planning
- the orchestrator must not revise `spec.md` directly; the Architect owns the spec amendment
- before editing `spec.md`, fetch one shell-backed timestamp with:
  - `date "+%Y-%m-%d %H:%M %Z"`
- update `spec.md` only; do not implement code in this phase
- revise goal, scope, constraints, implementation notes, checklist, acceptance criteria, status, and change log as needed
- stop after the revised `spec.md` is ready for the next human-directed phase

End by reporting:
- that `spec.md` was revised by the Architect
- whether the revised spec implies another `/lean-spec:implement-spec $ARGUMENTS` pass
- whether the next likely manual phase is implementation or review
