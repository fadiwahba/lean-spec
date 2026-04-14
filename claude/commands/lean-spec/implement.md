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
- Use `Context7` before implementation when external APIs, libraries, frameworks, or tool behavior matter.
- Use `sequential-thinking` before implementation when the work is multi-step, risky, or ambiguous.
- The Coder agent must implement from `spec.md`.
- If `review.md` contains open findings, the Coder agent should address those findings as part of this phase.
- For frontend/UI work, use Playwright or equivalent browser validation before reporting implementation complete, unless it is explicitly unavailable.
- If Playwright is used, close any opened browser, context, or page before ending the phase.
- Do not save Playwright screenshots into the project root. Use a dedicated artifact folder if captures are needed.
- If you start a local dev server or open a validation port, stop it before ending the phase. Use a project-approved cleanup command such as `npx kill-port 3000` when needed.
- The Coder agent must not rewrite `spec.md` or `review.md`.
- The Coder agent must not update `spec.md` status, checklist items, or timestamps during implementation.
- If scope is unclear or blocked, record that in `notes.md`.
- Stop when the implementation pass is complete.
- Do not continue to review automatically. The human must explicitly run `/lean-spec:review`.
- Do not claim implementation complete unless the required tool usage and artifact ownership rules above were satisfied.

Tasks:
1. Confirm the feature folder exists.
2. Read the current spec and relevant repo files.
3. Delegate implementation to `coder`.
4. Have the Coder agent record blockers, deviations, or reviewer guidance in `notes.md`.
5. Report concise phase status back to the human, including:
   - implementation complete / partial / blocked
   - whether `notes.md` was updated
   - whether `Context7`, `sequential-thinking`, and Playwright were used or unavailable
   - whether open review findings remain
   - that the next likely manual phase is `/lean-spec:review <slug>` when ready
