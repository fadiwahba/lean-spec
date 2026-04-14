---
description: Show the current lean-spec implementation status for a feature
agent: lean-spec-coder
subtask: true
---

Follow `AGENTS.md` and `.opencode/LEAN_SPEC_INSTRUCTIONS.md`.

Summarize lean-spec status for feature slug: `$ARGUMENTS`

Requirements:
- read only:
  - `lean-spec/features/$ARGUMENTS/spec.md`
  - `lean-spec/features/$ARGUMENTS/notes.md`
  - `lean-spec/features/$ARGUMENTS/review.md`
- infer the current implementation-side state from those artifacts only
- do not make code changes
- keep the output compact and operational
