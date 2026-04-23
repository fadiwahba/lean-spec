---
description: Advance to implementing phase and dispatch the coder subagent
argument-hint: <slug>
allowed-tools: Bash, Read, Task
---

# /lean-spec:submit-implementation

Advance a feature from `specifying` to `implementing` and dispatch the coder subagent.

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Read `features/$ARGUMENTS/workflow.json` and verify current phase is `specifying`. If not, say: "Phase gate: expected 'specifying', got '<phase>'. Run /lean-spec:resume-spec $ARGUMENTS if you need to re-enter the current phase."

## Steps

1. Advance phase to `implementing`:
```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"
CURRENT=$(jq -r '.phase // ""' "$WF" 2>/dev/null)
if [ "$CURRENT" != "specifying" ]; then
  echo "Phase gate: expected 'specifying', got '$CURRENT'" >&2; exit 1
fi
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "implementing" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp" && mv "$tmp" "$WF"
```

2. Dispatch the **coder subagent** using the `Task` tool:

   - `subagent_type`: `"lean-spec:coder"` — the plugin-provided coder (see `agents/coder.md`). Its frontmatter pins `model: haiku`; do not override.
   - `description`: `"Implement <slug>"`
   - `prompt`: build a fresh invocation payload like this (the coder's system prompt comes from `agents/coder.md`; do not include it yourself):

     ```
     Slug: <slug>
     Spec path: features/<slug>/spec.md
     Notes path: features/<slug>/notes.md
     Mode: initial

     (The coder should read spec.md with its own Read tool. No review.md exists in initial mode.)
     ```

3. Tell the user: "Dispatching coder subagent for '$ARGUMENTS'. Expected output: features/$ARGUMENTS/notes.md. Once notes.md is produced, run /lean-spec:submit-review $ARGUMENTS."
