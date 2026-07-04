<p align="center">
  <img src="images/header.svg" alt="lean-spec — deterministic, spec-driven development for Claude Code" width="880" />
</p>

<p align="center">
  <a href="https://github.com/fadiwahba/lean-spec-v4/actions/workflows/ci.yml"><img src="https://github.com/fadiwahba/lean-spec-v4/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <img src="https://img.shields.io/badge/python-3.11%2B-3776AB" alt="Python 3.11+" />
  <img src="https://img.shields.io/badge/Claude%20Code-plugin-8A63D2" alt="Claude Code plugin" />
</p>

<h1 align="center">lean-spec</h1>

<p align="center"><em>A Claude Code plugin that turns AI-assisted development into a disciplined lifecycle the model can't skip its way around.</em></p>

---

## What is lean-spec?

**lean-spec** gives your AI coding agent a rulebook it has to follow.

Instead of asking Claude to "build a feature" and hoping it plans, tests, and reviews along the way, lean-spec runs every feature through a fixed lifecycle:

```
init → plan → spec → implement → review → close
 └ once ┘      └────── repeat per feature ──────┘
```

Each phase has **one owner** (a specific model + effort level), produces **one mandatory artifact** (a validated markdown file), and passes through **one gate** before the next phase can start. The rules aren't polite suggestions in a prompt — they're enforced by the harness: a state machine, file-write guards, and validation hooks that **block** the model when it tries to cut a corner.

The result: a repeatable, auditable trail for every change, where `git log` and the `features/` folder tell the whole story.

## Why it exists

AI agents are fast but undisciplined. Left to a single prompt, they'll skip the plan, write code before tests, mark their own work "done," and leave you reconstructing what happened. Prompt instructions like *"always write tests first"* fail the moment the model forgets — and a skipped step is a gate that never ran.

lean-spec makes discipline **structural instead of aspirational**:

- **The model can't bypass the process** — phase transitions live in a state CLI and are guarded by hooks, not in prose the model can ignore.
- **The right model does each job** — cheap models code, stronger models spec and review, all configurable per phase.
- **Every step leaves evidence** — a spec, TDD run output, a review verdict — committed as you go.
- **Reviews actually gate** — a feature can't close unless a reviewer (a *different* model than the coder) approves it.

## How it works

Three layers with strictly separated jobs — this is the load-bearing idea:

```
skills/       DESCRIBE   thin prompts that dispatch agents · zero gate logic
hooks/        ENFORCE    block workflow.json edits · gate artifacts · drive auto mode
bin/lean-spec MUTATE     the only thing allowed to write workflow.json
```

A skill instruction the model ignores can never corrupt state, because **state and gates don't live in skills.** Skills just describe work and hand it to an agent; hooks enforce the rules; the CLI is the single source of truth for where each feature is in its lifecycle.

The lifecycle, with its gates:

```
   /lean-spec:spec          architect writes spec.md  ────────┐
        │                   (Scope · ACs · Guardrails)        │ validated
        ▼                                                     │ at every
   /lean-spec:implement     coder writes code + tests         │ SubagentStop
        │                   RED → GREEN, evidence in notes.md │ AND at the
        ▼                                                     │ phase gate
   /lean-spec:review        reviewer writes review.md ────────┤
        │                   verdict: APPROVE│NEEDS_FIXES│BLOCKED
        │                        │
        │   NEEDS_FIXES ──► /lean-spec:fix ──► back to review
        ▼
   /lean-spec:close         refuses unless verdict == APPROVE
```

## Features

- 🔒 **Bypass-proof lifecycle** — hooks block direct state edits and empty artifacts; the model literally can't skip or fake a phase.
- 🎯 **Right model per phase** — spec on Opus, code on Sonnet, review on Opus (or any mix), set in one config file.
- 🧪 **TDD by default** — RED then GREEN, both runs captured as evidence; `review` is blocked without it. Opt out per-feature with `--no-tdd`.
- 📝 **Artifacts as the audit trail** — `spec.md`, `notes.md`, `review.md` per feature; the whole history is in `git log`.
- 🧭 **One spec at a time** — the next slice is derived from the PRD plus what's already shipped, so specs never go stale from being written too early.
- 🖼️ **Visual reviews** — `review --visual` drives the running app via Playwright and captures UI evidence for design specs.
- 🤖 **Hands-free autonomy** — a Stop-hook driver runs a feature (or all of them) to done with no babysitting.
- 💥 **Fail-loud** — every entry point preflights its environment and exits with a one-line, actionable error. No silent fallbacks.
- 🪶 **A dependency-free core** — the harness is pure `python3` stdlib (≥ 3.11) + bash: no Node, no pip, no `jq`/`yq`, no YAML. (Only the optional `review --visual` step reaches for extra tooling — Playwright/Chrome.)

## Getting started

