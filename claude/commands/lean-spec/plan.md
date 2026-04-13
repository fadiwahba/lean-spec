---
name: plan
description: Create or locate a lean-spec feature folder and run the planning phase with the Architect agent.
---

Run the manual lean-spec planning phase for the feature slug in `$ARGUMENTS`.

Rules:
- Require a kebab-case slug. If no slug is provided, ask for one.
- The default session agent is the orchestrator. It owns scaffolding, routing, and concise status reporting.
- The Architect agent owns `spec.md`.
- The orchestrator must not write the substantive implementation plan into `spec.md`.
- If `lean-spec/features/<slug>/` does not exist, create it and scaffold:
  - `spec.md`
  - `notes.md`
  - `review.md`
- Use `lean-spec/templates/` as the source for scaffolded files.
- If the feature folder already exists, do not overwrite files. Reuse the existing folder.
- Read only the minimum relevant repository context needed to help the Architect plan accurately.
- Stop after the Architect has written or updated `spec.md`.
- Do not continue to implementation automatically. The human must explicitly run `/plan`, `/implement`, `/review`, `/status`, `/resume`, or `/end` next as needed.

Steps:
1. Normalize the slug from `$ARGUMENTS`.
2. Create `lean-spec/features/<slug>/` if needed.
3. Copy the template files if they do not already exist.
4. Replace obvious placeholders in `spec.md`:
   - feature title
   - slug
   - initial change log line
5. Delegate planning and spec authoring to `architect`.
6. Report concise completion status back to the human, including:
   - feature folder path
   - whether files were created or reused
   - that `spec.md` is ready for human review
   - that the next likely manual phase is `/implement <slug>` once approved

Use these shell commands when appropriate:

```bash
mkdir -p "lean-spec/features/$ARGUMENTS"
cp "lean-spec/templates/spec.md" "lean-spec/features/$ARGUMENTS/spec.md"
cp "lean-spec/templates/notes.md" "lean-spec/features/$ARGUMENTS/notes.md"
cp "lean-spec/templates/review.md" "lean-spec/features/$ARGUMENTS/review.md"
```
