---
description: Review a lean-spec feature with the Architect agent
agent: lean-spec-architect
subtask: true
---

Follow `AGENTS.md` and `.opencode/LEAN_SPEC_INSTRUCTIONS.md`.

Run the lean-spec review phase for feature slug: `$ARGUMENTS`

Requirements:
- read:
  - `lean-spec/features/$ARGUMENTS/spec.md`
  - `lean-spec/features/$ARGUMENTS/notes.md`
  - `lean-spec/features/$ARGUMENTS/review.md`
  - relevant changed source files
- use `context7` before review when external library, framework, or tool behavior matters
- use `sequential_thinking` before review when the work is multi-step, risky, or ambiguous
- review against the implementation and the current spec
- for frontend/UI review, use `playwright` before reporting the review complete, unless it is explicitly unavailable
- if `playwright` is used, close any opened browser, context, or page before ending the phase
- do not save Playwright screenshots into the project root; use a dedicated artifact folder if captures are needed
- update `review.md` with concrete findings and dispositions
- reconcile `spec.md` during review so checklist progress and status match the reviewed implementation
- do not leave non-defect process notes as open findings
- do not implement code in this phase
- stop after the review pass

End by reporting:
- number of open findings
- whether the review is clean
- whether `context7`, `sequential_thinking`, and `playwright` were used or unavailable
- whether the next likely manual phase is `/lean-spec:implement $ARGUMENTS` or `/lean-spec:end $ARGUMENTS`
