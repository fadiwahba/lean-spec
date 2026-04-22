---
name: reviewing-code-quality
description: Step 2 of the two-skill review sequence — checks implementation quality across conventions, correctness, security, and complexity
---

## When to Invoke

Invoke as **Step 2** of the review sequence, after `reviewing-spec-compliance` has completed. This skill is owned by the **Reviewer** subagent during the `reviewing` phase.

## What to Check

### Conventions
- Naming follows project patterns (files, variables, functions, exports)
- Directory structure matches the project layout
- Import style and module boundaries are consistent

### Correctness
- Logic handles the stated happy path and any edge cases noted in Technical Notes
- No off-by-one errors, missing null checks, or unhandled promise rejections in async paths
- Return values and side effects are correct and consistent

### Security
- No injection vectors (SQL, shell, template literals with untrusted input)
- No secrets or credentials hardcoded
- Input validated at system boundaries before use
- No OWASP Top-10 surface area introduced

### Complexity
- No unnecessary abstractions or premature generalization
- No dead code, unused stubs, or commented-out blocks
- Functions are single-purpose and reasonably sized
- No cyclomatic complexity spikes without justification

## Severity Ratings

| Severity | Definition | Blocks merge? |
|---|---|---|
| **Critical** | Incorrect behavior, security vulnerability, data loss risk | Yes |
| **Important** | Clear bug, significant convention violation, maintainability debt | Yes |
| **Minor** | Style preference, cosmetic, low-risk improvement | No |

Verdict is **FAIL** if any Critical or Important issues exist. Minor-only = PASS.

## Output Format

```
## Code Quality Review — <slug>

### Critical Issues
- `path/to/file.ts:42` — <description of issue>

### Important Issues
- `path/to/file.ts:17` — <description of issue>

### Minor Issues
- `path/to/file.ts:8` — <description of issue>

### Verdict: PASS | FAIL

<If PASS>: No critical or important issues found.
<If FAIL>: <N> critical / <N> important issues require fixes before merge.
```

Omit a severity section entirely if it has no issues. Do not emit an empty "Critical Issues" header.

## What Not to Do

- Do not re-check spec compliance — that was Step 1.
- Do not flag stylistic preferences as Important or Critical.
- Do not flag missing features that are explicitly listed as Out of Scope in `spec.md`.
- Do not recommend architectural redesigns unless the current design introduces a Critical issue.

## After This Skill

Combine both verdicts (spec compliance + code quality). The overall review result is:
- **APPROVE** if both return PASS
- **NEEDS_FIXES** if either returns FAIL

Report the combined verdict and the full list of required fixes to the user.
