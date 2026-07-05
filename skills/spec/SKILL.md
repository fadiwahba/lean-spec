---
name: spec
description: Specs the next feature slice (or a named one) by dispatching the architect agent to write features/<slug>/spec.md. Use --refine to revise an existing spec, --no-confirm to skip the propose-confirmation for an unattended run (auto-all). One slice at a time — never decomposes the whole PRD upfront.
disable-model-invocation: true
---

# /lean-spec:spec [<slug>] [--refine] [--no-confirm]

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
  closed slice's `spec.md`** — then propose the *next* slice. The
  architect's entire response is either `<slug>: <one-line scope>`, or,
  if no PRD scope remains undelivered, the literal sentinel
  `NO_REMAINING_SCOPE`.
  - **Without `--no-confirm`:** present the proposal to the user for
    confirmation before writing anything.
  - **With `--no-confirm`:** skip that confirmation — there is no live
    user to answer it in an unattended run (e.g. driven by
    `/lean-spec:auto-all --no-confirm`). Parse the response as
    `<slug>: <scope>`; treat the sentinel, or *any* response that
    doesn't parse that way (padding, extra prose, garbage, empty), the
    same — fail-safe, not exact-string-match-only. On the
    sentinel/unparseable case: delete `.lean-spec/auto.json` if it
    exists (a no-op if it doesn't — e.g. a cold-start caller that hasn't
    written it yet) and stop, reporting that the PRD is fully covered;
    write nothing. Otherwise proceed straight to Dispatch below with the
    parsed slug.
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

`.lean-spec/auto.json` is never touched by this skill except the one
delete described above (the sentinel/unparseable case) — no slug or
cycle bookkeeping is this skill's job, whether run standalone or chained
from `/lean-spec:auto-all --no-confirm`.

## Never does

- Write `spec.md` content itself — only the architect agent does, via
  Task dispatch.
- Advance `workflow.json` — `specifying` is the entry phase; `ensure` is
  the only state mutation this skill performs. Phase advances to
  `implementing` at `/lean-spec:implement`.
- Spec more than one slice per invocation (R8: no upfront decomposition)
  — true with or without `--no-confirm`.
- Dispatch the architect when `validate --project` fails for PRD.md or
  CONSTITUTION.md — the preflight is mandatory.
- Retry or guess when the propose-dispatch response is ambiguous — treat
  any unparseable response as `NO_REMAINING_SCOPE` (fail-safe), never
  loop trying to reinterpret it.
