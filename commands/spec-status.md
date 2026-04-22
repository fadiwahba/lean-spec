---
description: Print current phase and last activity for one or all features
argument-hint: "[<slug>]"
allowed-tools: Bash, Read
---

# /lean-spec:spec-status

Print the current lifecycle status for one or all features.

## Steps

If `$ARGUMENTS` is provided (specific slug):
1. Read `features/$ARGUMENTS/workflow.json`.
2. Print:
   - Slug, Phase, Updated at
   - History (phase → entered_at for each entry)

If `$ARGUMENTS` is empty (all features):
1. Find all `features/*/workflow.json` files:
```bash
PROJ_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || PROJ_ROOT="."
find "$PROJ_ROOT/features" -name "workflow.json" 2>/dev/null | sort
```
2. For each, print a one-line summary: `<slug>  [<phase>]  last updated: <updated_at>`
3. If no features found, say: "No features found. Run /lean-spec:start-spec <slug> to begin."
