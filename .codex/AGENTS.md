# lean-spec v3 — Codex project context

This file primes Codex for the lean-spec v3 lifecycle. Place it at the root of any project where you're using lean-spec; Codex reads `AGENTS.md` from the repo root as project-level instructions.

## The lifecycle

```
specifying  → implementing  → reviewing  → closed
     ^                           |
     |_______  submit-fixes  ____|   (if NEEDS_FIXES)
```

Each feature lives at `features/<slug>/` with four artifacts:

- `workflow.json` — phase + history (DO NOT hand-edit)
- `spec.md` — architect's output
- `notes.md` — coder's output (append-per-cycle in fixes mode)
- `review.md` — reviewer's output (archived to `review-cycle-N.md` across cycles)

## Invoking phases in Codex (degraded mode)

**Codex has no slash-command registry like Claude/Gemini/OpenCode, and no subagent dispatch.** So two-model cost arbitrage is unavailable — everything runs on your configured Codex model.

To run a phase, paste the appropriate prompt from `.codex/prompts/` into `codex`:

```bash
codex "$(cat .codex/prompts/start-spec.md)" --config model=gpt-5.4
# or interactively:
codex
# ... then paste the prompt content
```

The 11 prompt templates in `.codex/prompts/` mirror the Claude commands:

| Prompt | Role |
|---|---|
| `start-spec.md` | Create feature + draft spec.md |
| `update-spec.md` | Revise existing spec |
| `submit-implementation.md` | Advance to implementing + produce notes.md |
| `submit-review.md` | Advance to reviewing + produce review.md |
| `submit-fixes.md` | Roll back to implementing + address findings |
| `close-spec.md` | Finalize on APPROVE |
| `spec-status.md` | Print current phase |
| `next.md` | Resolve next phase command |
| `resume-spec.md` | Re-prime context |
| `brainstorm.md` | Draft project-level docs/PRD.md |
| `decompose-prd.md` | Emit feature skeletons from docs/PRD.md |

## Phase-gate discipline (manual in Codex)

Without hook enforcement, the agent must manually respect phase gates:

- `submit-implementation` requires current phase `specifying`
- `submit-review` requires `implementing`
- `submit-fixes` requires `reviewing` + `verdict: NEEDS_FIXES`
- `close-spec` requires `reviewing` + `verdict: APPROVE`

Every prompt template starts with a phase-gate check in bash. Trust the prompt; don't bypass.

## Coder's hard-forbidden edits (automatic critical-finding)

Even in Codex mode, the coder role must never edit these without an explicit spec mention:

- `package.json` and lockfiles (INCLUDING `scripts` fields)
- `next.config.*`, `tsconfig.json`, `eslint.config.*`, `postcss.config.*`, `tailwind.config.*`
- Root `app/layout.tsx` metadata / `<head>` / global providers
- Existing tests

The reviewer prompt template has a `git diff --name-only` sweep that flags these as Critical.

## Visual contract enforcement

For UI features with a binding visual contract (e.g. `docs/ux-design.png`), specs must express visual ACs as a numbered V1/V2/... Visual Checklist table, not prose. This was validated by experiment B2 on the Claude plugin — prose ACs let visual drift through review.

## Tier-enforcement caveat

The Claude Code plugin pins:
- architect → Opus
- coder → Haiku (cost-saver)
- reviewer → Opus

Codex runs everything on your `model =` setting in `config.toml`. If you want closest-to-Claude semantics, set `model = "gpt-5.4"` (or whatever OpenAI's top model is at the time) and accept the cost. For the cost-optimal split, use the Claude Code plugin instead.
