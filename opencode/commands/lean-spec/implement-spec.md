---
description: Implement a lean-spec feature as the OpenCode Coder companion
agent: lean-spec-coder
subtask: true
---

Follow `AGENTS.md` and `.opencode/LEAN_SPEC_INSTRUCTIONS.md`.

Run the lean-spec implementation phase for feature slug: `$ARGUMENTS`

Requirements:
- read `lean-spec/features/$ARGUMENTS/spec.md`
- read `lean-spec/features/$ARGUMENTS/notes.md`
- read `lean-spec/features/$ARGUMENTS/review.md`
- use `context7` before implementation when external library, framework, or tool behavior matters
- use `sequential_thinking` before implementation when the work is multi-step, risky, or ambiguous
- implement from `spec.md`
- if `review.md` contains open findings, address them in this implementation pass
- for frontend/UI work, use `playwright` before reporting implementation complete, unless it is explicitly unavailable
- if `playwright` is used, close any opened browser, context, or page before ending the phase
- do not save Playwright screenshots into the project root; use a dedicated artifact folder if captures are needed
- if you start a local dev server or open a validation port, stop it before ending the phase; use a project-approved cleanup command such as `npx kill-port 3000` when needed
- update `notes.md` with blockers, deviations, partial completion notes, and implementation-side resolutions
- before editing `notes.md`, fetch a real shell-backed timestamp with:
  - `date "+%Y-%m-%d %H:%M %Z"`
- do not edit `spec.md`
- do not edit `review.md`
- do not update `spec.md` status, checklist items, or timestamps during implementation
- stop after the implementation pass

End by reporting:
- implementation complete / partial / blocked
- whether `notes.md` changed
- whether `context7`, `sequential_thinking`, and `playwright` were used or unavailable
- whether Claude review is needed next
