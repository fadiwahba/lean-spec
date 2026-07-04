---
name: spec
description: Specs the next feature slice (or a named one) by dispatching the architect agent to write features/<slug>/spec.md. Use --refine to revise an existing spec. One slice at a time — never decomposes the whole PRD upfront.
disable-model-invocation: true
---

# /lean-spec:spec [<slug>] [--refine]

## Preflight (fail-loud)

Before proposing or speccing any slice, verify the project docs the
architect depends on exist and are actually filled (not the
`/lean-spec:init` placeholder skeletons):

```
bin/lean-spec validate --project PRD.md
bin/lean-spec validate --project CONSTITUTION.md
```

If either `validate --project` call exits non-zero, STOP and show the
CLI's one-line message verbatim. Do not dispatch the architect against a
missing or placeholder PRD/CONSTITUTION — run `/lean-spec:init` then
`/lean-spec:plan` first.

## Determine the slug

- **No argument:** dispatch the `architect` agent (Task tool) to read
  `docs/PRD.md`, every `features/*/workflow.json` phase (via
  `bin/lean-spec status`), **and the `## Acceptance Criteria` of every
  closed slice's `spec.md`** — then propose the *next* slice (a slug and
  one-line scope) covering only PRD scope **not already delivered by a
  closed slice**. Present the proposal to the user for confirmation before
  writing anything.
- **`<slug>` given:** spec that named slice directly.
- **`--refine`:** the slug must already exist and have a `spec.md`; dispatch
  the architect to revise it in place (same slug, same file).

## Dispatch

1. `bin/lean-spec ensure <slug>` — idempotent; creates `workflow.json` in
   `specifying` phase if this is a new feature.
2. Dispatch the `architect` agent via Task, with `docs/CONSTITUTION.md`'s
   content injected into the prompt, plus `docs/PRD.md`, current feature
   status, **the `## Acceptance Criteria` of every closed slice's `spec.md`
   (the "already delivered" ledger, so the architect never re-specs shipped
   work),** and (on `--refine`) the reason for revision. The architect
   writes `features/<slug>/spec.md`.
3. The `SubagentStop` hook validates `spec.md` automatically the moment
   the architect finishes (early gate). As a backstop, also run:
   ```
   bin/lean-spec validate <slug> spec.md
   ```
   If it fails, dispatch the architect again with the validator's output
   as feedback — do not hand-patch `spec.md` yourself.
4. Tell the orchestrator to commit: `spec(<slug>): <one-line scope>`.

## Never does

- Write `spec.md` content itself — only the architect agent does, via
  Task dispatch.
- Advance `workflow.json` — `specifying` is the entry phase; `ensure` is
  the only state mutation this skill performs. Phase advances to
  `implementing` at `/lean-spec:implement`.
- Spec more than one slice per invocation (R8: no upfront decomposition).
- Dispatch the architect when `validate --project` fails for PRD.md or
  CONSTITUTION.md — the preflight is mandatory.
