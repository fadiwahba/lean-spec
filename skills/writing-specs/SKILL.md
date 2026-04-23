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

### Visual Acceptance Criteria — ALWAYS a numbered table, NEVER prose

When the feature has a UI and the project ships a binding visual contract (e.g. `docs/ux-design.png` referenced in the PRD's Implementation Contract), the visual AC **must** be expressed as a numbered checklist table under a Technical Notes heading (`V1`, `V2`, `V3`...). The AC itself is a one-liner that defers to the table.

**Why:** prose visual ACs are not reviewable. The reviewer enforces what the spec encodes — if the spec says "recognisably matches the design," every visual detail is an opinion. If the spec says "V3 — ring is `rgba(255,107,53,0.15)` faint orange stroke at ~480px diameter," drift from that token is a first-class failing grade.

**Correct shape:**
```markdown
- [ ] AC4 — Visual contract. The running app at <url> satisfies every row in the Visual Checklist table (Technical Notes) when compared against <path/to/reference.png>.

## Technical Notes

**Visual checklist for AC4** (all must hold against `<path/to/reference.png>`):

| # | Requirement |
|---|---|
| V1 | Exact color tokens used — bg `#...`, primary `#...`, muted `#...`, ... |
| V2 | Vertical stack order: <elem> → <elem> → <elem> |
| V3 | Typography: <role> uses `<font>` `<weight>`, `<size>`, `<letter-spacing>`, `<case>` |
| V4 | Controls: <button> is `<size>` `<color>` with `<glyph>`; <button2> is ... |
| V5 | <State variants>: active = ..., inactive = ... |
| V6 | <Format invariants>: MM:SS always zero-padded, currency always 2 decimals, etc. |
```

**Each V-row must be checkable by eye or by `getComputedStyle`.** If a row says "looks balanced" you rewrote it wrong — rewrite it as an exact measurement or token. Minimum 3 rows for any UI-bearing feature; 6–8 is typical.

**Anti-pattern — do NOT do this:** `AC4: the page is visually recognisable as docs/ux-design.png — specifically with orange labels, mode pills, a ring containing readout, ...` (prose cramming).

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
- [ ] **If the feature has UI and the PRD references a binding visual contract: AC4 is a one-liner deferring to a numbered Visual Checklist table (V1, V2, …) in Technical Notes. Prose visual ACs are rejected.**
- [ ] Total file under ~80 lines
- [ ] No implementation details leaked into Scope or ACs
