# Project CLAUDE Example

Use this as a merge example for an existing project's root `CLAUDE.md`.

```md
## Lean-Spec

This project uses `lean-spec` for feature delivery.

For lean-spec work, read and follow:
- `.claude/LEAN_SPEC_INSTRUCTIONS.md`

Use the runtime assets in:
- `.claude/agents/lean-spec/`
- `.claude/commands/lean-spec/`
- `.claude/hooks/lean-spec/`
- `.claude/lean-spec/templates/`

Merge hook configuration from:
- the lean-spec settings example into `.claude/settings.json`

The canonical feature artifacts live in:
- `lean-spec/features/<slug>/spec.md`
- `lean-spec/features/<slug>/notes.md`
- `lean-spec/features/<slug>/review.md`

This workflow is human-controlled.
Advance phases only when the human explicitly runs:
- `/plan <slug>`
- `/implement <slug>`
- `/review <slug>`
- `/status <slug>`
- `/resume <slug>`
- `/end <slug>`
```
