---
name: fix
description: Runs the NEEDS_FIXES loop — moves a feature back to implementing and dispatches the coder to address the reviewer's findings, appending a new ## Cycle N section to notes.md.
disable-model-invocation: true
---

# /lean-spec:fix <slug>

Only meaningful when `bin/lean-spec next <slug>` says so (i.e.
`review.md`'s verdict is `NEEDS_FIXES`). Don't call this speculatively.

## Steps

1. `bin/lean-spec advance <slug> reviewing implementing`. The CLI gates
   this transition on `review.md`'s verdict being `NEEDS_FIXES` (APPROVE
   routes to close, BLOCKED stops the line, a missing verdict is not a
   fix) — so a wrong call fails loudly here rather than silently
   re-opening an approved or blocked feature.
2. Dispatch the `coder` agent via Task, with `docs/CONSTITUTION.md`
   injected, `features/<slug>/spec.md`, and `features/<slug>/review.md`'s
   findings. The coder appends a new `## Cycle N` section to
   `features/<slug>/notes.md` rather than rewriting history, addressing
   each finding with TDD unless the feature opted out at `/lean-spec:implement`.
3. Backstop validate:
   ```
   bin/lean-spec validate <slug> notes.md
   ```
4. Commit: `fix(<slug>): cycle N — <summary>`.
5. Tell the user to run `/lean-spec:review <slug>` next (or `/lean-spec:auto`
   to let the Stop-hook driver do it).

## Never does

- Edit `review.md` — the fix cycle doesn't erase the reviewer's findings;
  the next `/lean-spec:review` writes a fresh verdict.
- Skip straight to `closed` — every fix cycle goes back through review.
