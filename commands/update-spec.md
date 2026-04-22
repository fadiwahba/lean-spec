---
description: Dispatch the architect subagent to revise spec.md (stays in specifying phase)
argument-hint: <slug>
allowed-tools: Bash, Read, Task
---

# /lean-spec:update-spec

Dispatch the **architect subagent** (plugin-provided, pinned to a strong model) to revise an in-progress spec. Phase stays `specifying`.

The orchestrator (you) does NOT edit `spec.md` directly. Tier enforcement is the whole point — see PRD §4.2.

## Pre-flight

1. Check `$ARGUMENTS` provided. Usage: `/lean-spec:update-spec <slug>`.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Read `features/$ARGUMENTS/workflow.json` and verify current phase is `specifying`. If not, say: "Feature is in phase '<phase>' — spec is locked. Revisions after `specifying` require `/lean-spec:submit-fixes <slug>` (only valid from `reviewing` + NEEDS_FIXES)."

## Steps

1. Read the existing `features/$ARGUMENTS/spec.md` so you can include it in the dispatch payload.

2. Ask the user: "What changes should I make to the spec for `$ARGUMENTS`?" and capture the full feedback verbatim. The orchestrator's job here is to *collect* feedback — not to interpret or summarize it.

3. Dispatch the **architect subagent** using the `Task` tool:

   - `subagent_type`: `"lean-spec:architect"`
   - `description`: `"Revise spec.md for <slug>"`
   - `prompt`: build a fresh invocation payload like this (the architect's system prompt comes from `agents/architect.md`; do not include it yourself):

     ```
     Slug: <slug>
     Spec path: features/<slug>/spec.md
     Mode: update

     Brief (user's verbatim revision feedback):
     <feedback captured in step 2>

     Existing spec:
     <full contents of features/<slug>/spec.md, copied verbatim including frontmatter>
     ```

4. When the architect subagent returns, update `updated_at` in `workflow.json`:
```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg now "$NOW" '.updated_at = $now' "$WF" > "$tmp" && mv "$tmp" "$WF"
```

5. Confirm to the user:

   > "Spec revised. Review `features/$ARGUMENTS/spec.md`. Run `/lean-spec:update-spec $ARGUMENTS` again for more changes, or `/lean-spec:submit-implementation $ARGUMENTS` when ready."

## Notes

- **Phase stays `specifying`** — only `updated_at` is bumped. The `PreToolUse` hook that blocks hand-edits of `workflow.json` is still armed; the atomic jq block above is the approved mechanism.
- **Do not invoke the `writing-specs` skill in the orchestrator context.** That's the architect's tool.
- **Do not edit `spec.md` directly** even for "tiny" changes. Every spec mutation must go through a dispatched architect so the strong-model tier is enforced at runtime.
