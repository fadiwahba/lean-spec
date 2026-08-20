---
name: spec
description: Specs the next feature slice (or a named one) by dispatching the architect agent to write .lean-spec/features/<slug>/spec.md. Use --refine to revise an existing spec, --no-confirm to skip the propose-confirmation for an unattended run (auto-all). One slice at a time — never decomposes the whole PRD upfront.
---

# `spec` [<slug>] [--refine] [--no-confirm]

## Preflight (fail-loud)

Before proposing or speccing any slice, verify the project docs and unattended
readiness. `--no-confirm` skips proposal approval only; it never permits a
missing requirement to be invented.

```
bin/lean-spec validate --project PRD.md
bin/lean-spec validate --project CONSTITUTION.md
bin/lean-spec readiness --no-confirm --json
```

If a project validation exits non-zero, stop and show its message. If
`readiness` returns `NEEDS_INPUT`, ask its one question and resume `plan`.
Do not dispatch the architect against missing, placeholder, or incomplete
project requirements.

## Determine the slug

- **No argument:** dispatch the `architect` agent (subagent) to read
  `.lean-spec/PRD.md`, every `.lean-spec/features/*/workflow.json` phase (via
  `bin/lean-spec status`), **and the `## Acceptance Criteria` of every
  closed slice's `spec.md`** — then propose the *next* slice. The
  architect's entire response is either `<slug>: <one-line scope>`, or,
  if no PRD scope remains undelivered, the literal sentinel
  `NO_REMAINING_SCOPE`.
  - **Without `--no-confirm`:** present the proposal to the user for
    confirmation before writing anything.
  - **With `--no-confirm`:** skip that confirmation — there is no live
    user to answer it in an unattended run (e.g. driven by
    `auto-all` --no-confirm`). Parse the response as
    `<slug>: <scope>`; treat the sentinel, or *any* response that
    doesn't parse that way (padding, extra prose, garbage, empty), the
    same — fail-safe, not exact-string-match-only. On the
    sentinel/unparseable case, report that the PRD is fully covered and let
    the CLI-owned automatic run return `COMPLETE`; write no state directly.
    Otherwise proceed straight to Dispatch below with the parsed slug.
- **`<slug>` given:** spec that named slice directly.
- **`--refine`:** the slug must already exist and have a `spec.md`; dispatch
  the architect to revise it in place (same slug, same file).

## Dispatch

1. `bin/lean-spec ensure <slug>` — idempotent; creates `workflow.json` in
   `specifying` phase if this is a new feature.
2. Dispatch the `architect` agent as a subagent, with `.lean-spec/CONSTITUTION.md`'s
   content injected into the prompt, plus `.lean-spec/PRD.md`, current feature
   status, **the `## Acceptance Criteria` of every closed slice's `spec.md`
   (the "already delivered" ledger, so the architect never re-specs shipped
   work),** and (on `--refine`) the reason for revision. The architect
   writes `.lean-spec/features/<slug>/spec.md`.
3. The `SubagentStop` hook validates `spec.md` automatically the moment
   the architect finishes (early gate). As a backstop, also run:
   ```
   bin/lean-spec validate <slug> spec.md
   ```
   If it fails, dispatch the architect again with the validator's output
   as feedback — do not hand-patch `spec.md` yourself.
4. Tell the orchestrator to commit: `spec(<slug>): <one-line scope>`.

This skill never touches `.lean-spec/auto.json`. The CLI owns all automatic
run state, including completion, pending input, slug, and cycle bookkeeping.

## Never does

- Write `spec.md` content itself — only the architect agent does, via
  subagent dispatch.
- Advance `workflow.json` — `specifying` is the entry phase; `ensure` is
  the only state mutation this skill performs. Phase advances to
  `implementing` at `implement`.
- Spec more than one slice per invocation (R8: no upfront decomposition)
  — true with or without `--no-confirm`.
- Dispatch the architect when `validate --project` fails for PRD.md or
  CONSTITUTION.md — the preflight is mandatory.
- Retry or guess when the propose-dispatch response is ambiguous — treat
  any unparseable response as `NO_REMAINING_SCOPE` (fail-safe), never
  loop trying to reinterpret it.
