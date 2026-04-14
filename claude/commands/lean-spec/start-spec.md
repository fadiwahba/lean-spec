---
name: start-spec
description: Create or locate a lean-spec feature folder and run the planning phase with the Architect agent.
---

Run the manual lean-spec planning phase for the feature slug in `$ARGUMENTS`.

Rules:
- Require a kebab-case slug. If no slug is provided, ask for one.
- The default session agent is the orchestrator. It owns scaffolding, routing, and concise status reporting.
- The Architect agent owns `spec.md`.
- The orchestrator must not write the substantive implementation plan into `spec.md`.
- Template files live under `.claude/lean-spec/templates/` in the target project.
- If `lean-spec/features/<slug>/` does not exist, create it and scaffold:
  - `spec.md`
  - `notes.md`
  - `review.md`
- Use `.claude/lean-spec/templates/` as the source for scaffolded files.
- If the feature folder already exists, do not overwrite files. Reuse the existing folder.
- Read only the minimum relevant repository context needed to help the Architect plan accurately.
- Stop after the Architect has written or updated `spec.md`.
- Do not continue to implementation automatically. The human must explicitly run `/lean-spec:start-spec`, `/lean-spec:implement-spec`, `/lean-spec:review-spec`, `/lean-spec:spec-status`, `/lean-spec:resume-spec`, or `/lean-spec:close-spec` next as needed.
- Before writing scaffolded artifact files, retrieve the current timestamp from the shell with a command such as `date "+%Y-%m-%d %H:%M %Z"`.
- Use the shell-fetched timestamp for `Created At`, `Updated At`, and the initial change-log entry.
- Do not invent, estimate, hardcode, or round timestamps. Placeholder values such as `YYYY-MM-DD HH:MM TZ` or fabricated values such as `00:00 UTC` are invalid.

Steps:
1. Normalize the slug from `$ARGUMENTS`.
2. Create `lean-spec/features/<slug>/` if needed.
3. Copy the template files from `.claude/lean-spec/templates/` if they do not already exist.
4. Retrieve the current timestamp from the shell once for the scaffold pass.
5. Replace obvious placeholders in `spec.md`:
   - feature title
   - slug
   - `Created At`
   - `Updated At`
   - initial change log line
6. Replace obvious placeholders in `notes.md` and `review.md`:
   - `Created At`
   - `Updated At`
7. Delegate planning and spec authoring to `architect`.
8. Report concise completion status back to the human, including:
   - feature folder path
   - whether files were created or reused
   - that `spec.md` is ready for human review
   - that the next likely manual phase is `/lean-spec:implement-spec <slug>` once approved

Use these shell commands when appropriate:

```bash
NOW="$(date "+%Y-%m-%d %H:%M %Z")"
mkdir -p "lean-spec/features/$ARGUMENTS"
cp ".claude/lean-spec/templates/spec.md" "lean-spec/features/$ARGUMENTS/spec.md"
cp ".claude/lean-spec/templates/notes.md" "lean-spec/features/$ARGUMENTS/notes.md"
cp ".claude/lean-spec/templates/review.md" "lean-spec/features/$ARGUMENTS/review.md"
```
