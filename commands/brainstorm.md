---
description: Draft a project-level docs/PRD.md from a topic using the brainstormer subagent
argument-hint: "<topic-or-pitch> [@path/to/context-file ...]"
allowed-tools: Bash, Read, Task
---

# /lean-spec:brainstorm

Greenfield entry point (PRD §11 F10). Dispatches the **brainstormer subagent** to produce a draft `docs/PRD.md` from the user's topic, using the canonical shape in `templates/PRD.md`.

This is the first artifact on a fresh project. After you're happy with the PRD, run `/lean-spec:decompose-prd` to split it into per-feature skeletons, then `/lean-spec:start-spec <slug>` per feature to complete them via the architect subagent.

## Pre-flight

1. Check `$ARGUMENTS` is non-empty. If empty:
   ```
   Usage: /lean-spec:brainstorm <topic> [@path/to/context ...]
   Example: /lean-spec:brainstorm a minimalist habit tracker with streaks @docs/research.md
   ```
   Exit 1.

2. Check for existing `docs/PRD.md`:
   ```bash
   if [ -f "docs/PRD.md" ]; then
     echo "docs/PRD.md already exists. Either:"
     echo "  - edit it manually"
     echo "  - rerun /lean-spec:brainstorm with your revised topic after backing up the file"
     echo "  - delete it first if you want to regenerate from scratch"
     exit 1
   fi
   ```

3. Ensure `docs/` directory exists: `mkdir -p docs`.

## Steps

1. Locate the template. It lives at `${CLAUDE_PLUGIN_ROOT}/templates/PRD.md` inside the plugin.

2. Dispatch the **brainstormer subagent** using the `Task` tool:

   - `subagent_type`: `"lean-spec:brainstormer"` — plugin-provided, pinned to opus via frontmatter
   - `description`: `"Draft PRD for '$TOPIC'"` (first 40 chars of the topic)
   - `prompt`: build the invocation payload:

     ```
     Topic: <user's one-line topic>

     Brief:
     <full $ARGUMENTS after the topic — may reference files via @path>

     Template path: ${CLAUDE_PLUGIN_ROOT}/templates/PRD.md
     Output path: docs/PRD.md
     ```

3. When the brainstormer returns, confirm `docs/PRD.md` exists and tell the user:

   > "Draft PRD written to `docs/PRD.md`. Review it — flagged TODOs may need your input. When you're happy with the shape, run `/lean-spec:decompose-prd` to generate feature skeletons."

4. If the brainstormer returns `NEEDS_CONTEXT` or `BLOCKED`, relay the reason verbatim and do not attempt to write the PRD from the orchestrator session.

## Notes

- **Do not ghost-write `docs/PRD.md`** from this orchestrator session — the whole point is tier enforcement. If brainstormer fails, the correct recovery is re-dispatching with a clearer topic, not orchestrator fallback.
- **Brainstorm is single-shot.** For iteration, the user re-runs `/lean-spec:brainstorm` (after deleting or backing up the prior PRD) or edits the draft manually. Multi-turn iterative brainstorming inside a single subagent dispatch is not supported today.
- **The brainstormer is pinned to opus** (`agents/brainstormer.md` frontmatter). Do not override.
