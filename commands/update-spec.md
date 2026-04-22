---
description: Revise spec.md in place (stays in specifying phase)
argument-hint: <slug>
allowed-tools: Bash, Read, Write, Edit
---

# /lean-spec:update-spec

Revise the spec for an existing feature. Phase stays `specifying`.

## Pre-flight

1. Check `$ARGUMENTS` provided. Usage: `/lean-spec:update-spec <slug>`.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Read `features/$ARGUMENTS/workflow.json` and check current phase is `specifying`. If not, say: "Feature is in phase '<phase>' — only revise spec while in 'specifying'."

## Steps

1. Read `features/$ARGUMENTS/spec.md` and show it to the user.
2. Ask: "What changes should I make to the spec?"
3. Apply the requested changes to `features/$ARGUMENTS/spec.md`.
4. Update `updated_at` in `features/$ARGUMENTS/workflow.json`:
```bash
SLUG="$ARGUMENTS"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
jq --arg now "$NOW" '.updated_at = $now' "features/$SLUG/workflow.json" > "features/$SLUG/workflow.json.tmp" && mv "features/$SLUG/workflow.json.tmp" "features/$SLUG/workflow.json"
```
5. Confirm: "Spec updated. Run `/lean-spec:submit-implementation $ARGUMENTS` when ready."
