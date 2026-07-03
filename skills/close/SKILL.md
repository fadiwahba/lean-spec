---
name: close
description: Closes a reviewed feature. Gated entirely by bin/lean-spec advance — the CLI refuses to close without an APPROVE verdict; there is no manual override.
disable-model-invocation: true
---

# /lean-spec:close <slug>

## Steps

1. `bin/lean-spec advance <slug> reviewing closed`. This single call is
   the whole gate: the CLI itself refuses the transition unless
   `features/<slug>/review.md` has `verdict: APPROVE` (or whatever
   `.lean-spec/rules.toml`'s `[defaults].required_verdict` is set to) —
   see CONSTITUTION "close requires verdict: APPROVE. No manual override
   path exists." If it fails, stop and show the CLI's message; there is
   no prompt-level override.
2. Commit: `chore(<slug>): close`.
3. Report closure to the user. If driven by `/lean-spec:auto` /
   `/lean-spec:auto-all`, the Stop hook takes it from here (chains to the
   next feature under `--gates-on` auto-all, or stops).

## Never does

- Check the verdict itself in prose and decide to proceed anyway — the
  gate lives in `bin/lean-spec advance`, not this skill.
- Close a feature that isn't in `reviewing` phase.
