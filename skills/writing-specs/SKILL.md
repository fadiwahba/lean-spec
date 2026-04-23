---
name: writing-specs
description: Invoke when writing or revising a spec.md — guides the Architect role through structure, acceptance criteria quality, scope discipline, and coder-handoff hygiene. Caps spec length at ~80 lines.
---

## When to Invoke

Invoke when creating a new `spec.md` or revising an existing one. This skill is owned by the **Architect subagent** dispatched via `/lean-spec:start-spec` or `/lean-spec:update-spec`.

**Audience:** architect subagent only. The orchestrator never invokes this skill — if you are the orchestrator mediating between the user and the architect, dispatch the slash command instead of invoking this skill directly.

Do not invoke during `implementing` or later phases — specs are locked once submitted.

## spec.md Structure

Every `spec.md` must contain exactly these sections in this order. **Hard cap: ~80 lines total.** If you exceed it, the feature is probably too large — flag in Technical Notes and ask the user to split via `/update-spec`.

```markdown
---
slug: <feature-slug>
phase: specifying
handoffs:
  next_command: /lean-spec:submit-implementation <slug>
  blocks_on: []
  consumed_by: [coder, reviewer]
---

## Scope

One paragraph. What this feature does and why. No implementation details.

## Acceptance Criteria

- [ ] AC1: <specific, testable criterion>
- [ ] AC2: <specific, testable criterion>
...

## Out of Scope

Bullet list of things explicitly excluded. If nothing is excluded, write "None identified."

## Technical Notes

Optional. Constraints, contracts, dependencies the Coder must know. Tables/bullets only — no prose paragraphs. Omit if nothing to add.

## Coder Guardrails

Required when the implementation has known footguns for the target stack. Bullet list of 5–8 specific anti-patterns to avoid, each one line. Examples for React/Next: "use [...arr].sort(...) — never arr.sort() (mutates state)"; "useSyncExternalStore for browser-only data sources, not useEffect+useState".

Omit ONLY if the implementation is genuinely guardrail-free (rare).
```

## Structure rules (concision over detail)

- **Tables, not paragraphs**, for visual specs and any matrix data (states × behaviour, tokens × usage). One row per fact.
- **Bullets, not prose**, for lists of constraints, anti-patterns, and exclusions. One bullet per fact.
- **Reference, don't restate.** If the PRD specifies design tokens or shapes, link to the PRD section instead of copying.
- **Scope = one paragraph.** If you need more, you're describing implementation.
- **Each AC = one sentence + one verifiable observation.** Compound ACs (with "and" / "also") must be split.

## Acceptance Criteria Rules

Each criterion must be:
- **Testable**: A reviewer verifies by reading code or running the feature — never by asking "does it feel right?"
- **Specific**: Bad: "user can log in." Good: "submitting valid credentials redirects to `/dashboard` and sets an HTTP-only `auth` cookie."
- **Atomic**: One observable outcome per criterion.
- **Bounded**: Happy path stated. Edge cases go in Technical Notes unless they are the core behaviour.

Target **1–4 criteria**. If more than 4, the feature is too large — split.

## Scope Discipline

A spec is not a design doc. **Stop before:**
- Naming classes, files, or libraries inside ACs (unless the spec is *about* those artifacts)
- Listing every edge case as an AC (Technical Notes carry edge-case constraints)
- Specifying UI copy or exact styling unless that *is* the feature
- Writing more than one short paragraph in Scope

If Technical Notes is longer than Acceptance Criteria, trim it.

## Coder Guardrails — when to include

The Coder Guardrails section exists because cheap-tier coder models (Haiku, Sonnet 4) follow specs literally and benefit from explicit anti-patterns. Add it when:
- The target stack has known idiomatic traps (React state immutability, async cleanup, hydration mismatches)
- The PRD or codebase conventions imply patterns the spec text alone won't convey
- A prior review on a similar feature flagged a recurring footgun

**Format**: 5–8 bullets, each starting with the anti-pattern, then the corrective phrase. Example:
- "Mutating React state via array methods (`.sort()`, `.push()`, `.splice()`) — always copy first: `[...arr].sort(...)`"
- "`useEffect` for reading browser-only data on mount — use `useSyncExternalStore` instead (no SSR hydration mismatch)"

Omit if the spec genuinely has no stack-specific footguns.

## Frontmatter Checklist

Before submitting:
- [ ] `slug` matches the feature directory name
- [ ] `phase` is `specifying`
- [ ] `handoffs.next_command` is `/lean-spec:submit-implementation <slug>`
- [ ] Out of Scope section exists (even if "None identified.")
- [ ] Coder Guardrails included (or explicitly omitted with a one-line note in Technical Notes)
- [ ] Total file under ~80 lines
- [ ] No implementation details leaked into Scope or ACs
