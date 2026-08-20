---
name: close
description: Closes a reviewed feature. Gated entirely by bin/lean-spec advance — the CLI refuses to close without an APPROVE verdict; there is no manual override.
disable-model-invocation: true
---

# /lean-spec:close <slug>

## Steps

1. `bin/lean-spec advance <slug> reviewing closed`. This single call is
   the whole gate: the CLI itself refuses the transition unless
   `.lean-spec/features/<slug>/review.md` has `verdict: APPROVE` (or whatever
   `.lean-spec/rules.toml`'s `[defaults].required_verdict` is set to) —
   see CONSTITUTION "close requires verdict: APPROVE. No manual override
   path exists." If it fails, stop and show the CLI's message; there is
   no prompt-level override.
2. Commit: `chore(<slug>): close`.
3. Report closure to the user. If driven by `/lean-spec:auto`, the Stop
   hook removes `.lean-spec/auto.json` here and stops — auto mode drives
   exactly one feature to `closed`, then ends; do not tell the user
   another slice will start on its own. Only `/lean-spec:auto-all` (which
   sets `chain_all: true`, independent of `--gates-on`) picks the next
   non-closed feature and keeps driving. Otherwise: tell the user to run
   `/lean-spec:spec` for the next slice.

## Never does

- Check the verdict itself in prose and decide to proceed anyway — the
  gate lives in `bin/lean-spec advance`, not this skill.
- Close a feature that isn't in `reviewing` phase.
