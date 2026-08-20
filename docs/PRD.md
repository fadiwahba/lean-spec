# lean-spec v4 — Product Requirements Document

> Historical v4 product record. The current host-neutral adapter requirements
> are in [`CODEX_ADAPTER_SPEC.md`](CODEX_ADAPTER_SPEC.md).

> **What we are building.** How we build it lives in `docs/CONSTITUTION.md`.
> Status: APPROVED — shipped (1.0 and subsequent point releases; see `CHANGELOG.md`). Greenfield rebuild; shares no code with lean-spec v3 (`~/sandbox/lean-spec`), only lessons.

---

## 1. One-paragraph summary

lean-spec v4 is a Claude Code plugin that turns daily software development into a **deterministic, spec-driven lifecycle**: interview → PRD → spec → implement (TDD) → review → fix → close. Every phase has one owner agent (model + effort set in config), one mandatory artifact, and one gate. Discipline is enforced by the **harness** — hooks and a single state CLI — never by prompt obedience. Claude Code is the only target for 1.0; external coders (Gemini, OpenCode, Codex) come later as thin headless-CLI adapters.

## 2. Why a rebuild

v3 proved the concept (workflow.json state + hook guards + verdict routing, 184 green tests) but carries three structural costs the greenfield removes:

1. **Logic lives in prompts.** Phase-gate bash is duplicated across 16 command markdown files; a step the model skips is a gate that never ran.
2. **Deprecated surface.** `commands/*.md` is legacy; skills are the modern, model-invocable unit (required for `/loop` scheduling and forked context).
3. **Cross-provider tax.** Hand-ported Gemini TOML / OpenCode / Codex copies of every command needed count-tests just to stay in sync. v4 ships Claude-only core; other providers become *adapters that call the same CLI*, not ports.

v4 also builds on harness features that post-date v3's design: per-subagent `effort:` frontmatter, `/goal` (condition-based continuation), `/loop` (scheduled skills), and the full `Stop`/`SubagentStop` hook lifecycle.

## 3. Value propositions (ordered)

1. **Determinism** — the model cannot skip, reorder, or hand-edit its way around the lifecycle. Hooks block; the state CLI is the only mutation path.
2. **Right model per phase** — planning, speccing, coding, and reviewing each run on a configured model + effort (see §7). Cost/quality arbitrage is a config knob, not a rewrite.
3. **Artifacts as the audit trail** — every phase leaves a validated markdown artifact; `git log` + `features/` tells the whole story.
4. **TDD as a first-class mode** — RED/GREEN enforced with evidence gates, not vibes.
5. **Harness-native drivers** — autonomous mode is a `Stop` hook (deterministic JSON check); `/goal` and `/loop` are documented recipes on top.

## 4. Core concepts

### 4.1 Lifecycle

```
(first run)   init → plan(interview)
(per feature) specifying → implementing → reviewing → closed
                  ↑            ↑  NEEDS_FIXES │
                  │            └──────────────┘
                  └── respec (--refine)
```

**One feature at a time — no upfront decomposition.** `/spec` derives the *next* slice from the PRD plus what is already closed; blockers discovered while implementing feed back into `/plan --refine` before the next slice is specced. Specs are never written ahead of the feature that needs them (they go stale the moment a blocker refines the PRD).

### 4.2 Artifacts & owners

| Artifact | Written by | Validated by | Phase |
|---|---|---|---|
| `docs/PRD.md` | planner (session model, via interview) | plan skill checks | project |
| `docs/CONSTITUTION.md` | planner (from interview constraints) | plan skill checks | project |
| `features/<slug>/spec.md` | architect agent | SubagentStop gate + phase gate | specifying |
| `features/<slug>/workflow.json` | **state CLI only** | PreToolUse guard | all |
| `features/<slug>/notes.md` (+`## TDD` evidence) | coder agent | SubagentStop gate + phase gate | implementing |
| `features/<slug>/review.md` (`verdict:` line) | reviewer agent | SubagentStop gate + close gate | reviewing |
| `features/<slug>/evidence/visual/*` (screenshots, **gitignored**) | reviewer agent (`--visual` only) | review gate: must exist + be cited in review.md | reviewing |

### 4.3 `workflow.json`

Same minimal schema as v3 (phase, history[], timestamps). Single-sourced: no `phase:` in any artifact frontmatter. Created and mutated exclusively by the state CLI.

## 5. Architecture — three layers

