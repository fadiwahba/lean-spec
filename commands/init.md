---
description: Initialise lean-spec in this project — creates .lean-spec/rules.yaml and docs/ if absent
argument-hint: (no arguments)
allowed-tools: Bash
---

# /lean-spec:init

Bootstrap lean-spec in the current project. Safe to re-run — existing files are never overwritten.

## Steps

1. Run the following:

```bash
set -euo pipefail
RULES_DIR=".lean-spec"
RULES_FILE="$RULES_DIR/rules.yaml"
RULES_SRC="${CLAUDE_PLUGIN_ROOT}/examples/rules.yaml"
DOCS_DIR="docs"

CREATED=""

if [ ! -f "$RULES_FILE" ]; then
  mkdir -p "$RULES_DIR"
  cp "$RULES_SRC" "$RULES_FILE"
  CREATED="$CREATED\n  Created $RULES_FILE (from default template)"
else
  CREATED="$CREATED\n  Skipped $RULES_FILE (already exists)"
fi

if [ ! -d "$DOCS_DIR" ]; then
  mkdir -p "$DOCS_DIR"
  CREATED="$CREATED\n  Created $DOCS_DIR/"
else
  CREATED="$CREATED\n  Skipped $DOCS_DIR/ (already exists)"
fi

printf "lean-spec init complete:%b\n" "$CREATED"
echo ""
echo "Next:"
echo "  1. Edit .lean-spec/rules.yaml to tune quality gates and model overrides."
echo "  2. Run /lean-spec:brainstorm <topic> to draft docs/PRD.md."
```

2. Report what was created/skipped to the user verbatim from the script output.
