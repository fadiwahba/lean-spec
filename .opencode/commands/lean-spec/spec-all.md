---
description: Write spec.md for every feature currently in specifying phase
---

Arguments: `$ARGUMENTS` (no arguments required)

```bash
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
FEATURES_DIR="$PROJ/features"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "No features/ directory found. Run /lean-spec:decompose-prd first."
  exit 1
fi

SLUGS=$(find "$FEATURES_DIR" -name workflow.json 2>/dev/null \
  | xargs -I{} sh -c 'jq -r "select(.phase==\"specifying\") | .slug" "{}" 2>/dev/null' \
  | sort)

if [ -z "$SLUGS" ]; then
  echo "No features in specifying phase."
  exit 0
fi

echo "Features in specifying phase:"
echo "$SLUGS"
echo ""

# Check for model override in rules.yaml
MODEL_OVERRIDE=""
if [ -f ".lean-spec/rules.yaml" ]; then
  MODEL_OVERRIDE=$(grep -E "^\s+architect:" .lean-spec/rules.yaml | awk '{print $2}' | tr -d '"' 2>/dev/null || true)
fi
[ -n "$MODEL_OVERRIDE" ] && echo "Model override (rules.yaml): $MODEL_OVERRIDE"
```

For each slug listed above, act as the architect and write a complete `features/<slug>/spec.md` from the matching section in `docs/PRD.md`. Follow the structure in `skills/writing-specs/SKILL.md`. Cap each spec at ~80 lines.

If a model override was found in `.lean-spec/rules.yaml`, note it but use whichever model is active (OpenCode degraded mode — no subagent dispatch).

After writing all specs, report: "spec-all complete — N features specced: <slug-list>."
