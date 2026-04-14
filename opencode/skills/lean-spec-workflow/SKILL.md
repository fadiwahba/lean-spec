---
name: lean-spec-workflow
description: Follow the lean-spec workflow with strict artifact ownership and manual phase discipline
compatibility: opencode
metadata:
  workflow: lean-spec
  role: coder
---

## What This Skill Does

- reinforces lean-spec artifact ownership
- keeps planning anchored to `spec.md`
- keeps implementation work anchored to `spec.md`
- keeps implementation-side notes in `notes.md`
- keeps formal review in `review.md`
- prevents accidental rewrites of the wrong artifacts

## When To Use It

Use this skill whenever OpenCode is asked to:
- plan a lean-spec feature
- implement a lean-spec feature
- review a lean-spec feature
- end a lean-spec feature
- rebuild context for an existing feature

## Workflow

1. Read the canonical lean-spec artifacts relevant to the current phase
2. Respect ownership:
   - Architect -> `spec.md`, `review.md`
   - Coder -> `notes.md`
3. Perform only the current manual phase
4. Update only the artifacts owned by the active role
5. Use `context7` when external library or framework behavior matters
6. Use `sequential_thinking` for multi-step or risky work
7. Use `playwright` for frontend/UI validation before claiming implementation or review completion unless it is explicitly unavailable
8. Close any opened Playwright browser, context, or page before ending the phase
9. Do not save Playwright screenshots or captures into the project root; store any screenshots, images, audio, PDFs, or other lean-spec evidence files only under `lean-spec/features/<slug>/artifacts/`
10. When a phase starts a local dev server or opens a validation port, stop it before ending the phase; use a project-approved cleanup command such as `npx kill-port 3000` when needed
11. Use shell-backed timestamps when editing artifacts
12. Stop and wait for the next human command
13. Do not bypass the role owner for small or one-line fixes during `implement-spec`; the orchestrator must not edit implementation files directly
14. If required verification is incomplete, report it and stop instead of offering ad hoc workaround choices inside the phase

## Hard Rules

- Do not let the wrong role take ownership of the wrong artifact
- During implementation, do not let the Coder edit `spec.md` or `review.md`
- Do not auto-advance phases
- Do not claim final completion unless the end phase and artifacts support it
- Use a shell-backed timestamp when editing lean-spec artifacts
- Report whether `context7`, `sequential_thinking`, and `playwright` were used or unavailable when relevant
