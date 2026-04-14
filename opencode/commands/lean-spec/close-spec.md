---
description: Finalize and close a lean-spec feature with the Architect agent
agent: lean-spec-architect
subtask: true
---

Follow `AGENTS.md` and `.opencode/LEAN_SPEC_INSTRUCTIONS.md`.

Run the lean-spec end phase for feature slug: `$ARGUMENTS`

Requirements:
- read:
  - `lean-spec/features/$ARGUMENTS/spec.md`
  - `lean-spec/features/$ARGUMENTS/notes.md`
  - `lean-spec/features/$ARGUMENTS/review.md`
- block closure if open notes or open findings remain
- before writing closure updates, fetch one shell-backed timestamp with:
  - `date "+%Y-%m-%d %H:%M %Z"`
- reconcile `spec.md`
- refresh artifact timestamps
- append the final change-log line in `spec.md`
- stop after reporting the final reconciled state

End by reporting:
- final feature status
- remaining unchecked tasks
- open notes
- open review findings
- whether closure was completed
