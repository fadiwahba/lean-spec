# lean-spec — decompose-prd (Codex)

Emit one `features/<slug>/` skeleton per feature section in `docs/PRD.md`.

## Inputs

- **PRD path** (optional): defaults to `docs/PRD.md`

## Steps

```bash
PRD="<paste PRD path or leave 'docs/PRD.md'>"
[ -f "$PRD" ] || { echo "PRD not found at '$PRD'. Paste brainstorm first."; exit 1; }

slugify() {
  local s="$1"
  s=$(echo "$s" | sed -E 's/^[0-9]+(\.[0-9]+)*[[:space:]]+//; s/^[0-9]+\)[[:space:]]+//')
  s=$(echo "$s" | tr '[:upper:]' '[:lower:]')
  s=$(echo "$s" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  echo "$s"
}

HEADINGS=$(awk '
  BEGIN { in_features = 0 }
  /^## / {
    if (in_features) exit
    if ($0 ~ /^##[[:space:]]+([0-9]+\.[[:space:]]+)?Features[[:space:]]*$/) in_features = 1
    else in_features = 0
    next
  }
  in_features && /^### / { sub(/^### /, ""); print }
' "$PRD")

[ -z "$HEADINGS" ] && { echo "No Features section found in $PRD"; exit 1; }

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CREATED=0; SKIPPED=0

while IFS= read -r HEADING; do
  [ -z "$HEADING" ] && continue
  SLUG=$(slugify "$HEADING")
  DIR="features/$SLUG"
  if [ -d "$DIR" ]; then
    echo "skip $SLUG — exists"; SKIPPED=$((SKIPPED + 1)); continue
  fi
  mkdir -p "$DIR"
  cat > "$DIR/workflow.json" <<EOF
{
  "slug": "$SLUG",
  "phase": "specifying",
  "created_at": "$NOW",
  "updated_at": "$NOW",
  "history": [{"phase": "specifying", "entered_at": "$NOW"}],
  "artifacts": {"spec": "spec.md", "notes": "notes.md", "review": "review.md"}
}
EOF
  cat > "$DIR/spec.md" <<EOF
---
slug: $SLUG
phase: specifying
handoffs:
  next_command: /lean-spec:submit-implementation $SLUG
  blocks_on: []   # list sibling slugs this feature depends on
  consumed_by: [coder, reviewer]
---

# $HEADING

> 🚧 Skeleton from decompose-prd. Paste update-spec with slug=$SLUG to complete.

## Scope
(see PRD §$HEADING)

## Acceptance Criteria
## Out of Scope
## Technical Notes
## Coder Guardrails
EOF
  echo "created features/$SLUG/"
  CREATED=$((CREATED + 1))
done <<< "$HEADINGS"

echo ""
echo "Done. $CREATED skeleton(s) created, $SKIPPED already existed."
echo "Note: Claude Code native version also auto-generates .lean-spec/rules.yaml and warns about"
echo "cross-feature dependencies. This degraded port omits both — check blocks_on manually."
echo "Next: paste 'update-spec' per feature to complete the specs."
```
