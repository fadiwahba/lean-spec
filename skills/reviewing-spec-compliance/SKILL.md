---
name: reviewing-spec-compliance
description: Step 1 of the two-skill review sequence — checks each acceptance criterion against the implementation and produces a PASS/FAIL verdict
---

## When to Invoke

Invoke as **Step 1** of the review sequence, immediately after reading `spec.md` and before invoking `reviewing-code-quality`. This skill is owned by the **Reviewer** subagent during the `reviewing` phase.

## Protocol

1. Read `features/<slug>/spec.md` and extract every acceptance criterion.
2. For each criterion, search the implementation for the behavior it describes.
3. Produce the compliance table (format below).
4. Emit a verdict.

Do not check code quality, style, or correctness here — that is `reviewing-code-quality`'s job.

## What Counts as PASS vs FAIL per Criterion

**PASS**: The implementation demonstrably satisfies the criterion. You can point to a specific file and line (or behavior) that fulfills it.

**FAIL — Missing**: The criterion describes behavior that does not exist in the implementation at all.

**FAIL — Partial**: The behavior exists but does not fully satisfy the criterion (e.g., missing an edge case stated in the AC, wrong output, missing guard).

**FAIL — Wrong**: The implementation does something that contradicts the criterion.

Do not FAIL for things outside the spec (extra features, additional files) — those are neutral unless they break a stated criterion.

## Output Format

```
## Spec Compliance Review — <slug>

| # | Acceptance Criterion | Status | Evidence |
|---|---|---|---|
| 1 | <criterion text verbatim> | PASS / FAIL | <file:line or "not found"> |
| 2 | ... | ... | ... |

### Gaps (FAIL items only)

For each FAIL:
- **AC<N>**: <what is missing or wrong, one sentence>

### Verdict: PASS | FAIL

<If PASS>: All acceptance criteria satisfied.
<If FAIL>: <N> criteria not met — see gaps above.
```

## Edge Cases

- If `spec.md` has no acceptance criteria, emit `Verdict: FAIL` and note "spec.md contains no verifiable criteria."
- If the implementation directory is empty or missing, emit `Verdict: FAIL` and note "no implementation found."
- Do not invent criteria beyond what is written in `spec.md`. Review exactly what was specified.

## After This Skill

Invoke `reviewing-code-quality` regardless of the compliance verdict. Both reviews run; the overall review result is FAIL if either skill returns FAIL.
