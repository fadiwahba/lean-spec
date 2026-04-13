---
description: Plan a lean-spec feature with the Architect agent
agent: lean-spec-architect
subtask: true
---

Follow `AGENTS.md` and `.opencode/LEAN_SPEC_INSTRUCTIONS.md`.

Run the lean-spec planning phase for feature slug: `$ARGUMENTS`

Requirements:
- use `.opencode/lean-spec/templates/` as the template source
- ensure `lean-spec/features/$ARGUMENTS/` exists
- scaffold:
  - `spec.md`
  - `notes.md`
  - `review.md`
- if files already exist, reuse them and do not overwrite blindly
- before writing scaffold files, fetch one shell-backed timestamp with:
  - `date "+%Y-%m-%d %H:%M %Z"`
- replace placeholder timestamps and obvious feature placeholders
- write or update the real implementation plan in `spec.md`
- do not implement code in this phase
- stop after `spec.md` is ready for human review

End by reporting:
- feature folder path
- whether files were created or reused
- whether `spec.md` is ready for review
- that the next likely manual phase is `/lean-spec:implement $ARGUMENTS`
