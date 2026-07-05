---
name: auto-all
description: Drives every non-closed feature to closed, sequentially, one .lean-spec/auto.json at a time. With --no-confirm, also chains into speccing the next slice (one at a time, sentinel-terminated) instead of stopping when nothing's left to drain. A BLOCKED verdict stops the whole chain and escalates.
disable-model-invocation: true
---

# /lean-spec:auto-all [--gates-on] [--no-confirm] [--max-features=N]

Same hook-owned mechanism as `/lean-spec:auto`, with `chain_all: true` so
`hooks/stop-auto-driver.sh` picks the next non-closed feature (sorted by
slug) instead of stopping when one closes.

`--no-confirm` additionally chains into speccing the *next* slice — one
at a time, never batch-decomposed (R8 unchanged) — instead of stopping
when no non-closed feature remains, so a whole small/simple PRD can run
hands-off from a single command. `--max-features=N` caps the total
number of slices auto-specced in one run (default 20, independent from
`--max-cycles`'s per-feature fix-loop cap). Omit `--no-confirm` and this
skill behaves exactly as it always has: drains only what already has a
`spec.md`, never specs new work.

## Steps

1. Find the first non-closed feature: `bin/lean-spec status --json` (or
   `next --all --json`), pick the first whose `phase` isn't `closed`.
   **If none exist:**
   - **`--no-confirm` not set:** report that and stop — this skill never
     runs `/lean-spec:spec` to create new work.
   - **`--no-confirm` set (cold start):** before writing `auto.json` at
     all, inline the exact same flow that `/lean-spec:spec --no-confirm`
     defines — **run its `## Preflight (fail-loud)` section first** (this
     is the one entry point where the PRD is most likely still an
     unfilled `/lean-spec:init` skeleton, so skipping it is not safe
     here), then its "Determine the slug" propose → sentinel-check →
     `ensure` → architect-write flow. If the preflight fails, stop and
     show the CLI's one-line message verbatim, same as `/lean-spec:spec`
     would. If
     the propose dispatch returns `NO_REMAINING_SCOPE` (or an unparseable
     response — treat it the same, fail-safe): report that the PRD has
     nothing to spec and stop; do not write `auto.json`. Otherwise the
     newly-specced slug becomes `<first-non-closed-slug>` below and you
     continue to step 2.
2. Write `.lean-spec/auto.json`:
   ```json
   {"slug": "<first-non-closed-slug>", "gates_on": <true|false>, "max_cycles": 20, "cycles": 0, "chain_all": true, "no_confirm": <true|false>, "max_features": <N, default 20>, "features_specced": 0}
   ```
   `no_confirm`/`max_features`/`features_specced` are only meaningful
   when `--no-confirm` is set; omit them when it isn't (today's exact
   shape, unchanged).
3. Run `bin/lean-spec next <slug>` once yourself and dispatch the named
   skill, same as `/lean-spec:auto`'s first step.
4. From here, `hooks/stop-auto-driver.sh` drives every phase for every
   feature in sequence: on each `closed` outcome it looks for the next
   non-closed feature and rewrites `auto.json` to target it (resetting
   `cycles` to 0). When none remain **and `--no-confirm` is not set**, it
   removes `auto.json` and allows the stop. **When `--no-confirm` is
   set** and none remain, the hook instead (bounded by `max_features`)
   points you at `/lean-spec:spec --no-confirm` for the next slice before
   falling back to the same stop once the cap is hit or the PRD is fully
   covered. A `BLOCKED` verdict or a `max_cycles` cap on any single
   feature stops the *entire* chain immediately (it does not skip ahead
   to the next feature) — this matches the CONSTITUTION's "BLOCKED
   verdicts stop the line and escalate to Fady."

## Never does

- Decompose the whole PRD upfront — even with `--no-confirm`, specs are
  written strictly one at a time, grounded in real closed-slice ACs
  (R8). `--no-confirm` automates the confirmation *cadence* between
  slices; it never batch-writes more than one `spec.md` in a single
  dispatch.
- Run two features concurrently — `chain_all` always drives exactly one
  `auto.json` at a time (PRD R9).
- Skip past a BLOCKED feature to keep draining the rest.
