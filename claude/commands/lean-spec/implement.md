---
name: implement
description: Run the implementation phase for a lean-spec feature using the Coder agent.
---

Run the manual lean-spec implementation phase for the feature slug in `$ARGUMENTS`.

Rules:
- Require a slug. If no slug is provided, ask for one.
- Read:
  - `lean-spec/features/<slug>/spec.md`
  - `lean-spec/features/<slug>/notes.md`
  - `lean-spec/features/<slug>/review.md`
- The Coder agent owns code implementation and `notes.md`.
- The Coder agent must implement from `spec.md`.
- If `review.md` contains open findings, the Coder agent should address those findings as part of this phase.
- The Coder agent must not rewrite `spec.md` or `review.md`.
- If scope is unclear or blocked, record that in `notes.md`.
- Stop when the implementation pass is complete.
- Do not continue to review automatically. The human must explicitly run `/review`.

Tasks:
1. Confirm the feature folder exists.
2. Read the current spec and relevant repo files.
3. Delegate implementation to `coder`.
4. Have the Coder agent record blockers, deviations, or reviewer guidance in `notes.md`.
5. Report concise phase status back to the human, including:
   - implementation complete / partial / blocked
   - whether `notes.md` was updated
   - whether open review findings remain
   - that the next likely manual phase is `/review <slug>` when ready
