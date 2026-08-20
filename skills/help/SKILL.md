---
name: help
description: Read-only — prints an overview of lean-spec, the lifecycle and every skill with when to use each. Start here if you're new. Makes no changes and runs no command.
---

# `help`

New here? This is the map. lean-spec runs every feature through a fixed,
harness-enforced lifecycle — you drive it with the skills below. When
invoked, present this overview to the user; do **not** run any command or
dispatch any agent — this skill only informs.

## The lifecycle

`init` → `plan` → (per feature) `spec` → `implement` → `review` → [`fix` ⇄ `review`] → `close`

- `init`/`plan` run once to set the project up; everything after repeats
  once per feature.
- Each phase has one owner agent, one mandatory artifact, and one gate the
  model cannot skip — the CLI mutates state, hooks enforce, skills only
  describe.

## Setup — run once per project

- `init` — scaffold `.lean-spec/`, `.lean-spec/`, `.lean-spec/features/`,
  `.gitignore`; preflight the environment (python3 ≥ 3.11, git repo).
- `plan` ["<idea>"]` — short interview → `.lean-spec/PRD.md` +
  `.lean-spec/CONSTITUTION.md` (grounds itself in an existing repo for
  brownfield). `--refine` folds in a blocker without re-interviewing.

## Per feature — repeat

- `spec` [<slug>]` — the architect writes the next slice's
  `spec.md`. No slug derives the next slice from the PRD; `--refine`
  revises; `--no-confirm` skips the confirmation for unattended runs.
- `respec` <slug>` — revise an existing spec in place.
- `implement` <slug>` — the coder builds it RED → GREEN with
  captured TDD evidence. `--no-tdd` opts out for a spike.
- `review` <slug>` — a reviewer — by default a different model
  than the coder — writes a verdict. `--visual` captures UI screenshot
  evidence.
- `fix` <slug>` — address a `NEEDS_FIXES` verdict, then
  re-review.
- `close` <slug>` — closes the feature; refuses unless the
  verdict is `APPROVE`.

## Hands-free — optional

- `auto` <slug>` — drive one already-specced feature to done
  unattended (a Stop hook runs each phase).
- `auto-all` [--no-confirm]` — drive every non-closed feature;
  with `--no-confirm` it also specs the next slice on demand, so a whole
  small PRD builds from a single command.

## Read-only — safe any time

- `next` [<slug>|--all]` — what to run next.
- `status` [<slug>]` — where each feature is.
- `help` — this overview.

Full detail: `README.md` (command reference), `.lean-spec/PRD.md` (what it is),
`.lean-spec/CONSTITUTION.md` (how it's built).

## Never does

- Run a lifecycle command, dispatch an agent, or mutate any state — help
  only informs.
