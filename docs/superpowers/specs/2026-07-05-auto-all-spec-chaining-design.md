# auto-all spec-chaining — design

Status: approved by Fady, pending write-up review.

## Problem

Fady wanted a way to run a whole small/simple PRD hands-off. The
proposed idea was `/lean-spec:spec --all` — have the architect
batch-write every remaining feature's `spec.md` up front, so
`/lean-spec:auto-all` could then drain the whole pre-specced backlog
unattended.

**Rejected as literally proposed.** R8 ("no upfront decomposition — one
spec at a time") isn't an arbitrary rule; it's a lesson from v3
("pre-written specs go stale the moment a blocker refines the PRD").
Batch-writing spec #3 before #1/#2 are built means the architect guesses
at interfaces/state shape that don't exist yet, and loses the
"already-delivered ACs" grounding that makes today's one-at-a-time specs
accurate. That risk doesn't shrink for simple projects — it just fails
smaller.

## Chosen approach

Keep specs strictly one-at-a-time (R8 unchanged), but let
`/lean-spec:auto-all` **chain into speccing the next slice itself**, once
a feature closes and none remain, instead of stopping. This gets the
"walk away, come back to a finished project" ergonomics for simple
projects without ever writing a spec before its predecessor is real.

Opt-in via a new flag: `/lean-spec:auto-all --no-confirm [--max-features=N]`.
Without the flag, `/lean-spec:auto-all` is byte-for-byte unchanged
(drains only already-specced features, stops when none remain).

### Why `--no-confirm`, not `--spec-ahead`/`--gates-off`

- Mirrors the existing `/lean-spec:implement --no-tdd` naming pattern
  (negates one specific default-on behavior) rather than inventing a new
  style.
- Avoids colliding with the existing, already-reserved `--gates-on` flag
  on `auto`/`auto-all`, which is a different axis (stricter per-phase
  confirmation, currently a no-op) — reusing "gates" language here would
  make the two look like the same knob when they aren't.
- It's the single, precise thing being skipped: the no-arg `/lean-spec:spec`
  proposal's `AskUserQuestion` confirmation. There's no live user to
  answer it in an unattended Stop-hook-driven run anyway, so "enable
  chaining" and "skip confirmation" are the same decision — one flag,
  not two.

## Mechanism

The key insight: `stop-auto-driver.sh`'s existing `chain_all` logic
already rescans `features/*/workflow.json` (via `next_non_closed_slug`)
on every "closed" outcome to find the next feature to drive. A freshly
`/lean-spec:spec`'d feature creates exactly that — a new `workflow.json`
in `specifying` phase. So once the architect writes the new `spec.md`,
the *existing* chaining code picks it up automatically for the *ongoing*
drive (implement → review → close).

**One handoff-moment correction.** `subagent-stop-gate.sh` (the early
`SubagentStop` artifact gate) resolves the active feature from
`.lean-spec/auto.json`'s `slug` field first. During the chained-spec
write-dispatch, that field is still the *just-closed* feature (phase
`closed`, which the gate's `case` statement silently ignores) — so
without a correction, the early gate would resolve to the wrong feature
and silently skip validating the freshly-written `spec.md`, even though
the new feature's `workflow.json` already exists by then. So
`/lean-spec:spec --no-confirm`'s `ensure <new-slug>` step must also
update `auto.json`'s `slug` to the new slug at the same time, *before*
the architect is dispatched to write `spec.md` — mirroring the existing
precedent that `/lean-spec:auto`'s own step 2 already has the model write
`auto.json` directly. The rescan-on-next-cycle mechanism above still
applies as a backstop if that update is ever missed (same defense-in-depth
shape as the early gate + the skill's own backstop `validate` call).

### `.lean-spec/auto.json` — two new optional fields

```json
{
  "slug": "...", "gates_on": false, "max_cycles": 20, "cycles": 0,
  "chain_all": true,
  "no_confirm": true,
  "max_features": 20,
  "features_specced": 0
}
```

Written by `/lean-spec:auto-all --no-confirm [--max-features=N]` (default
`max_features` 20, mirroring `max_cycles`'s default). Absent `no_confirm`
→ these fields don't exist and nothing about existing behavior changes.

### `hooks/stop-auto-driver.sh` — one new branch

In the existing `action == "closed"` + `chain_all` handling, when
`next_non_closed_slug` returns `None` (today: stop, remove `auto.json`):

- If `no_confirm` is true **and** `features_specced < max_features`:
  increment `features_specced` (eagerly, same precedent as the existing
  unconditional `cycles` increment — the cap is a backstop, not a precise
  ledger), write `auto.json`, and emit a new `spec_next` decision leading
  to a distinct block reason (see below).
- Otherwise (no `no_confirm`, or cap reached): unchanged — stop, remove
  `auto.json`.

New block reason (analogous to the existing "read skills/<name>/SKILL.md"
reason from the disable-model-invocation fix):

> `lean-spec auto-all: no non-closed feature remains and --no-confirm is
> set (features_specced N/max_features M) — read skills/spec/SKILL.md now
> and follow its no-arg Steps yourself with --no-confirm (skip the
> AskUserQuestion) to propose and write the next slice. If the architect
> returns NO_REMAINING_SCOPE, delete .lean-spec/auto.json and stop —
> the PRD is fully covered. Otherwise, once you know the new slug, update
> .lean-spec/auto.json's "slug" to it (before dispatching the architect to
> write spec.md) so the early SubagentStop gate validates the right
> feature; the driver continues driving it normally from there.`

### Architect sentinel contract

`agents/architect.md`: in the no-arg proposal path, after cross-checking
the PRD against every closed slice's delivered ACs, if no scope remains
undelivered, the architect's **entire response is the literal string**
`NO_REMAINING_SCOPE` — nothing else. This is a machine-checked sentinel
the orchestrator string-compares against, not prose it has to interpret.

### `/lean-spec:spec --no-confirm`

`skills/spec/SKILL.md`: when `--no-confirm` is passed, skip the
`AskUserQuestion` proposal-confirmation step entirely and go straight to
`ensure` + architect dispatch. The existing R15 preflight
(`validate --project` on PRD/CONSTITUTION) still runs first, unchanged.
If the architect returns `NO_REMAINING_SCOPE`, the orchestrator deletes
`.lean-spec/auto.json` and stops instead of writing anything — this is
the terminal "PRD fully covered" condition for the whole `auto-all` run.

When driven by `auto-all` chaining specifically (i.e. `.lean-spec/auto.json`
exists with `chain_all`/`no_confirm` set), `ensure <new-slug>` and updating
`auto.json`'s `slug` to that new slug happen together, *before* the
architect is dispatched to write `spec.md` — see the handoff-moment
correction above. This step is a no-op when `/lean-spec:spec --no-confirm`
is run standalone (no active `auto.json`).

## Safety interactions (no new code — these already compose)

- A `NEEDS_FIXES`/`BLOCKED` review verdict on a chain-specced feature
  still stops the entire chain immediately, exactly as today.
- `max_cycles` (per-feature fix-loop churn) and `max_features` (total
  slices auto-specced this run) are independent counters — tuned
  separately, checked separately.

## Out of scope

- Plain `/lean-spec:auto <slug>` (single feature, no `chain_all`) is
  unchanged — it never chains into speccing a new feature. This is
  `auto-all`-only.
- No change to R8 itself — specs are still written strictly one at a
  time, grounded in real closed-slice ACs. This automates the
  human-confirmation *cadence* between slices; it does not reintroduce
  upfront batch decomposition.

## `docs/PRD.md` update

Add to §12 Resolved decisions:

| # | Decision | Rationale |
|---|---|---|
| R17 | `/lean-spec:auto-all --no-confirm` chains into speccing the next slice (one at a time, sentinel-terminated) instead of stopping when nothing's left to drain | gives simple/small projects a hands-off "spec+build the whole PRD" flow without reopening R8: specs are still written sequentially, grounded in real closed-slice ACs, never batch-decomposed. Opt-in and off by default — plain `/lean-spec:auto-all` is unchanged |

Update §13's "Resolved" line to add R17.

## Test plan

`tests/hooks_stop_auto_driver.bats`:
1. chained-and-empty + `no_confirm` + cap not hit → `spec_next` decision, `features_specced` incremented
2. chained-and-empty + `no_confirm` + cap reached → stops, removes `auto.json` (mirrors existing cap test)
3. chained-and-empty + `no_confirm` absent → stops exactly as today (regression guard on the existing "stops entirely once every feature is closed" test)
4. reason text names `skills/spec/SKILL.md`, `--no-confirm`, and `NO_REMAINING_SCOPE`
5. `max_features` defaults to 20 when omitted
6. non-numeric `max_features`/`features_specced` disarms (mirrors existing `coerce_int` tests)
7. `subagent-stop-gate.sh` resolves the *new* slug (not the stale closed one) once `auto.json`'s `slug` has been updated by the spec-write step — proves the handoff-moment correction actually fixes the early-gate resolution (write `auto.json` with the old closed slug, update it to a second, freshly-`ensure`'d `specifying`-phase slug, write a valid `spec.md` for it, confirm the gate validates *that* slug's artifact, not the closed one's)

`tests/scaffold_skills_agents.bats`:
8. `auto-all/SKILL.md` documents `--no-confirm` and `max_features`
9. `spec/SKILL.md` documents `--no-confirm` skipping confirmation and the `auto.json` slug-update handoff step
10. `architect.md` documents the `NO_REMAINING_SCOPE` sentinel

No new `e2e_lifecycle.bats` case — that file exercises CLI/hook wrappers the driver script itself doesn't touch; the hook-level tests above are the correct layer.

Run `.tools/bin/bats tests/` — all green is the definition of done.

## Surface touched

- `hooks/stop-auto-driver.sh` — new `no_confirm`/`max_features`/`features_specced` handling, one new `spec_next` decision branch, one new block-reason template. No `bin/lean-spec` (CLI) changes — `--no-confirm`/`--max-features` are skill-level flags parsed into `auto.json`, same as the existing `--gates-on`/`--max-cycles`.
- `skills/auto-all/SKILL.md` — document `--no-confirm [--max-features=N]`.
- `skills/spec/SKILL.md` — document `--no-confirm` (skip confirmation) and the `auto.json` slug-update handoff step when chained.
- `agents/architect.md` — document the `NO_REMAINING_SCOPE` sentinel contract.
- `docs/PRD.md` — R17 + updated §13 resolved line.
- `tests/hooks_stop_auto_driver.bats`, `tests/scaffold_skills_agents.bats` — new cases per the test plan above.
