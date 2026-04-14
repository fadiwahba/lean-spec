# Project CLAUDE Example

Use this only if you intentionally want lean-spec called out in a repo's root `CLAUDE.md`.
For most product repos, this is not recommended; keep root `CLAUDE.md` generic and let lean-spec remain opt-in through `.claude/commands/lean-spec/`.

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
- `/lean-spec:start-spec <slug>`
- `/lean-spec:update-spec <slug>`
- `/lean-spec:implement-spec <slug>`
- `/lean-spec:review-spec <slug>`
- `/lean-spec:spec-status <slug>`
- `/lean-spec:resume-spec <slug>`
- `/lean-spec:close-spec <slug>`
```
