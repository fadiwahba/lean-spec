---
description: Advance to implementing phase and dispatch the coder subagent
argument-hint: <slug> [--no-rules]
allowed-tools: Bash, Read, Task
---

# /lean-spec:submit-implementation

Advance a feature from `specifying` to `implementing` and dispatch the coder subagent.

Pass `--no-rules` to skip `rules.yaml` validation for this invocation (e.g. when iterating on a draft spec).

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Read `features/$ARGUMENTS/workflow.json` and verify current phase is `specifying`. If not, say: "Phase gate: expected 'specifying', got '<phase>'. Run /lean-spec:resume-spec $ARGUMENTS if you need to re-enter the current phase."

## Steps

1. Advance phase to `implementing`. **If this block exits non-zero, STOP — do not dispatch the subagent. Report the error verbatim to the user.**
```bash
set -e
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
  "$WF" > "$tmp"
mv -f "$tmp" "$WF" || { echo "ERROR: mv failed — workflow.json not updated. Orphan tmp: $tmp" >&2; exit 1; }
# Post-advance assertion — catch silent failures
NEW_PHASE=$(jq -r '.phase // ""' "$WF" 2>/dev/null)
if [ "$NEW_PHASE" != "implementing" ]; then
  echo "ERROR: phase did not advance — expected 'implementing', still '$NEW_PHASE'. Aborting before subagent dispatch." >&2
  exit 1
fi
echo "phase advanced: specifying → implementing"
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