lean-spec is a local Claude Code plugin (not yet on a marketplace). Point Claude Code at the repo:

```bash
# 1. Get the plugin (clone it anywhere)
git clone https://github.com/fadiwahba/lean-spec-v4.git ~/tools/lean-spec-v4

# 2. From inside YOUR project (any git repo), launch Claude Code with the plugin
cd ~/path/to/your-project
claude --plugin-dir ~/tools/lean-spec-v4
```

Then drive the lifecycle from inside Claude Code:

```
/lean-spec:init                  scaffold .lean-spec/, docs/, features/, .gitignore  (run once)
/lean-spec:plan "<your idea>"    short interview → docs/PRD.md + docs/CONSTITUTION.md
/lean-spec:spec                  architect proposes & specs the NEXT slice
/lean-spec:implement <slug>      coder implements it, RED → GREEN TDD
/lean-spec:review <slug>         reviewer gives a verdict  (--visual for UI specs)
/lean-spec:fix <slug>            address NEEDS_FIXES, loop back to review
/lean-spec:close <slug>          APPROVE-gated — closes the feature
/lean-spec:next · :status        read-only: where am I, what's next
```

Repeat `spec → implement → review → close` for each feature. That's the whole loop.

## Configuration

Everything is optional — a zero-config project completes a full cycle. Tune per project in `.lean-spec/rules.toml`:

```toml
[agents]                                              # who runs each phase
spec      = { model = "opus",   effort = "xhigh" }
implement = { model = "sonnet", effort = "high" }
review    = { model = "opus",   effort = "high" }     # switch to "sonnet" to cut cost

[defaults]
tdd = true                                            # RED/GREEN enforced; false or --no-tdd to opt out
required_verdict = "APPROVE"                          # what `close` demands

[required_sections]                                   # additive artifact checks
"spec.md"   = ["Scope", "Acceptance Criteria", "Out of Scope", "Coder Guardrails"]
"review.md" = ["Verdict", "Spec Compliance", "Code Quality"]
```

## Who does what

| Phase | Owner | Default model · effort | Writes |
|---|---|---|---|
| plan | your session | — | `PRD.md`, `CONSTITUTION.md` |
| spec | **architect** | Opus 4.8 · xhigh | `spec.md` |
| implement / fix | **coder** | Sonnet 5 · high · **TDD** | `notes.md` (+ TDD evidence) |
| review | **reviewer** | Opus 4.8 · high | `review.md` (+ verdict) |

The coder is always reviewed by a *different* model family — no rubber-stamping your own work.

## Hands-free mode

```
/lean-spec:auto <slug>        drive one feature to closed; a Stop hook runs each phase
/lean-spec:auto-all           drain every open feature, one at a time
```

Or use Claude Code built-ins directly — no plugin code involved:

```
/goal features/<slug>/workflow.json has "phase": "closed", or stop after 20 turns
/loop /lean-spec:auto-all
claude -p "/lean-spec:auto <slug>"          # headless / CI
```

## Try the demo (no API key needed)

See the whole lifecycle run against a throwaway project — real CLI, real hooks, model steps simulated from a fixture so it's fully deterministic:

```bash
./scripts/demo.sh            # needs python3, git, and bash — drives a feature specifying → closed, then shows the gates rejecting a hand-edit and a non-APPROVE close
scripts/bootstrap-bats.sh    # one-time: vendors bats-core into .tools/ (gitignored)
.tools/bin/bats tests/       # the full suite, incl. the CI-enforced e2e drive
```

Details: [`tests/e2e_lifecycle.bats`](tests/e2e_lifecycle.bats) · [`scripts/demo.sh`](scripts/demo.sh) · [`tests/fixtures/demo-project/`](tests/fixtures/demo-project/).

## Documentation

- [`docs/PRD.md`](docs/PRD.md) — **what** we're building: architecture, skill surface, milestones, decisions.
- [`docs/CONSTITUTION.md`](docs/CONSTITUTION.md) — **how** we build it: stack, invariants, delegation ladder, TDD policy, quality bars.

## Roadmap

| Milestone | Scope | Status |
|---|---|---|
| M0 | scaffold · BATS harness · CI | ✅ done |
| M1 | state CLI + enforcement hooks | ✅ done |
| M2 | lifecycle skills + agents | ✅ done |
| M3 | e2e demo ✅ · headless CI smoke · marketplace publish · ship review → **1.0** | 🚧 in progress |
| M5 | external provider adapters (Gemini / OpenCode / Codex) · telemetry | post-1.0 |

## Requirements

- **Claude Code** (a recent version; exact floor pinned at release)
- **Python 3 ≥ 3.11** — stdlib only, no pip packages
- **bash** — the hooks and scripts are bash
- **git**

---

<p align="center"><sub><strong>lean-spec</strong> — for solo devs & small teams who want their AI agents disciplined.</sub></p>
