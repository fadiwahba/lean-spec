---
description: Initialise lean-spec in this project — creates .lean-spec/rules.yaml and docs/ if absent
---

Arguments: `$ARGUMENTS` (none expected — init takes no arguments).

## Step 1 — Bootstrap

```bash
RULES_DIR=".lean-spec"
RULES_FILE="$RULES_DIR/rules.yaml"
DOCS_DIR="docs"

[ ! -f "$RULES_FILE" ] && mkdir -p "$RULES_DIR" && echo "Created $RULES_FILE" || echo "Skipped $RULES_FILE (exists)"
[ ! -d "$DOCS_DIR" ] && mkdir -p "$DOCS_DIR" && echo "Created $DOCS_DIR/" || echo "Skipped $DOCS_DIR/ (exists)"

echo ""
echo "Note: rules.yaml must be seeded manually in OpenCode (copy examples/rules.yaml)."
echo "Next: /lean-spec:brainstorm <topic>"
```

## Step 2 — Hand off

Tell the user what was created. Remind them to copy `examples/rules.yaml` into `.lean-spec/rules.yaml` and tune quality gates before running brainstorm.
