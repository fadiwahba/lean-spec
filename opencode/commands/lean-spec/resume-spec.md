---
description: Rebuild lean-spec implementation context for a feature
agent: lean-spec-coder
subtask: true
---

Follow `AGENTS.md` and `.opencode/LEAN_SPEC_INSTRUCTIONS.md`.

Resume lean-spec state for feature slug: `$ARGUMENTS`

Requirements:
- read in this order:
  - `lean-spec/features/$ARGUMENTS/spec.md`
  - `lean-spec/features/$ARGUMENTS/notes.md`
  - `lean-spec/features/$ARGUMENTS/review.md`
- rebuild implementation context from canonical artifacts only
- do not make code changes before the state report
- stop after the report unless the human explicitly asks to continue
