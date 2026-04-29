---
description: Create a new feature and dispatch the architect subagent to write spec.md
argument-hint: <slug> [--auto] [--gates-on|--gates-off] [free-form brief or @path/to/PRD.md]
allowed-tools: Task, Read, SlashCommand
---

# /lean-spec:start-spec

The `UserPromptSubmit` hook has already validated the slug, created `features/<slug>/`, and written `workflow.json` (phase: `specifying`). Your job is to dispatch the **architect subagent** to write `spec.md`, then optionally chain into the auto-driver.

## Steps

1. Parse `$ARGUMENTS`:

   ```
   AUTO_MODE = 0
   GATES_ON  = 0
   SLUG      = ""
   BRIEF     = ""

   For each token in $ARGUMENTS:
     --auto       → AUTO_MODE=1
     --gates-on   → GATES_ON=1
     --gates-off  → GATES_ON=0
     --*          → ignore unknown flags
     else         → if SLUG is empty, this token is SLUG; otherwise append to BRIEF

   BRIEF = everything remaining after SLUG and flags are removed (may be empty)
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
     <BRIEF verbatim — everything after the slug in $ARGUMENTS, with flags removed>

     Existing spec:
     (none — this is a new feature)
     ```

   - If the brief is empty: use `Brief: (none provided — report DONE_WITH_CONCERNS and ask the user to re-invoke with a brief)`.
   - If the brief starts with `@` (file reference): include verbatim; the architect will read the file.

3. When the architect subagent returns, confirm `features/<slug>/spec.md` exists.

   - If architect returned `NEEDS_CONTEXT` or `BLOCKED`: relay the reason verbatim and stop.

   - If spec.md exists and `AUTO_MODE=0` (default manual mode):
     > "Architect drafted `features/<slug>/spec.md`. Review it. When satisfied, run `/lean-spec:submit-implementation <slug>`."

   - If spec.md exists and `AUTO_MODE=1` and `GATES_ON=1`:
     Tell the user: "Spec ready. Dispatching auto-driver with close gate — will pause before closing."
     Then dispatch via `SlashCommand`: `/lean-spec:auto <slug> --gates-on`

   - If spec.md exists and `AUTO_MODE=1` and `GATES_ON=0` (default for --auto):
     Tell the user: "Spec ready. Dispatching auto-driver in fully autonomous mode."
     Then dispatch via `SlashCommand`: `/lean-spec:auto <slug>`

## Notes

- Do NOT write `spec.md` yourself, even as a fallback. Tier enforcement is the point.
- Do NOT invoke the `writing-specs` skill in the orchestrator context — that skill belongs to the architect subagent.
- Do NOT run any bash commands — the hook has done all filesystem setup already.
- When `--auto` is set, the SlashCommand dispatch hands off control to the auto-driver; no further action needed after dispatching.