```
lean-spec/
├── .claude-plugin/plugin.json      # manifest
├── bin/lean-spec                   # LAYER 1 — state CLI (python3 stdlib, single file)
│   #  ensure <slug>        create workflow.json if absent (idempotent)
│   #  advance <slug> <from> <to> [--tdd|--no-tdd]  fcntl-locked; atomic tmp+replace, history append, post-assert
│   #  assert <slug> <phase>        exit 2 on mismatch
│   #  validate <slug> <artifact>   rules.toml checks (sections, caps, verdict, TDD evidence)
│   #  next <slug>|--all            phase → next-skill resolver
│   #  status [<slug>]              read-only report
├── hooks/                          # LAYER 2 — enforcement (all gates live here)
│   ├── pre-tool-use-guard.sh       # blocks Write/Edit on features/*/workflow.json
│   ├── subagent-stop-gate.sh       # validate artifact the moment its agent finishes
│   └── stop-auto-driver.sh         # auto mode: block turn-end until closed/BLOCKED/cap
├── skills/                         # LAYER 3 — thin prompts (zero gate logic)
│   └── <name>/SKILL.md             # init, plan, spec, respec, implement, review,
│                                   # fix, close, auto, auto-all, next, status, help
├── agents/                         # architect, coder, reviewer (frontmatter model+effort)
├── templates/                      # PRD, CONSTITUTION, spec, notes, review skeletons
├── examples/rules.toml
└── tests/                          # Python unittest; CLI + hooks testable without a live model
```

**Layer rule (the load-bearing invariant):** skills *describe* work and dispatch agents; hooks *enforce*; the CLI *mutates*. A skill instruction the model ignores can never break state, because state and gates don't live in skills.

## 6. Skill surface (1.0)

| Skill | Does | Gate |
|---|---|---|
| `/lean-spec:init` | preflight environment (fail-loud); scaffold `.lean-spec/rules.toml`, `docs/`, `features/`, `.gitignore` entry for `features/*/evidence/` | idempotent |
| `/lean-spec:plan` | AskUserQuestion interview (≤3 rounds: problem/users, features, constraints, quality bar, non-goals) → session model writes `docs/PRD.md` + `docs/CONSTITUTION.md`; `--refine` (blocker feedback) / `--regenerate` modes | PRD/CONSTITUTION template sections present |
| `/lean-spec:spec [<slug>] [--refine] [--no-confirm]` | no args: **architect** reads PRD + feature status, proposes the *next* slice (slug + scope) for user confirmation — skipped with `--no-confirm`, which instead parses the response fail-safe against the `NO_REMAINING_SCOPE` sentinel (R17) — then writes that one `spec.md` + `ensure` state; with slug: spec that named slice; `--refine` revises | SubagentStop validate |
| `/lean-spec:implement <slug> [--tdd\|--no-tdd]` | `advance specifying→implementing` (passing `--tdd`/`--no-tdd` so the CLI records the per-feature TDD mode in `workflow.json`); dispatch **coder**; TDD per §8; commit | validate + `advance` + commit token |
| `/lean-spec:review <slug> [--visual]` | `advance implementing→reviewing`; dispatch **reviewer** → `review.md` verdict. `--visual` (UI/UX specs): reviewer drives the running app with a browser scripted through `Bash` (e.g. a Playwright CLI script), verifies visual ACs, saves screenshots to `features/<slug>/evidence/visual/`, cites them in a `## Visual Fidelity` section | validate; `--visual` additionally requires evidence files + section |
| `/lean-spec:fix <slug>` | NEEDS_FIXES loop: `advance reviewing→implementing` (CLI-gated on `review.md` verdict == `NEEDS_FIXES` — R18); coder appends `## Cycle N` | validate + commit |
| `/lean-spec:close <slug>` | verdict==APPROVE gate; `advance reviewing→closed`; commit | verdict gate |
| `/lean-spec:auto <slug> [--gates-on] [--max-cycles=N]` | write `.lean-spec/auto.json`, run first next-step; **Stop hook drives the rest** | hook-owned |
| `/lean-spec:auto-all [--gates-on] [--no-confirm] [--max-features=N]` | drive every non-closed feature to closed, sequentially (one `auto.json` at a time); with `--no-confirm`, also chains into speccing the next slice one at a time, sentinel-terminated, instead of stopping (R17) | hook-owned |
| `/lean-spec:next`, `/lean-spec:status` | read-only navigation (CLI passthrough) | — |
| `/lean-spec:help` | read-only onboarding overview: the lifecycle + every skill with when to use it (no command run) | — |

Driver recipes (docs only): `/goal "features/<slug>/workflow.json has \"phase\": \"closed\", or stop after 20 turns"`, `/loop /lean-spec:auto-all`, CI: `claude -p "/lean-spec:auto <slug>"`.

## 7. Configuration — `.lean-spec/rules.toml`

TOML, not YAML: Python's stdlib has **no YAML parser** (v3 hand-rolled a fragile subset parser); `tomllib` is stdlib since Python 3.11 and TOML keeps comments. State stays JSON (`workflow.json`, `auto.json` — `json` stdlib). This sets the Python floor at **≥ 3.11**, enforced by a fail-loud preflight (CONSTITUTION §Principles).

