---
description: Dispatch the architect subagent to revise spec.md (stays in specifying phase)
argument-hint: <slug>
allowed-tools: Bash, Read, Task
---

# /lean-spec:update-spec

Dispatch the **architect subagent** to revise an in-progress spec. Phase stays `specifying`.

The orchestrator (you) does NOT edit `spec.md` directly. Enforced strong-model tier is the whole point — see PRD §4.2.

## Pre-flight

1. Check `$ARGUMENTS` provided. Usage: `/lean-spec:update-spec <slug>`.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Read `features/$ARGUMENTS/workflow.json` and verify current phase is `specifying`. If not, say: "Feature is in phase '<phase>' — spec is locked. Revisions after `specifying` require `/lean-spec:submit-fixes <slug>` (only valid from `reviewing` + NEEDS_FIXES)."

## Steps

1. Read the existing `features/$ARGUMENTS/spec.md` so you can pass it to the subagent.

2. Ask the user: "What changes should I make to the spec for `$ARGUMENTS`?" and capture the full feedback verbatim. The orchestrator's job here is to collect — not to interpret — feedback.

3. Dispatch the **architect subagent** using the `Task` tool:
   - `subagent_type`: `architect`
   - `description`: `Revise spec.md for <slug>`
   - `prompt`: use `agents/architect-prompt.md` as the template. Fill in:
     - `{{SLUG}}` → the slug
     - `{{SPEC_PATH}}` → `features/<slug>/spec.md`
     - `{{MODE}}` → `update`
     - `{{BRIEF}}` → the user's verbatim revision feedback
     - `{{EXISTING_SPEC}}` → the full contents of the current `spec.md`

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

- **Phase stays `specifying`**, so the `PreToolUse` hook that blocks hand-edits of `workflow.json` is still armed — only `updated_at` is bumped via the atomic jq block above.
- **Do not invoke the `writing-specs` skill in the orchestrator context.**
- **Do not edit `spec.md` directly** even for "tiny" changes. The whole point of the dispatched-architect model is runtime enforcement of the strong-model tier for every spec change.
