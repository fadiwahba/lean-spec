---
description: Re-dispatch coder with spec + review feedback, then re-enter reviewing
argument-hint: <slug>
allowed-tools: Bash, Read, Task
---

# /lean-spec:submit-fixes

When review verdict is `NEEDS_FIXES`, re-dispatch the coder with `spec.md + review.md`, then advance back to `reviewing`.

## Pre-flight

1. Check `$ARGUMENTS` provided.
2. Verify `features/$ARGUMENTS/workflow.json` exists.
3. Read `features/$ARGUMENTS/workflow.json` and verify current phase is `reviewing`. If not, say: "Phase gate: expected 'reviewing', got '<phase>'."
4. Read `features/$ARGUMENTS/review.md`. Verify it contains `NEEDS_FIXES`. If verdict is `APPROVE`, say: "Verdict is APPROVE — run /lean-spec:close-spec $ARGUMENTS instead." If `BLOCKED`, say: "Verdict is BLOCKED — human intervention required before fixes can proceed."

## Steps

1. Advance phase back to `implementing`:
```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "implementing" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp" && mv "$tmp" "$WF"
```

2. Dispatch the **coder subagent** using the `Task` tool:

   - `subagent_type`: `"lean-spec:coder"`
   - `description`: `"Apply review fixes for <slug>"`
   - `prompt`: build a fresh invocation payload like this (the coder's system prompt comes from `agents/coder.md`; do not include it yourself):

     ```
     Slug: <slug>
     Spec path: features/<slug>/spec.md
     Notes path: features/<slug>/notes.md
     Review path: features/<slug>/review.md
     Mode: fixes

     (The coder should read spec.md and review.md with its own Read tool, address every finding in review.md, then overwrite notes.md to enumerate what was fixed per reviewer item.)
     ```

3. After coder completes, advance phase to `reviewing`:
```bash
SLUG="$ARGUMENTS"
WF="features/$SLUG/workflow.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "reviewing" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp" && mv "$tmp" "$WF"
```

4. Tell the user: "Fix cycle complete. Run /lean-spec:submit-review $ARGUMENTS to re-review."
