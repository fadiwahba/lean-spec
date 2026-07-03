---
name: init
description: One-time project bootstrap for lean-spec — scaffolds .lean-spec/rules.toml, docs/, features/, and the evidence .gitignore entry. Fail-loud preflight; idempotent (safe to re-run).
disable-model-invocation: true
---

# /lean-spec:init

Bootstraps a project for the lean-spec lifecycle. Runs once per project;
safe to re-run (idempotent — never overwrites existing files).

## Steps

1. **Preflight (fail-loud).** Run `bin/lean-spec status` from the plugin
   root. This alone exercises the CLI's own preflight: python3 >= 3.11 on
   PATH, and the current directory is inside a git repo. If it errors,
   stop and show the CLI's one-line message verbatim — do not paper over
   it or invent a workaround.

2. **Scaffold `.lean-spec/rules.toml`** — if it does not already exist,
   copy `examples/rules.toml` from the plugin into `.lean-spec/rules.toml`
   at the project root. If it already exists, leave it untouched (report
   that it already exists).

3. **Scaffold `docs/`** — if `docs/PRD.md` or `docs/CONSTITUTION.md` do
   not exist, copy the matching file from `templates/` into `docs/`. Do
   not overwrite either file if it already exists — `/lean-spec:plan` (or
   the user) fills these in next.

4. **Scaffold `features/`** — create the empty `features/` directory if
   absent (features are created individually by `/lean-spec:spec` via
   `bin/lean-spec ensure <slug>`; nothing to pre-populate here).

5. **`.gitignore`** — ensure a line matching `features/*/evidence/` is
   present; append it if missing. Never duplicate an existing entry.

6. **Report** what was created vs. already present, then tell the user to
   run `/lean-spec:plan` next.

## Never does

- Overwrite an existing `docs/PRD.md`, `docs/CONSTITUTION.md`, or
  `.lean-spec/rules.toml`.
- Create or touch anything under `features/<slug>/` — that starts at
  `/lean-spec:spec`.
- Make a git commit on the user's behalf without being asked.
