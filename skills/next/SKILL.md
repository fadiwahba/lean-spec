---
name: next
description: Read-only — reports the next lifecycle step for a feature (or every feature with --all), by calling bin/lean-spec next. Safe to invoke any time; makes no state changes.
---

# `next` [<slug>|--all]

Passthrough to the CLI resolver — this skill contains no routing logic of
its own (the CLI decides; see `bin/lean-spec`'s `resolve_next`).

## Steps

1. No argument or a `<slug>`: run `bin/lean-spec next <slug>`. Report its
   output verbatim: the named skill to dispatch next, or, for `reviewing`
   phase, whichever of `close`, `fix`, or a
   `BLOCKED`/missing-verdict report applies; or `closed — nothing to do`.
2. `--all`: run `bin/lean-spec next --all` and report the per-feature
   list.
3. Do not dispatch the named skill yourself unless the user asks you to
   act on it — this command only reports.

## Never does

- Decide routing from `review.md` prose itself — always defer to the
  CLI's verdict parsing.
- Mutate `workflow.json` or any artifact.
