---
name: plan
description: Runs the project interview and writes .lean-spec/PRD.md + .lean-spec/CONSTITUTION.md. Use --refine to fold in a blocker discovered during implementation, or --regenerate to redo from scratch. Runs in the session model, not a dispatched agent.
disable-model-invocation: true
---

# /lean-spec:plan ["<idea>"] [--refine] [--regenerate]

Runs in the session model directly (`rules.toml` → `[agents] plan = {
model = "session" }`) — no Task dispatch. You are the planner here.

## Modes

- **Default (first run)** — full interview, then write both docs from
  scratch.
- **`--refine`** — a blocker surfaced during implementation needs a PRD or
  CONSTITUTION change before the next slice can be specced. Ask only about
  the blocker; do not re-run the full interview. Append/update the
  relevant section(s); do not discard existing content.
- **`--regenerate`** — discard and redo the full interview, overwriting
  both docs. Confirm with the user before overwriting non-empty files.

## Ground the interview in the existing repo (before round 1)

If the project already contains code, read what is there before you ask —
do not interview a brownfield repo as if it were greenfield:

- Detect the stack from the manifests actually present (`package.json`,
  `pyproject.toml`/`requirements.txt`, `go.mod`, `Cargo.toml`, `Gemfile`,
  …), the test runner / CI config, and `README`.
- Skim `git log` for the commit convention and branching already in use.

Propose the `Stack`, `Principles`, and `Delegation` sections pre-filled
from what you found and ask the user to confirm or correct — rather than
asking them to describe from scratch what the repo already states. On an
empty (greenfield) repo this finds nothing and the interview proceeds as
normal.

## Interview (≤3 rounds, default mode)

Use `AskUserQuestion` to cover, across up to three rounds:

1. Problem & users — what problem, who has it, why now.
2. Features — the feature list (no upfront per-feature detail — that's
   what `/lean-spec:spec` derives later, one slice at a time).
3. Constraints, quality bar, and non-goals — explicitly ask whether this
   project wants TDD (`.lean-spec/rules.toml` defaults `tdd = true`, i.e.
   every `/lean-spec:implement`/`fix` run demands a RED-then-GREEN test
   suite). Do not let the answer land only in prose: a Quality Bar that
   says "no test suite" while `rules.toml` still enforces TDD is a
   contradiction the coder agent will hit mid-implementation, not
   something to resolve later.

Keep it to what's needed to fill `templates/PRD.md` and
`templates/CONSTITUTION.md`'s sections — don't over-interview.

## Write the docs

1. Copy the structure of `templates/PRD.md` and `templates/CONSTITUTION.md`
   into `.lean-spec/PRD.md` and `.lean-spec/CONSTITUTION.md`, filling every section
   from the interview answers. Keep `.lean-spec/CONSTITUTION.md` short — it is
   injected into every agent dispatch.
2. If the TDD answer is "no automated tests," set `tdd = false` under
   `[defaults]` in `.lean-spec/rules.toml` in this same step — the
   Constitution's Quality Bar and the CLI's actual gate must agree from
   the start, not after a coder cycle discovers the mismatch.
3. Validate both, via the CLI (never eyeball this):
   ```
   bin/lean-spec validate --project PRD.md
   bin/lean-spec validate --project CONSTITUTION.md
   ```
   If either fails, add the missing section(s) and re-run — do not
   proceed with a failing validate.
4. Tell the orchestrator (you) to commit:
   `docs: write PRD and CONSTITUTION` (first run) or
   `docs: refine PRD/CONSTITUTION — <blocker>` (`--refine`).

## Never does

- Decompose the PRD into per-feature specs — that is `/lean-spec:spec`'s
  job, one slice at a time (R8).
- Skip the `bin/lean-spec validate --project` check before committing.
