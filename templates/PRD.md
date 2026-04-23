# <Product Name> — Product Requirements Document

<!--
This template is the lean-spec v3 canonical PRD shape. It is consumed by the
(planned) `/lean-spec:brainstorm` and `/lean-spec:decompose-prd` commands in M2
and can be used standalone today as a starting point for greenfield projects.

Why this shape works:
- Named elements + exact tokens → Reviewer can spot-check visually (and with
  Playwright visual-fidelity review) without guessing.
- Tables over prose → coder can scan; reviewer can check AC-by-AC.
- "Implementation Contract" makes design fidelity a first-class requirement,
  not an aesthetic afterthought.

Fill in every `<angle-bracketed>` placeholder. Remove any section that does not
apply (e.g. omit §2 if the project has no UI). Keep it tight — the PRD is the
source of truth, not a design document; specs derived from it go deeper.
-->

**Figma source:** <link or "N/A">
**Design reference (binding visual contract):** `docs/ux-design.<png|jpg>` (omit if no UI)
**Status:** Draft
**Last updated:** YYYY-MM-DD

---

## Implementation Contract

<!-- Omit this whole section if the project has no UI. -->

**`docs/ux-design.<ext>` is the binding visual contract for this feature.** The implementation must match this design in:

- **Typography** — <fonts referenced in §2>
- **Color palette** — the tokens listed in §2 (exact hex values)
- **Layout** — <one-line layout summary — "centred column", "two-pane split", etc.>
- **Components** — every named element in §4 renders recognisably as in the reference

Pixel-perfect spacing/padding is not required. Visual recognisability is. If the rendered UI cannot be mistaken for the design reference at a glance, the implementation is incomplete. The Reviewer subagent must treat deviations from the reference as first-class findings, not cosmetic nits.

Acceptance Criteria in the feature spec must encode visual requirements alongside functional ones — omitting visual ACs is itself a spec bug.

---

## 1. Overview

<!-- 2–4 sentences. What is it, who uses it, what tech stack, what scope boundary. -->

---

## 2. Design Language

<!-- Omit if no UI. Values must be exact — "roughly dark orange" is not acceptable. -->

| Token | Value | Usage |
|---|---|---|
| <token name> | `<exact hex or rgba>` | <where it's used> |

**Typography**
- <role>: `<font family>` `<weight>`, `<size>`, <other attrs: letter-spacing, case>

---

## 3. Layout

<!-- One short paragraph describing the macro layout. No per-pixel specs. -->

---

## 4. Features

<!--
Each sub-section is ONE named UI element or ONE feature capability.
The Reviewer checks these names against the rendered DOM. Name them the same
way a user would describe them ("Add Task Input", not "TaskInputComponent").
-->

### 4.1 <Named element or capability>

- <bullets of behaviour / what it does / what user sees>

### 4.2 <Named element or capability>

| Element / State | Behaviour / Visual |
|---|---|
| <name> | <description> |

<!-- Repeat 4.x as needed. Prefer tables when comparing states or variants. -->

---

## 5. State Model

```ts
// Only include if there is meaningful client or server state.
type AppState = {
  // ...
};
```

<!-- Note persistence strategy: localStorage, in-memory, server-side, etc. -->

---

## 6. Derived Values

<!-- Omit if nothing is derived. Otherwise: table showing how displayed values
     come from state. This prevents the coder from re-deriving them differently
     in multiple places. -->

| Value | Derivation |
|---|---|
| <displayed value> | `<expression from §5 state>` |

---

## 7. Interactions Summary

<!-- The user-facing action → trigger → result table. This is the coder's
     checklist and the reviewer's AC source. -->

| Action | Trigger | Result |
|---|---|---|
| <action> | <event / gesture> | <state change + UI change> |

---

## 8. Out of Scope (v1)

<!-- Explicit list of things intentionally excluded. Prevents scope creep and
     gives the architect a clear boundary when drafting feature specs. -->

- <excluded item>
