<p align="center">
  <img src="images/logo-trans.svg" alt="lean-spec" width="360" />
</p>

<h1 align="center">lean-spec v4</h1>

<p align="center"><strong>Deterministic, spec-driven development for Claude Code.</strong><br/>
One phase, one owner, one artifact, one gate — enforced by the harness, not by prompt obedience.</p>

<p align="center"><code>Status: design approved · implementation starting · nothing installable yet</code></p>

---

## What it is

lean-spec is a Claude Code plugin that turns daily software work into a disciplined lifecycle:

```
(first run)   init → plan (interview → PRD + CONSTITUTION)
(per feature) spec → implement (TDD) → review → fix → review → close
```

Every phase is owned by a configured agent (model + effort per phase), produces a mandatory validated artifact, and advances through a state machine the model **cannot bypass** — hooks block direct state edits, artifact gates block empty work, and a verdict gate blocks closing anything a reviewer didn't approve.

## Why v4

v4 is a greenfield rebuild of [lean-spec v3](https://github.com/fadiwahba/lean-spec)'s proven concept on a stricter architecture:

| | v3 | v4 |
|---|---|---|
| Gate logic | bash duplicated across 16 command files | one state CLI (`bin/lean-spec`), hooks own all gates |
| Plugin surface | `commands/` (deprecated) | `skills/` (model-invocable, `/loop`-schedulable) |
| Spec strategy | decompose PRD into all specs upfront | **one spec at a time**, next slice derived from PRD + what's closed |
| Providers | hand-ported command copies (Gemini TOML, OpenCode, Codex) | Claude-only 1.0; external CLIs later as thin headless adapters |
| Config | YAML (no stdlib parser) | **TOML** (`tomllib`, comments) for config · JSON for state |
| TDD | none | default ON — RED/GREEN commits + evidence gate |
| Autonomy | prompt-protocol driver loop | **Stop-hook driver** (deterministic JSON check); `/goal` & `/loop` recipes |

## The three layers

```
bin/lean-spec     MUTATES   — the only writer of workflow.json (ensure/advance/assert/validate/next/status)
hooks/            ENFORCES  — PreToolUse guard · SubagentStop artifact gates · Stop auto-driver
skills/           DESCRIBES — thin prompts that dispatch agents; zero gate logic lives here
```

A skill instruction the model ignores can never corrupt state, because state and gates don't live in skills.

## Agent delegation (defaults)

| Phase | Agent | Model · effort |
|---|---|---|
| plan (interview) | session model | — |
| spec | architect | Opus 4.8 · xhigh |
| implement / fix | coder | Sonnet 5 · high · **TDD** |
| review | reviewer | Opus 4.8 · high (switchable to Sonnet 5) |

All overridable per project in `.lean-spec/rules.toml`:

```toml
[agents]
spec      = { model = "opus",   effort = "xhigh" }
implement = { model = "sonnet", effort = "high" }
review    = { model = "opus",   effort = "high" }

[defaults]
tdd = true
constitution = "docs/CONSTITUTION.md"
```

## Planned command surface (1.0)

```
/lean-spec:init                    scaffold config, docs/, features/ (fail-loud preflight)
/lean-spec:plan "<idea>"           interview → docs/PRD.md + docs/CONSTITUTION.md
/lean-spec:spec                    architect proposes & specs the NEXT slice (or: spec <slug>)
/lean-spec:implement <slug>        coder implements, RED→GREEN TDD (--no-tdd to opt out)
/lean-spec:review <slug>           reviewer → verdict; --visual = Playwright evidence for UI specs
/lean-spec:fix <slug>              NEEDS_FIXES loop
/lean-spec:close <slug>            APPROVE-gated close
/lean-spec:auto <slug>             hands-free: Stop hook drives phases until closed
/lean-spec:auto-all                drain every non-closed feature
/lean-spec:next · status           read-only navigation
```

Autonomy alternatives using Claude Code built-ins (no plugin code involved):

```
/goal features/<slug>/workflow.json has "phase": "closed", or stop after 20 turns
/loop /lean-spec:auto-all
claude -p "/lean-spec:auto <slug>"          # headless / CI
```

## Design principles

- **Fail loudly** — every entry point preflights its environment (python3 ≥ 3.11, Claude Code version floor, git repo) and exits with a one-line actionable error. No silent fallbacks.
- **Artifacts are the audit trail** — `spec.md`, `notes.md` (with TDD evidence), `review.md` (with verdict); `git log` tells the whole story.
- **Zero-config first run** — no `rules.toml` needed to complete a full cycle; every key is additive.
- **Dogfooded** — v4's own features are built through the v4 lifecycle as soon as the pipeline stands.

## Demo / end-to-end walkthrough

F9 (PRD §11, M3) proves the deterministic pipeline works end-to-end — the
harness spine, not a model. Everything below runs the REAL `bin/lean-spec`
CLI and the REAL hooks against a throwaway project; only the model-authored
artifacts (the "interview" output, `spec.md`, `notes.md`, `review.md`) are
simulated from a checked-in fixture, so the walkthrough is fully
deterministic and needs no API key or live model call.

```
interview (simulated) → docs/PRD.md + docs/CONSTITUTION.md
        │
        ▼
   ensure <slug>            phase: specifying
        │  architect writes spec.md (simulated)
        │  bin/lean-spec validate  → SubagentStop gate → advance
        ▼
   implementing              coder writes notes.md + ## TDD evidence (simulated)
        │  validate → gate → advance
        ▼
   reviewing                 reviewer writes review.md, verdict: APPROVE (simulated)
        │  validate → gate → next → /lean-spec:close
        ▼
   closed                    advance reviewing→closed (CLI refuses without verdict: APPROVE)
```

Run it yourself:

```console
$ ./scripts/demo.sh
lean-spec F9 demo — driving 'hello-cli' through the full lifecycle
temp project: /tmp/lean-spec-demoXXXXXX (removed on exit)

=== init: scaffold .lean-spec/rules.toml + docs/ (as /lean-spec:init would) ===
...
=== close: advance reviewing -> closed (CLI enforces verdict: APPROVE) ===
slug: hello-cli
phase: closed
...
demo complete: 'hello-cli' reached 'closed' via the real CLI + hooks, zero live model calls.

=== bonus: a second slice shows the gates really enforce the lifecycle ===
-- attempting a hand-edit of workflow.json mid-flow (should be denied) --
{ "hookSpecificOutput": { ... "permissionDecision": "deny" ... } }
-- attempting to close with a NEEDS_FIXES verdict (should be rejected) --
lean-spec: cannot close 'second-slice': review.md verdict is 'NEEDS_FIXES', required 'APPROVE'
rejected as expected — next step:
/lean-spec:fix second-slice
```

The script fails loudly on a missing `python3 >= 3.11` or `git`, creates
its own `mktemp` temp project, and cleans up on exit — safe to re-run any
number of times.

The automated, CI-enforced version of the same drive lives in
[`tests/e2e_lifecycle.bats`](tests/e2e_lifecycle.bats): it exercises the
identical happy path plus a **negative path** — a `NEEDS_FIXES` verdict
correctly blocks `advance reviewing closed` and routes `next` to
`/lean-spec:fix` instead of `/lean-spec:close`, and the `PreToolUse` guard
denies a hand-edit of `workflow.json` mid-lifecycle — proving the gates
bite, not just that the happy path runs. Run it with:

```console
$ .tools/bin/bats tests/e2e_lifecycle.bats
1..2
ok 1 e2e: full lifecycle interview(simulated) -> spec -> implement -> review -> closed
ok 2 e2e negative: NEEDS_FIXES verdict blocks close and routes to fix; hand-edit of workflow.json is denied mid-flow
```

Both the script and the test source the same fixture content —
[`tests/fixtures/demo-project/`](tests/fixtures/demo-project/) (a minimal
`hello-cli` target project: scaffolded `docs/`, one feature slice's
`spec.md`/`notes.md`/`review.md`) — through the shared helper library
[`scripts/lib/demo-lifecycle.sh`](scripts/lib/demo-lifecycle.sh), so the
human-readable walkthrough and the CI-enforced proof can never drift apart.

> **TODO (human):** an asciinema recording or terminal GIF of `./scripts/demo.sh`
> would make a nicer visual walkthrough than the console transcript above —
> not yet recorded.

## Documents

- [`docs/PRD.md`](docs/PRD.md) — **what** we are building: architecture, skill surface, milestones F1–F14, resolved decisions
- [`docs/CONSTITUTION.md`](docs/CONSTITUTION.md) — **how** we build it: stack, invariants, delegation ladder, TDD policy, quality bars

## Roadmap

| Milestone | Scope | Status |
|---|---|---|
| M0 | scaffold, BATS harness, CI | next |
| M1 | state CLI + enforcement hooks | — |
| M2 | lifecycle skills + agents | — |
| M3 | e2e demo, headless CI smoke, marketplace publish, final ship review → **1.0** | — |
| M5 | external provider adapters (Gemini / OpenCode / Codex), telemetry | post-1.0 |

## Requirements

- Claude Code (version floor pinned at F11)
- Python 3 ≥ 3.11 (stdlib only — no pip packages)
- git

---

<p align="center"><sub>lean-spec — for solos & small teams who want their AI agents disciplined.</sub></p>
