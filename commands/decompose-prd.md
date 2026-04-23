---
description: Generate feature skeletons (features/<slug>/ with workflow.json + spec stub) from docs/PRD.md
argument-hint: "[<prd-path>]"
allowed-tools: Bash, Read
---

# /lean-spec:decompose-prd

Read a project-level PRD and emit one feature skeleton per item in its **Features** section. Each skeleton lands at `features/<slug>/` with:

- `workflow.json` in `specifying` phase
- `spec.md` with frontmatter, a populated `## Scope` (copied from the PRD's feature paragraph), and empty placeholders for Acceptance Criteria / Out of Scope / Technical Notes / Coder Guardrails

**The skeletons are NOT complete specs.** They seed the architect's work — for each skeleton the user then runs `/lean-spec:update-spec <slug>` (or `/lean-spec:start-spec <slug>` if re-priming from scratch) to dispatch the architect and fill the rest.

This command is deterministic bash — it does NOT dispatch any subagent.

## Pre-flight

```bash
PRD="${ARGUMENTS:-docs/PRD.md}"

if [ ! -f "$PRD" ]; then
  echo "PRD not found at '$PRD'. Run /lean-spec:brainstorm first, or pass an explicit path."
  exit 1
fi

# Source the parser from the plugin
source "${CLAUDE_PLUGIN_ROOT}/lib/prd-parser.sh"

# Resolve the project root (features/ lands here)
PROJ_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || PROJ_ROOT="."
```

## Steps

1. Extract feature slugs from the PRD:

```bash
SLUGS=$(list_feature_slugs "$PRD")
if [ -z "$SLUGS" ]; then
  echo "No Features section found in $PRD (expected '## <N>. Features' with '### <N>.<M> <title>' sub-sections)."
  echo "Either:"
  echo "  - Check the PRD structure matches templates/PRD.md"
  echo "  - Add a Features section and re-run"
  exit 1
fi
```

2. For each slug, create `features/<slug>/` if it doesn't already exist, with a workflow.json (phase=specifying) and a spec.md skeleton:

```bash
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CREATED=0
SKIPPED=0

while IFS= read -r SLUG; do
  [ -z "$SLUG" ] && continue
  DIR="$PROJ_ROOT/features/$SLUG"

  if [ -d "$DIR" ]; then
    echo "skip $SLUG — features/$SLUG/ already exists"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  mkdir -p "$DIR"

  TITLE=$(feature_section_title "$PRD" "$SLUG")
  SCOPE=$(feature_scope "$PRD" "$SLUG")

  # Write workflow.json
  cat > "$DIR/workflow.json" <<EOF
{
  "slug": "$SLUG",
  "phase": "specifying",
  "created_at": "$NOW",
  "updated_at": "$NOW",
  "history": [
    { "phase": "specifying", "entered_at": "$NOW" }
  ],
  "artifacts": {
    "spec": "spec.md",
    "notes": "notes.md",
    "review": "review.md"
  }
}
EOF

  # Write spec.md skeleton
  cat > "$DIR/spec.md" <<EOF
---
slug: $SLUG
phase: specifying
handoffs:
  next_command: /lean-spec:submit-implementation $SLUG
  blocks_on: []
  consumed_by: [coder, reviewer]
---

# $TITLE

> 🚧 **Skeleton** produced by \`/lean-spec:decompose-prd\`. Run
> \`/lean-spec:update-spec $SLUG\` to dispatch the architect and complete this
> spec before running \`/lean-spec:submit-implementation\`.

## Scope

$SCOPE

## Acceptance Criteria

<!-- Fill via /lean-spec:update-spec $SLUG — the architect will derive ACs from
     the PRD's feature section and produce a V1/V2 table if the feature has UI. -->

## Out of Scope

<!-- Fill via /lean-spec:update-spec $SLUG. Reference the project PRD's §Out of Scope
     when it carries over. -->

## Technical Notes

Source: \`$PRD\` §$TITLE.

## Coder Guardrails

<!-- Fill via /lean-spec:update-spec $SLUG if the stack has known footguns. -->
EOF

  echo "created features/$SLUG/ (phase=specifying)"
  CREATED=$((CREATED + 1))
done <<< "$SLUGS"

echo ""
echo "Done. $CREATED skeleton(s) created, $SKIPPED already existed."
echo ""
echo "Next:"
echo "  1. Review each features/<slug>/spec.md and trim Scope if needed."
echo "  2. Run /lean-spec:update-spec <slug> per feature to dispatch the architect."
echo "  3. /lean-spec:spec-status for the current lifecycle view."
```

## Notes

- **Slug generation** lowercases the heading, strips `4.N` numbering, and collapses non-alphanumeric characters to single hyphens. `4.1 Add Task Input` → `add-task-input`.
- **Skip if exists** — the command is idempotent. Re-running it after adding a new feature to the PRD creates only the new skeletons; existing ones are left alone (even if the PRD section changed — edit manually or delete and re-run).
- **This command writes `workflow.json` directly.** That's explicit scaffolding, not a phase mutation — `pre-tool-use-workflow.sh` blocks hand edits of workflow.json, but this command is the scaffolder of record, so users running it should know they're seeding the lifecycle state.
