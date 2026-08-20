---
name: fix
description: Runs the NEEDS_FIXES loop — moves a feature back to implementing and dispatches the coder to address the reviewer's findings, appending a new ## Cycle N section to notes.md.
---

# `fix` <slug>

Only meaningful when `bin/lean-spec next <slug>` says so (i.e.
`review.md`'s verdict is `NEEDS_FIXES`). Don't call this speculatively.

## Steps

1. `bin/lean-spec advance <slug> reviewing implementing`. The CLI gates
   this transition on `review.md`'s verdict being `NEEDS_FIXES` (APPROVE
   routes to close, BLOCKED stops the line, a missing verdict is not a
   fix) — so a wrong call fails loudly here rather than silently
   re-opening an approved or blocked feature.
2. Give the active host adapter the explicit work identity, then dispatch the
   `coder` agent as a subagent, with `.lean-spec/CONSTITUTION.md`
   injected, `.lean-spec/features/<slug>/spec.md`, and `.lean-spec/features/<slug>/review.md`'s
   findings. The coder appends a new `## Cycle N` section to
   `.lean-spec/features/<slug>/notes.md` rather than rewriting history, addressing
   each finding with TDD unless the feature opted out at `implement`.
3. Backstop validate:
   ```
   bin/lean-spec validate <slug> notes.md
   ```
4. Commit: `fix(<slug>): cycle N — <summary>`.
5. Tell the user to run `review <slug>` next (or `auto`
   to let the Stop-hook driver do it).

## Never does

- Edit `review.md` — the fix cycle doesn't erase the reviewer's findings;
  the next `review` writes a fresh verdict.
- Skip straight to `closed` — every fix cycle goes back through review.
