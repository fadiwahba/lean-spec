---
description: Dispatch the architect subagent to revise spec.md (stays in specifying phase)
argument-hint: <slug> [inline-brief]
allowed-tools: Bash, Read, Task
---

# /lean-spec:update-spec

Dispatch the **architect subagent** (plugin-provided, pinned to a strong model) to revise an in-progress spec. Phase stays `specifying`.

The orchestrator (you) does NOT edit `spec.md` directly. Tier enforcement is the whole point — see PRD §4.2.

## Pre-flight

1. Parse arguments — first token is the slug; everything after is the optional inline brief:
```bash
ARGS="$ARGUMENTS"
SLUG="${ARGS%% *}"
BRIEF="${ARGS#"$SLUG"}"
BRIEF="${BRIEF# }"
```
   If `$SLUG` is empty, say: "Usage: /lean-spec:update-spec <slug> [inline-brief]" and stop.

2. Verify `features/$SLUG/workflow.json` exists.
3. Read `features/$SLUG/workflow.json` and verify current phase is `specifying`. If not, say: "Feature is in phase '<phase>' — spec is locked. Revisions after `specifying` require `/lean-spec:submit-fixes <slug>` (only valid from `reviewing` + NEEDS_FIXES)."

## Steps

1. Read the existing `features/$SLUG/spec.md` so you can include it in the dispatch payload.

2. Collect the revision brief:
   - If `$BRIEF` (parsed in pre-flight) is **non-empty**: use it verbatim — **do NOT prompt the user**. This path is used by headless/agentic callers (e.g. `/lean-spec:auto`, driver scripts) that pre-supply the brief inline.
   - If `$BRIEF` is **empty**: ask the user: "What changes should I make to the spec for `$SLUG`?" and capture the full feedback verbatim. The orchestrator's job here is to *collect* feedback — not to interpret or summarize it.

3. Read the model override for the architect (if any):
   - Check if `.lean-spec/rules.yaml` exists. If it does, read it and look for a `models:` key with an `architect:` sub-key.
   - If found, note the value (e.g. `sonnet`). You will pass it as the `model` parameter in the Task tool call below.
   - If not found or the file doesn't exist, omit `model` — the agent's frontmatter default (`opus`) applies.

4. Dispatch the **architect subagent** using the `Task` tool:

   - `subagent_type`: `"lean-spec:architect"`
   - `model`: the value from step 3 if present (omit entirely if not set). Its frontmatter default is `model: opus`. Override via `.lean-spec/rules.yaml` models block if present.
   - `description`: `"Revise spec.md for <slug>"`
   - `prompt`: build a fresh invocation payload like this (the architect's system prompt comes from `agents/architect.md`; do not include it yourself):

     ```
     Slug: <slug>
     Spec path: features/<slug>/spec.md
     Mode: update

     Brief (revision feedback):
     <brief from step 2 — verbatim>

     Existing spec:
     <full contents of features/<slug>/spec.md, copied verbatim including frontmatter>
     ```

5. When the architect subagent returns, update `updated_at` in `workflow.json`. **If this block exits non-zero, the architect's spec.md was written successfully but the workflow.json timestamp didn't update — report the error to the user but note the spec changes are still on disk.**
```bash
set -e
SLUG="${ARGUMENTS%% *}"
WF="features/$SLUG/workflow.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg now "$NOW" '.updated_at = $now' "$WF" > "$tmp"
mv -f "$tmp" "$WF" || { echo "ERROR: mv failed — workflow.json not updated. Orphan tmp: $tmp" >&2; exit 1; }
# Verify file is still valid JSON with phase=specifying
jq -e '.phase == "specifying"' "$WF" > /dev/null || { echo "ERROR: workflow.json corrupted or phase changed unexpectedly." >&2; exit 1; }
echo "workflow.json updated_at refreshed"
```

6. Confirm to the user:

   > "Spec revised. Review `features/$SLUG/spec.md`. Run `/lean-spec:update-spec $SLUG` again for more changes, or `/lean-spec:submit-implementation $SLUG` when ready."

## Notes

- **Phase stays `specifying`** — only `updated_at` is bumped. The `PreToolUse` hook that blocks hand-edits of `workflow.json` is still armed; the atomic jq block above is the approved mechanism.
- **Do not invoke the `writing-specs` skill in the orchestrator context.** That's the architect's tool.
- **Do not edit `spec.md` directly** even for "tiny" changes. Every spec mutation must go through a dispatched architect so the strong-model tier is enforced at runtime.
