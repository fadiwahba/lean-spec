---
name: review
description: Advances an implemented feature to reviewing and dispatches the reviewer agent to write review.md with a verdict. Use --visual for UI/UX specs to capture Playwright screenshot evidence.
disable-model-invocation: true
---

# /lean-spec:review <slug> [--visual]

## Steps

1. `bin/lean-spec advance <slug> implementing reviewing` — the state
   transition. Stop and surface the CLI's message on failure.
2. Dispatch the `reviewer` agent via Task, with `.lean-spec/CONSTITUTION.md`
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
   With `--visual`, additionally confirm every cited screenshot file
   exists under `.lean-spec/features/<slug>/evidence/visual/` and that a
   `## Visual Fidelity` section is present — if either is missing, the
   review is incomplete; dispatch the reviewer again.
4. Report the verdict to the user. Do **not** decide what happens next
   yourself — run `bin/lean-spec next <slug>` and follow its routing
   (`/lean-spec:close` on APPROVE, `/lean-spec:fix` on NEEDS_FIXES, or
   report BLOCKED and stop).
5. Commit: `review(<slug>): <verdict>`.

## Never does

- Let the reviewer fix code — findings only, in `review.md`.
- Infer the next step from the verdict text itself — always route through
  `bin/lean-spec next <slug>`.
- Accept `--visual` evidence saved outside
  `.lean-spec/features/<slug>/evidence/visual/` or not cited in `review.md`.
