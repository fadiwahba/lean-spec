---
name: writing-specs
description: Invoke when writing or revising a spec.md — guides the Architect role through structure, acceptance criteria quality, and scope discipline
---

## When to Invoke

Invoke when creating a new `spec.md` or revising an existing one. This skill is owned by the **Architect subagent** dispatched via `/lean-spec:start-spec` or `/lean-spec:update-spec`.

**Audience:** architect subagent only. The orchestrator never invokes this skill — if you are the orchestrator mediating between the user and the architect, stop and dispatch `/lean-spec:start-spec` or `/lean-spec:update-spec` instead of invoking this skill directly.

Do not invoke during `implementing` or later phases — specs are locked once submitted.

## spec.md Structure

Every `spec.md` must contain exactly these sections in this order:

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

Optional. Architecture hints, constraints, API contracts, or dependencies the Implementer must know. Omit if none.
```

## Acceptance Criteria Rules

Each criterion must be:
- **Testable**: A reviewer can verify it by reading code or running the feature — not by asking "does it feel right?"
- **Specific**: Includes the exact behavior, not a vague description. Bad: "user can log in." Good: "submitting valid credentials redirects to /dashboard and sets an auth cookie."
- **Atomic**: One observable outcome per criterion. Split compound criteria.
- **Bounded**: States the happy path. Edge cases belong in Technical Notes unless they are the core behavior.

Target **1–4 criteria**. If you have more than 4, ask whether the feature is too large and should be split.

## Scope Discipline

A spec is not a design doc. Stop before:
- Describing internal implementation (how to structure files, which classes to use)
- Listing every edge case as an AC
- Specifying UI copy or exact styling unless that is the feature
- Writing more than one short paragraph in the Scope section

If the Technical Notes section is longer than the Acceptance Criteria section, trim it.

## Frontmatter Checklist

Before submitting the spec:
- [ ] `slug` matches the feature directory name
- [ ] `phase` is `specifying`
- [ ] `handoffs.next_command` is `/lean-spec:submit-implementation <slug>`
- [ ] All ACs are verifiable without ambiguity
- [ ] Out of Scope section exists (even if "None identified.")
- [ ] No implementation details leaked into Scope or ACs
