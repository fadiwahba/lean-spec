---
name: auto-all
description: Drives every non-closed feature to closed, sequentially, one .lean-spec/auto.json at a time. With --no-confirm, also chains into speccing the next slice (one at a time, sentinel-terminated) instead of stopping when nothing's left to drain. A BLOCKED verdict stops the whole chain and escalates.
---

# `auto-all` [--gates-on] [--no-confirm] [--max-features=N]

Same CLI-owned mechanism as `auto`, with `chain_all: true` so
`bin/lean-spec auto tick` picks the next non-closed feature (sorted by slug)
instead of stopping when one closes. The Stop hook only forwards its event to
that CLI command.

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
     runs `spec` to create new work.
   - **`--no-confirm` set (cold start):** before writing `auto.json` at
     all, inline the exact same flow that `spec --no-confirm`
     defines — **run its `## Preflight (fail-loud)` section first** (this
     is the one entry point where the PRD is most likely still an
     unfilled `init` skeleton, so skipping it is not safe
     here), then its "Determine the slug" propose → sentinel-check →
     `ensure` → architect-write flow. If the preflight fails, stop and
     show the CLI's one-line message verbatim, same as `spec`
     would. If
     the propose dispatch returns `NO_REMAINING_SCOPE`: report that the PRD
     has nothing to spec and stop; do not write `auto.json`. If the response
     is malformed, stop with `NEEDS_INPUT`; never infer completion. Otherwise the
     newly-specced slug becomes `<first-non-closed-slug>` below and you
     continue to step 2.
2. Arm the driver via the CLI — **never write the file yourself**:
   ```
   bin/lean-spec auto arm <first-non-closed-slug> --chain-all [--gates-on] \
       [--no-confirm [--max-features=N]]
   ```
   The CLI owns `.lean-spec/auto.json`'s schema, defaults, provenance and
   atomic write; it emits `no_confirm`/`max_features`/`features_specced`
   only when `--no-confirm` is passed (today's exact shape, unchanged). A
   direct `Write`/`Edit` of that path is denied by
   `hooks/pre-tool-use-guard.sh`.
3. Run `bin/lean-spec next <slug>` once yourself and dispatch the named
   skill, same as `auto`'s first step.
4. From here, `hooks/stop-auto-driver.sh` drives every phase for every
   feature in sequence: on each `closed` outcome it looks for the next
   non-closed feature and rewrites `auto.json` to target it (resetting
   `cycles` to 0). When none remain **and `--no-confirm` is not set**, it
   removes `auto.json` and allows the stop. **When `--no-confirm` is
   set** and none remain, the hook instead (bounded by `max_features`)
   points you at `spec --no-confirm` for the next slice before
   falling back to the same stop once the cap is hit or the PRD is fully
   covered. Only if that architect response is exactly `NO_REMAINING_SCOPE`,
   run the exact `bin/lean-spec auto complete --run-id <id> --no-remaining-scope`
   command supplied by the continuation reason. This records `COMPLETE` in
   CLI-owned state; never delete or edit `auto.json` directly. A `BLOCKED`
   verdict or a `max_cycles` cap on any single
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
- Write, edit, or delete `.lean-spec/auto.json` by hand (including via a
  Bash heredoc or `rm`) — including re-arming a chain the user paused, or
  arming one on a `spec_next` poke. Use `bin/lean-spec auto arm`/`auto
  disarm`, and only when the user asked for it.
