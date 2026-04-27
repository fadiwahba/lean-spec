---
description: Create a new feature and dispatch the architect subagent to write spec.md
argument-hint: <slug> [free-form brief or @path/to/PRD.md]
allowed-tools: Task, Read
---

# /lean-spec:start-spec

The `UserPromptSubmit` hook has already validated the slug, created `features/<slug>/`, and written `workflow.json` (phase: `specifying`). Your only job is to dispatch the **architect subagent** to write `spec.md`.

## Steps

1. Parse `$ARGUMENTS` — first token is the slug, everything after is the brief:

   ```
   SLUG = first word of $ARGUMENTS
   BRIEF = remainder of $ARGUMENTS after the slug (may be empty)
   ```

2. Dispatch the **architect subagent** using the `Task` tool:

   - `subagent_type`: `"lean-spec:architect"` — model tier is pinned in its frontmatter; do not override.
   - `description`: `"Author spec.md for <slug>"`
   - `prompt`: build this payload (Claude Code loads the architect system prompt automatically; send only per-invocation context):

     ```
     Slug: <slug>
     Spec path: features/<slug>/spec.md
     Mode: new

     Brief:
     <BRIEF verbatim — everything after the slug in $ARGUMENTS>

     Existing spec:
     (none — this is a new feature)
     ```

   - If the brief is empty: use `Brief: (none provided — report DONE_WITH_CONCERNS and ask the user to re-invoke with a brief)`.
   - If the brief starts with `@` (file reference): include verbatim; the architect will read the file.

3. When the architect subagent returns, confirm `features/<slug>/spec.md` exists. If it does, tell the user:

   > "Architect drafted `features/<slug>/spec.md`. Review it. When satisfied, run `/lean-spec:submit-implementation <slug>`."

4. If the architect returned `NEEDS_CONTEXT` or `BLOCKED`, relay the reason verbatim and stop.

## Notes

- Do NOT write `spec.md` yourself, even as a fallback. Tier enforcement is the point.
- Do NOT invoke the `writing-specs` skill in the orchestrator context — that skill belongs to the architect subagent.
- Do NOT run any bash commands — the hook has done all filesystem setup already.