```toml
# per-phase owner; precedence: CLI flag > this file > agent frontmatter default
[agents]
plan      = { model = "session" }                  # interview runs in the main session
spec      = { model = "opus",   effort = "xhigh" }
implement = { model = "sonnet", effort = "high" }
review    = { model = "opus",   effort = "high" }  # switch to "sonnet" to cut cost
# fix inherits implement when omitted

[defaults]
tdd = true                            # v4 default ON; --no-tdd or false to opt out
constitution = "docs/CONSTITUTION.md" # injected into every agent dispatch prompt
required_verdict = "APPROVE"

[required_sections]                   # additive, as v3
"spec.md"   = ["Scope", "Acceptance Criteria", "Out of Scope", "Coder Guardrails"]
"notes.md"  = ["What was built", "How to verify"]
"review.md" = ["Verdict", "Spec Compliance", "Code Quality"]

[max_tokens]
"spec.md" = 2000
"notes.md" = 6000
"review.md" = 8000
```

Effort resolution: agent frontmatter carries defaults. The current external
adapter passes `effort` only to Codex through
`-c model_reasoning_effort=<effort>`. Claude and Gemini entries must omit it;
the adapter rejects an unsupported effort instead of silently dropping it.

## 8. TDD mode (default ON)

1. **RED** — coder writes failing tests per Acceptance Criterion, runs them, captures output. Commit `test(<slug>): red — failing ACs`.
2. **GREEN** — implement until pass; capture run. Commit `feat(<slug>): green — <subject>`.
3. **Evidence** — `notes.md ## TDD` holds both trimmed runs; `bin/lean-spec validate` blocks `/review` without them; reviewer verifies tests map to ACs and weren't weakened.

## 9. External providers (post-1.0, M5)

One adapter contract, not command ports: resolve prompt → run an installed
provider headlessly → CLI validates artifacts → orchestrator commits. The
current adapter IDs are `codex`, `claude`, and `gemini`. It builds argv lists
without a shell: `codex exec --json --model`, `claude -p --output-format json
--model`, and `gemini --output-format json --model --prompt`. Providers never
write lifecycle state; only `bin/lean-spec` does.

## 10. Non-goals (explicit)

- No per-command cross-provider ports (TOML/Codex/OpenCode copies) — ever.
- No Node.js/npm runtime; no `jq`/`yq`; no YAML anywhere (python3 ≥ 3.11 stdlib only: `json` for state, `tomllib` for config). Python's stdlib `unittest` is the test tool.
- No web UI/dashboard; artifacts + git are the interface.
- No multi-feature parallel orchestration in 1.0 (one feature in flight per driver).
- No native support for non-Claude orchestrators in 1.0 (they arrive as M5 adapters).

## 11. Feature breakdown (implementation-ready)

### M0 — Bootstrap (no lifecycle yet)
- **F1** repo scaffold: manifest, Python unittest harness, CI (GitHub Actions: unittest on PR), templates.

### M1 — Deterministic core
- **F2** `bin/lean-spec` state CLI (ensure/advance/assert/validate/next/status) + full Python unittest coverage.
- **F3** `pre-tool-use-guard.sh` + `subagent-stop-gate.sh` + `stop-auto-driver.sh`.
- **F4** rules.toml v2 loader inside the CLI (`validate` consumes it).

### M2 — Lifecycle skills & agents
- **F5** agents: architect (opus/xhigh), coder (sonnet/high), reviewer (opus/high) + constitution injection.
- **F6** skills: init, plan (interview → PRD + CONSTITUTION).
- **F7** skills: spec (next-slice derivation + named + --refine), implement (+TDD), review (+`--visual` evidence), fix, close.
- **F8** skills: next, status, auto, auto-all (+`.lean-spec/auto.json` contract).

### M3 — Proof & ship
- **F9** e2e demo: fixture project driven interview→closed, recorded walkthrough in README.
- **F10** headless CI smoke: `claude -p` full cycle on release tags.
- **F11** marketplace publish + compatibility floor pinned (min Claude Code version).
- **F12** final ship review (Opus 4.8 · xhigh, per CONSTITUTION §Delegation) → 1.0.

### M5 — Post-1.0
- **F13** external provider adapters (Gemini, Codex, and Claude headless CLIs).
- **F14** opt-in telemetry.

Dogfood rule: from F6 onward, every feature is built through the v4 pipeline itself (M0–M1 bootstrap by hand, by necessity).

## 12. Resolved decisions

