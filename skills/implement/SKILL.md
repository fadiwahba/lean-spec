---
name: implement
description: Advances a specced feature to implementing and dispatches the coder agent to build it with mandatory TDD (RED then GREEN), writing notes.md. Use --no-tdd to opt out for a spike.
---

# `implement` <slug> [--tdd|--no-tdd]

## Steps

1. Resolve TDD mode first: `--tdd` / `--no-tdd` flag > `.lean-spec/rules.toml`
   `[defaults].tdd` > default `true`.
2. `bin/lean-spec advance <slug> specifying implementing` — the state
   transition. **Pass the resolved mode through as a flag** so the CLI
   records it per-feature in `workflow.json`: append `--no-tdd` for a
   spike (or `--tdd` to pin it on against a `tdd = false` project
   default); omit for the plain default. This is what makes the
   `notes.md` gate (step 4) honor the opt-out — without it the CLI reads
   only the global default and rejects a `--no-tdd` `notes.md`. If the
   transition fails (wrong phase), stop and show the CLI's message; do
   not force it.
3. Dispatch the `coder` agent as a subagent, with `.lean-spec/CONSTITUTION.md`
   injected, `.lean-spec/features/<slug>/spec.md`, and the resolved TDD mode. The
   coder implements and writes `.lean-spec/features/<slug>/notes.md` (with `## TDD`
   evidence when TDD mode is on).
4. `SubagentStop` validates `notes.md` automatically when the coder
   finishes. Backstop:
   ```
   bin/lean-spec validate <slug> notes.md
   ```
   On failure, dispatch the coder again with the validator's output as
   feedback.
5. Commit the coder's work yourself (the coder never commits). With TDD
   on, this is normally two commits reflecting the coder's captured runs:
   `test(<slug>): red — failing ACs` then `feat(<slug>): green — <subject>`.
   With `--no-tdd`, a single `feat(<slug>): <subject>` commit.

## Never does

- Skip `bin/lean-spec advance` and edit `workflow.json` directly (hook
  blocks it anyway).
- Let the coder commit — commits are the orchestrator's job.
- Decide TDD pass/fail by reading prose — `bin/lean-spec validate` is the
  only gate for whether `## TDD` evidence is present.
