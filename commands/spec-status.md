---
description: Print current phase, last activity, and the next command for one or all features
argument-hint: "[<slug>]"
allowed-tools: Bash, Read
---

# /lean-spec:spec-status

Print the current lifecycle status for one or all features, **and explicitly state the next command** the user should run.

## Steps

If `$ARGUMENTS` is provided (specific slug):
1. Read `features/$ARGUMENTS/workflow.json`.
2. Print:
   - Slug, Phase, Updated at
   - History (phase → entered_at for each entry)
3. Print the canonical next command (see "Next command per phase" below).

If `$ARGUMENTS` is empty (all features):
1. Find all `features/*/workflow.json` files:
```bash
PROJ_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || PROJ_ROOT="."
find "$PROJ_ROOT/features" -name "workflow.json" 2>/dev/null | sort
```
2. For each, print a one-line summary: `<slug>  [<phase>]  last updated: <updated_at>  → next: <command>`
3. If no features found, say: "No features found. Run `/lean-spec:start-spec <slug>` to begin."

## Next command per phase

This is the authoritative mapping. Use it verbatim — do not freelance suggestions.

| Current phase | Next command | When |
|---|---|---|
| `specifying` | `/lean-spec:submit-implementation <slug>` | Always the canonical forward step |
| `specifying` | `/lean-spec:update-spec <slug>` | **Alternative** — only mention this as a "or revise first via..." aside |
| `implementing` | `/lean-spec:submit-review <slug>` | After the coder produced `notes.md` |
| `reviewing` | `/lean-spec:close-spec <slug>` | When `review.md` verdict is `APPROVE` |
| `reviewing` | `/lean-spec:submit-fixes <slug>` | When `review.md` verdict is `NEEDS_FIXES` |
| `reviewing` | (human action required) | When `review.md` verdict is `BLOCKED` |
| `closed` | (none — feature complete) | — |

For `reviewing` phase: read `features/<slug>/review.md` and grep for the verdict line to pick between close-spec and submit-fixes. If `review.md` doesn't exist yet, say "Reviewer subagent has not produced review.md — re-dispatch via /lean-spec:submit-review <slug>".

`/lean-spec:resume-spec <slug>` is **not** a forward step — only suggest it if the user explicitly asks how to re-prime context after a session break.

## Output format

```
<slug> — [<phase>] — last updated: <iso8601>

History:
- specifying   → entered <iso8601>
- implementing → entered <iso8601>
...

Next: /lean-spec:<command> <slug>
```

The `Next:` line is mandatory. It is the most useful thing in the output.