| # | Decision | Rationale |
|---|---|---|
| R1 | Evolve nothing — clean repo, lessons only | v3 stays intact for comparison; no migration burden |
| R2 | Skills, not commands | modern surface; `/loop`-schedulable; forked context |
| R3 | Single state CLI over per-skill bash | one implementation, one test target, adapters reuse it |
| R4 | Stop hook is the shipped driver; `/goal` is a recipe | deterministic JSON check beats Haiku yes/no; zero user action |
| R5 | TDD default ON | v4 is quality-first; the knob exists for spikes |
| R6 | Coder = Sonnet 5/high (not Haiku) | v3's cheapest-coder default optimized tokens over correctness; v4 inverts it, config can still downshift |
| R7 | Claude-only 1.0 | cross-provider was v3's largest maintenance tax |
| R8 | No upfront decomposition — one spec at a time (`decompose` does not exist) | pre-written specs go stale the moment a blocker refines the PRD; next-slice visibility beats batch speccing (Fady, from v3 experience) |
| R9 | `auto-all` ships in 1.0 | near-free atop the Stop-hook driver: iterate non-closed features, one `auto.json` at a time |
| R10 | `effort` is capability-gated per provider | optional knob; passed only to CLIs that support it, dropped with a note elsewhere |
| R11 | Reviewer defaults to Opus 4.8/high, switchable to Sonnet 5 in rules.toml | cross-family review by default; cost knob stays available |
| R12 | `--visual` review evidence lives in `features/<slug>/evidence/visual/`, **gitignored** | co-located local audit aid without binary repo bloat; review.md citations are the durable record |
| R13 | Fail loudly | every entry point preflights (python3 ≥ 3.11, Claude Code floor, git repo) and exits with a one-line actionable error; no silent fallbacks (CONSTITUTION principle 8) |
| R14 | TOML for config, JSON for state — YAML eliminated | stdlib has no YAML parser; `tomllib` (3.11+) keeps comments and determinism; state stays `json` |
| R15 | `/lean-spec:spec` fail-loud-preflights project-doc readiness via `validate --project`; the check now rejects **unfilled placeholder** sections, not just missing headings | a user could `init` then jump straight to `spec` (or run brownfield without ever `plan`ning), feeding the architect an empty/skeleton PRD + CONSTITUTION — defeating the "discipline enforced by the CLI, never prompt obedience" premise; the gate is a CLI check (layer rule), invoked as a preflight exactly like `init`'s and `plan`'s |
| R16 | `/lean-spec:plan` grounds its interview in the existing repo (reads manifests / test+CI config / README / `git log`) before asking, rather than interviewing greenfield-only | brownfield adoption: `Stack`/`Principles`/`Delegation` are usually already evident in-repo; asking from scratch yields a Constitution that ignores what's actually there — done in the session model directly, no CLI stack-detection heuristic |
| R17 | `auto-all --no-confirm` chains into speccing the next slice one at a time, stopping only on the exact `NO_REMAINING_SCOPE` sentinel | gives simple/small projects a hands-off "spec+build the whole PRD" flow without reopening R8. Malformed architect output is `NEEDS_INPUT`, never inferred completion. |
| R18 | Enforcement hardening from a ground-up deep review (v1.3.0): the three hooks reject valid-but-non-object JSON instead of crashing (was a fail-open bypass); the `workflow.json` write guard normalizes + case-folds paths (`Workflow.json`/`../` no longer dodge it); corrupt `rules.toml`/`workflow.json` fail loudly, not with tracebacks; `--no-tdd` persists per-feature in `workflow.json` so the gate honors the opt-out; `reviewing→implementing` is CLI-gated on a `NEEDS_FIXES` verdict; `advance` is serialized with an `fcntl` lock and preserves file mode | the "discipline enforced by the harness, never prompt obedience" premise only holds if the harness itself can't be crashed into failing open or bypassed — the review found several such holes; closing them keeps the enforcement guarantees real under corrupt/adversarial state |

## 13. Open questions

None. Resolved 2026-07-03: reviewer = Opus default with Sonnet switch (R11) · `decompose` removed in favour of one-spec-at-a-time (R8) · `auto-all` in 1.0 (R9) · evidence gitignored (R12) · fail-loud preflights (R13) · TOML config / JSON state (R14). Resolved 2026-07-05: `spec` preflights project-doc readiness and `validate --project` rejects unfilled placeholders (R15) · `plan` grounds its interview in the existing repo for brownfield (R16) · `auto-all --no-confirm` chains into speccing the next slice, sentinel-terminated (R17). Resolved 2026-07-07: enforcement hardening from the deep review — hooks reject non-object JSON, guard normalizes paths, corrupt state fails loud, `--no-tdd` persists, fix loop gated on NEEDS_FIXES, advance locked (R18).

## 14. Approval

- [x] Fady — PRD approved; 1.0 shipped and released (see `CHANGELOG.md`).
