---
name: spec-status
description: Show the current lifecycle status of a lean-spec feature including open notes, review findings, and next recommended action.
---

Summarize lean-spec status for the feature slug in `$ARGUMENTS`.

## Rules

- Require a slug. If none is provided, ask for one.
- Read only:
  - `lean-spec/features/<slug>/spec.md`
  - `lean-spec/features/<slug>/notes.md`
  - `lean-spec/features/<slug>/review.md`
- Do not read source files.
- Do not make code changes.
- Infer phase and owner from the lean-spec artifacts only.

## Output Format

```text
# lean-spec status: <slug>

Phase:           <inferred from artifact state>
Owner:           <inferred current owner>
Feature status:  <status from spec.md>
Remaining tasks: <count or "none">
Open notes:      <count or "none">
Open findings:   <count or "none">
Next action:     <single concrete recommended action>
```

Keep the output compact. No narrative. No speculation about source code state.
