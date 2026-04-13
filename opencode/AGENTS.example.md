# Project AGENTS Example

Use this as a merge example for an existing project's root `AGENTS.md`.

```md
# Lean-Spec OpenCode Workflow

This project uses `lean-spec` in OpenCode.

The workflow can be run in two ways:

- mixed mode:
  - Claude Code is the Architect
  - OpenCode is the Coder
- full OpenCode mode:
  - OpenCode `lean-spec-architect` is the Architect
  - OpenCode `lean-spec-coder` is the Coder

For lean-spec work in OpenCode:
- follow `.opencode/LEAN_SPEC_INSTRUCTIONS.md`
- use the runtime assets in:
  - `.opencode/agents/`
  - `.opencode/commands/lean-spec/`
  - `.opencode/skills/`
  - `.opencode/lean-spec/templates/`
- merge `opencode.example.json` into the project's root `opencode.json`
- configure MCP access for `context7`, `sequential_thinking`, and `playwright` so all lean-spec agents can use them

Canonical feature artifacts live in:
- `lean-spec/features/<slug>/spec.md`
- `lean-spec/features/<slug>/notes.md`
- `lean-spec/features/<slug>/review.md`

Lean-spec commands:
- `/lean-spec:plan <slug>`
- `/lean-spec:implement <slug>`
- `/lean-spec:review <slug>`
- `/lean-spec:status <slug>`
- `/lean-spec:resume <slug>`
- `/lean-spec:end <slug>`

Ownership rules:
- Architect owns `spec.md`
- Coder owns `notes.md`
- Architect owns `review.md`
- during implementation, the Coder must not edit `spec.md` or `review.md`
- for frontend/UI work, use `playwright` before claiming implementation or review completion unless it is explicitly unavailable
- use `context7` when external library or framework behavior matters
- use `sequential_thinking` for multi-step or risky work

If you are running mixed mode:
- use Claude for `/lean-spec:plan <slug>`, `/lean-spec:review <slug>`, `/lean-spec:end <slug>`
- use OpenCode for:
- `/lean-spec:implement <slug>`
- `/lean-spec:status <slug>`
- `/lean-spec:resume <slug>`

If you are running full OpenCode mode:
- assign your desired Architect and Coder models to the two OpenCode agents
- keep the same ownership and manual phase rules
```
