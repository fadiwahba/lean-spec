---
name: plan
description: Runs the project interview and writes docs/PRD.md + docs/CONSTITUTION.md. Use --refine to fold in a blocker discovered during implementation, or --regenerate to redo from scratch. Runs in the session model, not a dispatched agent.
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

## Interview (≤3 rounds, default mode)

Use `AskUserQuestion` to cover, across up to three rounds:

1. Problem & users — what problem, who has it, why now.
2. Features — the feature list (no upfront per-feature detail — that's
   what `/lean-spec:spec` derives later, one slice at a time).
3. Constraints, quality bar, and non-goals.

Keep it to what's needed to fill `templates/PRD.md` and
`templates/CONSTITUTION.md`'s sections — don't over-interview.

## Write the docs

1. Copy the structure of `templates/PRD.md` and `templates/CONSTITUTION.md`
   into `docs/PRD.md` and `docs/CONSTITUTION.md`, filling every section
   from the interview answers. Keep `docs/CONSTITUTION.md` short — it is
   injected into every agent dispatch.
2. Validate both, via the CLI (never eyeball this):
   ```
   bin/lean-spec validate --project PRD.md
   bin/lean-spec validate --project CONSTITUTION.md
   ```
   If either fails, add the missing section(s) and re-run — do not
   proceed with a failing validate.
3. Tell the orchestrator (you) to commit:
   `docs: write PRD and CONSTITUTION` (first run) or
   `docs: refine PRD/CONSTITUTION — <blocker>` (`--refine`).

## Never does

- Decompose the PRD into per-feature specs — that is `/lean-spec:spec`'s
  job, one slice at a time (R8).
- Skip the `bin/lean-spec validate --project` check before committing.
