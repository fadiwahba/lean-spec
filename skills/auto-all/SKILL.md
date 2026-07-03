---
name: auto-all
description: Drives every non-closed feature to closed, sequentially, one .lean-spec/auto.json at a time. Does not spec new features — only drains what already has a spec. A BLOCKED verdict stops the whole chain and escalates.
disable-model-invocation: true
---

# /lean-spec:auto-all [--gates-on]

Same hook-owned mechanism as `/lean-spec:auto`, with `chain_all: true` so
`hooks/stop-auto-driver.sh` picks the next non-closed feature (sorted by
slug) instead of stopping when one closes.

## Steps

1. Find the first non-closed feature: `bin/lean-spec status --json` (or
   `next --all --json`), pick the first whose `phase` isn't `closed`. If
   none exist, report that and stop — this skill never runs
   `/lean-spec:spec` to create new work.
2. Write `.lean-spec/auto.json`:
   ```json
   {"slug": "<first-non-closed-slug>", "gates_on": <true|false>, "max_cycles": 20, "cycles": 0, "chain_all": true}
   ```
3. Run `bin/lean-spec next <slug>` once yourself and dispatch the named
   skill, same as `/lean-spec:auto`'s first step.
4. From here, `hooks/stop-auto-driver.sh` drives every phase for every
   feature in sequence: on each `closed` outcome it looks for the next
   non-closed feature and rewrites `auto.json` to target it (resetting
   `cycles` to 0); when none remain it removes `auto.json` and allows the
   stop. A `BLOCKED` verdict or a `max_cycles` cap on any single feature
   stops the *entire* chain immediately (it does not skip ahead to the
   next feature) — this matches the CONSTITUTION's "BLOCKED verdicts stop
   the line and escalate to Fady."

## Never does

- Spec a new feature — only drains features that already have a
  `spec.md`/`workflow.json`.
- Run two features concurrently — `chain_all` always drives exactly one
  `auto.json` at a time (PRD R9).
- Skip past a BLOCKED feature to keep draining the rest.
