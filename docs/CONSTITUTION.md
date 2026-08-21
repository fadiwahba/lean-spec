# lean-spec v4 — Constitution

> **How we build.** What we build lives in `docs/PRD.md`. This file is injected into every agent dispatch — keep it under ~90 lines. Amendments require Fady's sign-off.

---

## Stack

- Bash (hooks) + **Python 3 ≥ 3.11, stdlib only** (state CLI; JSON for state, `tomllib` for config). No `jq`, no `yq`, no YAML, no Node.js, no pip packages.
- Markdown: skills (`skills/*/SKILL.md`), agents (`agents/*.md`), artifacts, templates.
- Tests: Python 3.11 stdlib `unittest` (`python3 -m unittest discover -s tests -p 'test_*.py'`). CI: GitHub Actions.
- Target: Claude Code ≥ 2.1.198 (documented floor; not machine-enforced in the manifest).

## Architecture principles (non-negotiable)

1. **Layer rule** — skills describe, hooks enforce, the CLI mutates. Gate logic never lives in a skill prompt.
2. **State is single-sourced** in `.lean-spec/features/*/workflow.json`, `.lean-spec/auto.json`, and `.lean-spec/dispatch.json`; all are mutated only by `bin/lean-spec` (`ensure`/`advance`, `auto`, and `dispatch`). Never hand-write or hand-delete them. The PreToolUse guard denies direct supported-tool and Bash references to all three state paths. `auto.json` carries the higher stake: once it exists the Stop hook drives phases whose mutating skills require explicit invocation, so **arming, re-arming, or disarming a run is the user's decision, never the model's.**
3. **Phase transitions are atomic**: tmp file + `os.replace` + post-advance assertion.
4. **Artifacts gate phases**: an invalid artifact blocks the advance; validation runs at `SubagentStop` (early) and at the phase gate (backstop).
5. **Additive config**: absent `rules.toml` keys enforce nothing; zero-config first run must complete a full cycle.
6. **Idempotency everywhere**: `ensure` and re-running any skill in its own phase is a no-op, never an error.
7. **One spec at a time**: no upfront decomposition — the next slice is specced only after the previous one closes; blockers refine the PRD first.
8. **Fail loudly, never silently**: every entry point preflights its environment — `python3 ≥ 3.11` on PATH, Claude Code ≥ the pinned floor, inside a git repo, required files present — and exits non-zero with a one-line actionable message naming exactly what is missing and how to fix it (e.g. `lean-spec: python3 >= 3.11 required (found 3.9.6) — brew install python3`). No silent fallbacks, no swallowed exceptions, no degraded "best effort" paths; a gate that fails prints which check failed and why.

## Delegation ladder — who does what (building v4 itself)

| Role | Model / effort | Owns | Never does |
|---|---|---|---|
| **Orchestrator & planner** | **Opus 4.8 · effort xhigh** (session) | PRD, CONSTITUTION, next-slice arbitration, phase advances, git commits, unblocking decisions | writing specs, implementation code, per-feature reviews |
| **Architect (spec writer)** | **Opus 4.8 · effort xhigh** | `.lean-spec/features/<slug>/spec.md` (Scope, ACs, Out of Scope, Coder Guardrails) | touching app code or state |
| **Coder (implementer)** | **Sonnet 5 · effort high** | implementation **with TDD (mandatory)**, `notes.md` + `## TDD` evidence | editing spec.md, review.md, workflow.json, git commits |
| **Per-feature reviewer** | **Opus 4.8 · effort high** (project may downshift to Sonnet 5 via rules.toml) | `review.md` with `verdict: APPROVE\|NEEDS_FIXES\|BLOCKED`; with `--visual`: browser evidence (Playwright CLI via `Bash`) in `.lean-spec/features/<slug>/evidence/visual/` | fixing code itself |
| **Final ship reviewer** | **Opus 4.8 · effort xhigh** | F12 whole-project review before 1.0: bug sweep, invariant audit, ship/no-ship verdict | rubber-stamping — findings block release |

Rationale: spend the strongest configuration where judgment concentrates — planning/arbitration and the final ship gate both run on **Opus 4.8 at xhigh effort**. Everything delegable is delegated. Same-model self-review within a feature is forbidden: the coder (Sonnet) is always reviewed by a different family (Opus). The final ship gate is a distinct pass — a fresh agent and context at **higher effort (xhigh)** than the per-feature reviewer (Opus · high), reviewing the whole project rather than one slice — so it stays an independent set of eyes even though it shares the Opus family.

## TDD policy (mandatory for all v4 features)

- **RED first**: failing tests per Acceptance Criterion, run captured, committed as `test(<slug>): red — failing ACs`.
- **GREEN second**: implement until pass, run captured, committed as `feat(<slug>): green — <subject>`.
- Evidence lives in `notes.md ## TDD`; `bin/lean-spec validate` blocks review without it.
- Tests are never weakened to pass; reviewer explicitly checks for it.
- The state CLI and hooks themselves are Python-unittest-tested before any skill depends on them (M1 before M2).

## Quality bars

- All Python unittest tests green on every commit — no exceptions, no skips.
- Artifact caps: spec ≤2000 tokens, notes ≤6000, review ≤8000 (enforced via rules.toml).
- `close` requires `verdict: APPROVE`. No manual override path exists.
- `--visual` reviews must save every screenshot under `.lean-spec/features/<slug>/evidence/visual/` and cite each in `review.md` — evidence outside that folder fails the gate. The folder is **gitignored** (`init` scaffolds the entry): evidence is a local audit aid; the `review.md` citations are the durable record.
- Every shell script passes `bash -n`; every CLI command and gate has Python unittest coverage (the environment preflights — missing `python3`/`git` — abort before any command runs and are the one exception).
- macOS + Linux portable: `mktemp` X-suffix pattern, no GNU-only flags, glob via Python not zsh.

## Process

- **Dogfood rule**: from F6 onward, every feature ships through the v4 lifecycle itself (spec → implement → review → close). M0–M1 are hand-built by necessity, still TDD.
- One feature in flight at a time. `BLOCKED` verdicts stop the line and escalate to Fady.
- Commits: `type(scope): short subject` — types `feat|fix|refactor|docs|chore|test|spec|review` (`spec`/`review` scope the lifecycle skills' own commits); no Co-Authored-By; no emoji.
- Version bumps: `.claude-plugin/plugin.json` only (single manifest — no Gemini twin in v4). CHANGELOG follows Keep a Changelog, new block above `[Unreleased]`.
- Never commit `.env*` or credentials. No new dependency without Fady's explicit approval. No destructive git (`reset --hard`, `push --force`) without explicit confirmation.

## Hard non-goals (do not build, even if tempting)

- Cross-provider command ports; per-provider command copies.
- Web dashboards, servers, databases — artifacts + git are the interface.
- Speculative abstraction: no plugin-API layers, adapter registries, or config options without a live consumer.
