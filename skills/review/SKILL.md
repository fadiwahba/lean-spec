---
name: review
description: Advances an implemented feature to reviewing and dispatches the reviewer agent to write review.md with a verdict. Use --visual for UI/UX specs to capture Playwright screenshot evidence.
---

# `review` <slug> [--visual]

## Steps

1. `bin/lean-spec advance <slug> implementing reviewing [--visual]` — the
   state transition. Pass `--visual` when requested. This records the visual
   evidence gate in CLI-owned feature state. Stop and surface the CLI's
   message on failure.
2. Give the active host adapter the explicit work identity, then dispatch the
   `reviewer` agent as a subagent, with `.lean-spec/CONSTITUTION.md`
   injected, `.lean-spec/features/<slug>/spec.md`, and `.lean-spec/features/<slug>/notes.md`
   (including its `## TDD` evidence). Pass `--visual` through when given —
   the reviewer then drives the running app with a browser scripted
   through `Bash` (e.g. a Playwright CLI script) and saves screenshots
   under `.lean-spec/features/<slug>/evidence/visual/`.
3. `SubagentStop` validates `review.md` automatically (verdict line
   present and valid) when the reviewer finishes. Backstop:
   ```
   bin/lean-spec validate <slug> review.md
   ```
   When the transition used `--visual`, this CLI validation requires a
   `## Visual Fidelity` section and a cited file below
   `.lean-spec/features/<slug>/evidence/visual/`. If it fails, dispatch the
   reviewer again.
4. Report the verdict to the user. Do **not** decide what happens next
   yourself — run `bin/lean-spec next <slug>` and follow its routing
   (`close` on APPROVE, `fix` on NEEDS_FIXES, or
   report BLOCKED and stop).
5. Commit: `review(<slug>): <verdict>`.

## Never does

- Let the reviewer fix code — findings only, in `review.md`.
- Infer the next step from the verdict text itself — always route through
  `bin/lean-spec next <slug>`.
- Accept `--visual` evidence saved outside
  `.lean-spec/features/<slug>/evidence/visual/` or not cited in `review.md`.
