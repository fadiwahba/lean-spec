# Project GEMINI Example

Use this only if you intentionally want lean-spec called out in a repo's root `GEMINI.md`.
For most product repos, this is not recommended; keep root `GEMINI.md` generic and let lean-spec remain opt-in through `.gemini/commands/lean-spec/`.

```md
# Lean-Spec

This project uses `lean-spec` for feature delivery in Gemini CLI.

For lean-spec work, read and follow:
- `.gemini/LEAN_SPEC_INSTRUCTIONS.md`

Use the runtime assets in:
- `.gemini/commands/lean-spec/`
- `.gemini/hooks/lean-spec/`
- `.gemini/lean-spec/templates/`

Merge hook and model configuration from:
- the lean-spec Gemini settings example into `.gemini/settings.json`

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

Recommended session split:
- use `gemini -m gemini-3-pro-preview` for planning, review, status, resume, and end
- use `gemini -m gemini-3-flash-preview` for implementation

Gemini `Architect` and `Coder` are session roles, not native spawned subagents.
If a lean-spec phase is started in the wrong session, stop and rerun it in the intended model session.
For lean-spec work, use `context7` before implementation or review when external library or framework behavior matters, use `sequential_thinking` for multi-step or risky work, and use `playwright` for frontend/UI validation before claiming implementation or review completion unless the tool is explicitly unavailable.
```
