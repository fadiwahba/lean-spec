---
description: Create a new feature and dispatch the architect subagent to write spec.md
argument-hint: <slug> [free-form brief or @path/to/PRD.md]
allowed-tools: Bash, Read, Task
---

# /lean-spec:start-spec

Initialize a new feature. Creates `features/<slug>/` with `workflow.json` in the `specifying` phase, then dispatches the **architect subagent** (plugin-provided, pinned to a strong model via its frontmatter) to author `spec.md` from the user's brief.

The orchestrator (you) does NOT write `spec.md` directly. Tier enforcement is the whole point — see PRD §4.2.

## Pre-flight

Parse arguments. First token = slug; rest = brief (optional):
```bash
ARGS="$ARGUMENTS"
SLUG="${ARGS%% *}"
BRIEF="${ARGS#"$SLUG"}"
BRIEF="${BRIEF# }"

if [[ -z "$SLUG" ]]; then
  echo "Usage: /lean-spec:start-spec <slug> [brief or @path/to/PRD.md]"
  exit 1
fi
if ! [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Invalid slug '$SLUG': use lowercase letters, digits, and hyphens only (e.g. 'add-user-export')"
  exit 1
fi
if [ -d "features/$SLUG" ]; then
  echo "Feature '$SLUG' already exists. Use /lean-spec:update-spec $SLUG to revise."
  exit 1
fi
```

## Steps

1. Create `features/$SLUG/` directory and initialize `workflow.json`:
```bash
SLUG="${ARGUMENTS%% *}"
mkdir -p "features/$SLUG"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "features/$SLUG/workflow.json" <<EOF
{
  "slug": "$SLUG",
  "phase": "specifying",
  "created_at": "$NOW",
  "updated_at": "$NOW",
  "history": [
    { "phase": "specifying", "entered_at": "$NOW" }
  ],
  "artifacts": {
    "spec": "spec.md",
    "notes": "notes.md",
    "review": "review.md"
  }
}
EOF
```

2. Dispatch the **architect subagent** using the `Task` tool:

   - `subagent_type`: `"lean-spec:architect"` — the plugin-provided architect (see `agents/architect.md`). The subagent's frontmatter pins `model: opus`; do not override.
   - `description`: `"Author spec.md for <slug>"`
   - `prompt`: build a fresh invocation payload like this (do NOT send the `agents/architect.md` body yourself — Claude Code loads it automatically as the subagent's system prompt):

     ```
     Slug: <slug>
     Spec path: features/<slug>/spec.md
     Mode: new

     Brief:
     <user's full brief, verbatim — everything after the slug in $ARGUMENTS>

     Existing spec:
     (none — this is a new feature)
     ```

   If the brief references a file (e.g. `@docs/PRD.md`), include that reference verbatim in the `Brief:` section; the architect will read it with its own tools.
   If the brief is empty, send `Brief: (none provided — report DONE_WITH_CONCERNS and ask the user to re-invoke with a brief)`.

3. When the architect subagent returns, confirm `features/$SLUG/spec.md` exists. If it does, tell the user:

   > "Architect drafted `features/$SLUG/spec.md`. Review it. If you want revisions, run `/lean-spec:update-spec $SLUG`. When you're satisfied, run `/lean-spec:submit-implementation $SLUG`."

4. If the architect returned `NEEDS_CONTEXT` or `BLOCKED`, relay the reason verbatim and do not advance.

## Notes

- **The architect is a plugin-provided subagent** with its system prompt in `agents/architect.md` and its model pinned in frontmatter. Your only job is to construct the per-invocation prompt (slug, spec path, mode, brief).
- **Do not invoke the `writing-specs` skill in the orchestrator context.** That skill is the architect subagent's tool.
- **Do not write `spec.md` directly**, even as a fallback. If the architect fails, the right recovery is `/lean-spec:update-spec` (which re-dispatches), not the orchestrator ghost-writing.
