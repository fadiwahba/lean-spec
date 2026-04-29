# lean-spec — init (Codex)

Initialise lean-spec in this project — creates `.lean-spec/rules.yaml` and `docs/` if absent.

## Steps

### 1. Bootstrap

```bash
RULES_DIR=".lean-spec"
RULES_FILE="$RULES_DIR/rules.yaml"
DOCS_DIR="docs"

if [ ! -f "$RULES_FILE" ]; then
  mkdir -p "$RULES_DIR"
  echo "Created $RULES_FILE — copy examples/rules.yaml from the lean-spec repo and edit to tune quality gates."
else
  echo "Skipped $RULES_FILE (already exists)"
fi

if [ ! -d "$DOCS_DIR" ]; then
  mkdir -p "$DOCS_DIR"
  echo "Created $DOCS_DIR/"
else
  echo "Skipped $DOCS_DIR/ (already exists)"
fi
```

### 2. Hand off

Tell the user what was created or skipped. Remind them to copy `examples/rules.yaml` from the lean-spec repo into `.lean-spec/rules.yaml` and tune quality gates before running `brainstorm`.
