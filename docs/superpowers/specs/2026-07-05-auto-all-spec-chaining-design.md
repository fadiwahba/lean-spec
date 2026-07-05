# auto-all spec-chaining — design

Status: approved by Fady, revised after an adversarial Opus/xhigh review
that caught real mechanism bugs in the first draft (see "Revision
history" at the end).

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
Without the flag, `/lean-spec:auto-all` is observably unchanged (the hook
code gains a new branch, but it's only reached when `no_confirm` is set;
drains only already-specced features, stops when none remain, exactly
as today).

### Why `--no-confirm`, not `--spec-ahead`/`--gates-off`

- Mirrors the existing `/lean-spec:implement --no-tdd` naming pattern
  (negates one specific default-on behavior) rather than inventing a new
  style.
- Avoids colliding with the existing, already-reserved `--gates-on` flag
  on `auto`/`auto-all`, which is a different axis (stricter per-phase
  confirmation, currently a no-op) — reusing "gates" language here would
  make the two look like the same knob when they aren't. **Note:** if
  `--gates-on` is ever implemented, its documented purpose ("stricter
  per-phase confirmation") will directly tension with `--no-confirm`'s
  unattended intent — worth resolving at that time, not blocking this
  design now since `--gates-on` is a no-op today.
- It's the single, precise thing being skipped: the no-arg `/lean-spec:spec`
  proposal's `AskUserQuestion` confirmation. There's no live user to
  answer it in an unattended Stop-hook-driven run anyway, so "enable
  chaining" and "skip confirmation" are the same decision — one flag,
  not two.

## Mechanism

The key insight: `stop-auto-driver.sh`'s existing `chain_all` logic
already rescans `features/*/workflow.json` (via `next_non_closed_slug`)
on every "closed" outcome to find the next feature to drive, and — when
it finds one — resets that feature's `cycles` to `0`
(`hooks/stop-auto-driver.sh:157`, existing code, unchanged). A freshly
`/lean-spec:spec`'d feature creates exactly what this rescan looks for: a
new `workflow.json` in `specifying` phase. So once the architect writes
the new `spec.md`, **the existing, unmodified chaining code picks up the
handoff automatically — including the cycle reset — on the very next hook
cycle.** No model-side `auto.json` bookkeeping is needed for the ongoing
handoff at all.

**Known, accepted gap (not fixed, deliberately):** `subagent-stop-gate.sh`
(the early `SubagentStop` artifact gate) resolves the active feature from
`.lean-spec/auto.json`'s `slug` field first. During the one write-dispatch
that creates the new `spec.md`, that field is still the *just-closed*
feature (phase `closed`, which the gate's `case` statement silently
ignores) — so the early gate no-ops for this one dispatch instead of
validating the new `spec.md` the instant the architect finishes. This is
fine: `/lean-spec:spec`'s own backstop (`bin/lean-spec validate <slug>
spec.md`, run by the orchestrator with the slug it already knows
directly, not via `auto.json`) still validates it immediately after,
satisfying CONSTITUTION principle 4's "early + backstop" pairing (early
gate is best-effort here; the backstop always fires). An earlier draft of
this design "fixed" this gap by having the model hand-write `auto.json`'s
`slug` mid-chain — an adversarial review caught that this introduced
worse bugs than the gap it closed (see Revision history), so that "fix"
was removed in favor of this documented, backstop-covered limitation.

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

**Implementation note (coerce idiom):** `coerce_int`'s own `default`
parameter is never actually returned by the function (it returns the
coerced value or `None`) — every existing call relies on
`auto.get(key, default)` supplying the default *before* coercion, e.g.
`coerce_int(auto.get("max_cycles", 20), 20)`. The new fields must follow
the exact same idiom — `coerce_int(auto.get("max_features", 20), 20)` —
not `coerce_int(auto.get("max_features"), 20)`, which would make a
missing key (i.e. every `auto.json` written before this feature existed)
coerce `None` and disarm the whole run.

### `hooks/stop-auto-driver.sh` — one new branch, placed correctly

In the existing `action == "closed"` + `chain_all` handling, in the
`else` of `if nxt is not None:` (today: stop, remove `auto.json`):

- If `no_confirm` is true **and** `features_specced < max_features`:
  increment `features_specced` (eagerly, same precedent as the existing
  unconditional `cycles` increment — the cap is a backstop, not a precise
  ledger), write `auto.json` (this rewrite touches only
  `features_specced` — the python dict is mutated in place, so `slug`,
  `cycles`, and every other field are preserved automatically; no
  read-modify-write hazard because there is only one write path, not two),
  and emit a new `spec_next` decision string.
- Otherwise (no `no_confirm`, or cap reached): unchanged — stop, remove
  `auto.json`.

**The bash side must intercept `spec_next` explicitly, before the generic
reason-builder** — the same way the existing `case "$decision" in
chained:*) ... esac` block intercepts chaining before falling through.
Without an explicit arm, `spec_next` would fall through to the generic
reason-builder, which rebuilds `reason` from the *original* `$next_json`/
`$slug` (the just-closed feature's stale `next` output, `skill: null`) —
producing a broken, wrong-feature reason. Add a `spec_next)` arm (or an
`if` before the generic builder) that constructs its own static reason
and `exit 0`s directly, using `$PLUGIN_ROOT` (already in scope) for the
absolute path — **not** a bare relative path. The disable-model-invocation
fix (`hooks/stop-auto-driver.sh:210-231`, this project's own prior
release) exists specifically because the plugin is installed *outside*
the driven project; a relative `skills/spec/SKILL.md` would resolve under
the user's project root, where it doesn't exist, regressing exactly the
drift that fix prevented.

New block reason:

> `lean-spec auto-all: no non-closed feature remains and --no-confirm is
> set (features_specced N/max_features M) — read
> {PLUGIN_ROOT}/skills/spec/SKILL.md now and follow its no-arg Steps
> yourself with --no-confirm (skip the AskUserQuestion) to propose and
> write the next slice. The propose dispatch returns either
> "<slug>: <one-line scope>" or the literal sentinel NO_REMAINING_SCOPE —
> treat ANY other or malformed response the same as the sentinel
> (fail-safe: stop, do not retry or guess). If it's the sentinel (or
> unparseable): delete .lean-spec/auto.json and stop — the PRD is fully
> covered. Otherwise: ensure the new slug and dispatch the architect to
> write spec.md exactly as /lean-spec:spec normally would. Do not touch
> .lean-spec/auto.json yourself — the driver picks up the new feature
> (and resets its cycle count to 0) automatically via the existing
> next-non-closed-feature rescan on your next turn-end.`

### Architect sentinel contract

`agents/architect.md` currently describes writing exactly one artifact
(`spec.md`) as its whole job — this sentinel only applies to the
**no-arg propose dispatch** (the existing, separate, artifact-free
dispatch that returns a slug + one-line scope for confirmation), never
to the write dispatch. That needs to be explicit in the agent doc, not
implied: add a short subsection stating the propose dispatch's contract
is "return either `<slug>: <one-line scope>`, or, if — after
cross-checking the PRD against every closed slice's delivered ACs — no
scope remains undelivered, the literal string `NO_REMAINING_SCOPE` and
nothing else." The write dispatch is completely unchanged (still writes
`spec.md`, still the agent's only artifact).

`NO_REMAINING_SCOPE` cannot collide with a real proposal: it's uppercase,
and slugs are constrained to `^[a-z0-9][a-z0-9._-]*$`
(`bin/lean-spec:75`), so no valid slug can ever equal or be confused with
it. The orchestrator's check must still be **fail-safe, not exact-match-
only**: if the architect pads or rephrases the sentinel (e.g.
`"NO_REMAINING_SCOPE — all features delivered"`), an exact string-compare
would fail, the orchestrator would try to treat the padded text as a slug,
`ensure` would reject it (invalid `SLUG_RE`), and — without a fail-safe —
the turn would end having accomplished nothing, `spec_next` would fire
again next cycle, and this would loop until `max_features`. So the
contract is: parse the propose-dispatch response as `<slug>: <scope>`; if
that parse fails for *any* reason (sentinel, padding, garbage, empty),
treat it identically to `NO_REMAINING_SCOPE` — delete `auto.json` and
stop. A stop that turns out to be premature is recoverable (the user
re-runs `/lean-spec:auto-all --no-confirm`, or specs manually); a retry
loop burning the `max_features` cap on garbage is not.

### `/lean-spec:spec --no-confirm`

`skills/spec/SKILL.md`: when `--no-confirm` is passed, skip the
`AskUserQuestion` proposal-confirmation step — the propose dispatch still
runs (it's the only source of the new slug and the sentinel), only the
human confirmation of its result is skipped. Then, per the sentinel
contract above: if the response doesn't parse as `<slug>: <scope>`,
delete `.lean-spec/auto.json` and stop. Otherwise proceed exactly as the
skill does today: `ensure <slug>`, dispatch the architect to write
`spec.md`, then the existing R15 preflight/backstop `validate` calls,
unchanged. `auto.json` is never touched here except in the terminal
delete case — no slug/cycle bookkeeping is this skill's job.

## Safety interactions

- **Corrected:** a `NEEDS_FIXES` review verdict on a chain-specced
  feature does **not** stop the chain — `resolve_next` maps it to
  `action="skill"`/`/lean-spec:fix` (`bin/lean-spec:464-466`), which
  `stop-auto-driver.sh` treats as continue-the-loop, bounded by that
  feature's own `max_cycles`. Only a `BLOCKED` verdict, or hitting
  `max_cycles`, stops the entire chain immediately — this part is
  unchanged from today's existing `chain_all` behavior.
- `max_cycles` (per-feature fix-loop churn) and `max_features` (total
  slices auto-specced this run) are independent counters — tuned
  separately, checked separately.

## Out of scope

- Plain `/lean-spec:auto <slug>` (single feature, no `chain_all`) is
  unchanged — it never chains into speccing a new feature. This is
  `auto-all`-only.
- No change to R8 itself — specs are still written strictly one at a
  time, grounded in real closed-slice ACs, never batch-decomposed. What
  this *does* give up, honestly: today's `--refine` feedback loop (PRD
  §4.1 — a blocker discovered while implementing feeds back into
  `/plan --refine` *before* the next slice is specced) has no human in
  the loop to trigger it during an unattended `--no-confirm` chain. This
  is a real accuracy mechanism being traded away, not just a confirmation
  formality — acceptable for the simple/small-project scope this is
  aimed at, not something to gloss over.

## `docs/PRD.md` update

Add to §12 Resolved decisions:

| # | Decision | Rationale |
|---|---|---|
| R17 | `/lean-spec:auto-all --no-confirm` chains into speccing the next slice (one at a time, sentinel-terminated, fail-safe on any unparseable response) instead of stopping when nothing's left to drain | gives simple/small projects a hands-off "spec+build the whole PRD" flow without reopening R8: specs are still written sequentially, grounded in real closed-slice ACs, never batch-decomposed. Trades away the `--refine` mid-chain feedback loop for unattended projects — an accepted, scoped-down cost, not free. Opt-in and off by default — plain `/lean-spec:auto-all` is unchanged |

Update §13's "Resolved" line to add R17.

## Test plan

`tests/hooks_stop_auto_driver.bats`:
1. chained-and-empty + `no_confirm` + cap not hit → `spec_next` decision, `features_specced` incremented, `slug`/`cycles` untouched
2. chained-and-empty + `no_confirm` + cap reached → stops, removes `auto.json` (mirrors existing cap test)
3. chained-and-empty + `no_confirm` absent → stops exactly as today (regression guard on the existing "stops entirely once every feature is closed" test)
4. reason text contains the **absolute** `${LEAN_SPEC_REPO_ROOT}/skills/spec/SKILL.md` path (not just the bare relative substring, which would pass for a broken relative-path reason too), `--no-confirm`, and `NO_REMAINING_SCOPE`
5. `max_features` defaults to 20 when omitted
6. non-numeric `max_features`/`features_specced` disarms (mirrors existing `coerce_int` tests); a *missing* `max_features` key does **not** disarm (guards the `auto.get(key, default)` idiom specifically, per the implementation note above)
7. `spec_next` is intercepted before the generic reason-builder: assert the emitted reason does **not** contain the closed feature's slug or the generic "run `bin/lean-spec next …`" fallback text

No new test is needed for "the chained-to feature's `cycles` resets to `0`" — that's already covered by the existing `"chain_all: closing one feature chains to the next non-closed feature"` test (`tests/hooks_stop_auto_driver.bats:207-226`, asserts `cycles == 0` after chaining), and this design reuses that exact mechanism unmodified.

`tests/scaffold_skills_agents.bats`:
8. `auto-all/SKILL.md` documents `--no-confirm` and `max_features`
9. `spec/SKILL.md` documents `--no-confirm` skipping confirmation and the fail-safe "treat any unparseable response as the sentinel" rule
10. `architect.md` documents the `NO_REMAINING_SCOPE` sentinel, scoped explicitly to the propose dispatch (not the write dispatch)

No new `e2e_lifecycle.bats` case — that file exercises CLI/hook wrappers the driver script itself doesn't touch; the hook-level tests above are the correct layer.

**Accepted coverage limit:** the sentinel/fail-safe *parsing* logic and the propose-dispatch's actual behavior are model-driven (the architect deciding what to return, the orchestrator parsing it) — same category as this project's existing disable-model-invocation compliance, which also can't be fully unit-tested. The hook-level tests above cover every deterministic branch (the `spec_next` decision, the cap, the reason text); the model-driven parts are backstopped by the design (fail-safe default = stop) rather than asserted by a test. Manual verification (a demo run) is the practical check for that part, not a new automated test.

Run `.tools/bin/bats tests/` — all green is the definition of done.

## Surface touched

- `hooks/stop-auto-driver.sh` — new `no_confirm`/`max_features`/`features_specced` handling, one new `spec_next` decision branch (intercepted before the generic reason-builder, using the absolute `$PLUGIN_ROOT` path), one new block-reason template. No `bin/lean-spec` (CLI) changes — `--no-confirm`/`--max-features` are skill-level flags parsed into `auto.json`, same as the existing `--gates-on`/`--max-cycles`. No changes to `subagent-stop-gate.sh` or `pre-tool-use-guard.sh` (the known early-gate gap is accepted, not patched; the guard's regex already excludes `auto.json`/`spec.md`).
- `skills/auto-all/SKILL.md` — document `--no-confirm [--max-features=N]`.
- `skills/spec/SKILL.md` — document `--no-confirm` (skip confirmation, propose dispatch still runs) and the fail-safe sentinel-parsing rule. No `auto.json` bookkeeping documented here — this skill never touches it except the terminal delete.
- `agents/architect.md` — document the `NO_REMAINING_SCOPE` sentinel contract, scoped to the propose dispatch only.
- `docs/PRD.md` — R17 + updated §13 resolved line.
- `tests/hooks_stop_auto_driver.bats`, `tests/scaffold_skills_agents.bats` — new cases per the test plan above.

## Revision history

An adversarial Opus/xhigh design review of the first draft found the
following, all incorporated above:

- **Factual error:** the first draft claimed `NEEDS_FIXES` stops the
  chain like `BLOCKED` does; it doesn't (continues via `/lean-spec:fix`,
  bounded by `max_cycles`). Corrected in "Safety interactions."
- **Regression:** the first draft's new block-reason template used a
  bare relative `skills/spec/SKILL.md` path, regressing this project's
  own prior disable-model-invocation fix (which uses an absolute
  `$PLUGIN_ROOT`-prefixed path for exactly this reason). Fixed.
- **Runaway-guard defeat + missing cycle reset:** the first draft had the
  *model* hand-write `auto.json`'s `slug` mid-chain (to fix the early-gate
  gap below), risking the model clobbering `features_specced` back to 0
  via a full-file rewrite, and never reset `cycles` for the handed-off
  feature (the existing `chained:` path already does, at
  `hooks/stop-auto-driver.sh:157`). **Root-cause fix, not a patch:**
  removed the model-side `auto.json` write requirement entirely: the
  final design lets the existing, unmodified `chained:` rescan mechanism
  handle the handoff (including the cycle reset) one cycle later, and
  documents the early-gate gap as an accepted, backstop-covered
  limitation instead of "fixing" it with a more fragile mechanism.
- **Missing dispatch guard:** the first draft didn't show that the new
  `spec_next` decision needs an explicit early-return in the bash script,
  or it falls through to the generic reason-builder using stale data.
  Fixed — the mechanism section now specifies this explicitly.
- **Fragile termination:** the first draft's sentinel check was implied
  to be an exact string-match, which fails open into a retry loop on any
  padded/malformed architect response. Fixed — the contract is now
  explicitly fail-safe (any unparseable response stops the chain, same as
  the canonical sentinel).
