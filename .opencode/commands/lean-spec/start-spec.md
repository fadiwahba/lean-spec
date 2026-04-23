---
description: Create a new feature and dispatch the architect to write spec.md
agent: architect
subtask: true
---

Create a new lean-spec v3 feature.

Arguments: `$ARGUMENTS` — first token is the kebab-case slug; remaining text is the brief (may include `@path/to/PRD.md`).

## Step 1 — Pre-flight and workflow.json creation

Run this bash:

```bash
ARGS="$ARGUMENTS"
SLUG="${ARGS%% *}"
BRIEF="${ARGS#$SLUG}"; BRIEF="${BRIEF# }"

if [[ -z "$SLUG" ]]; then
  echo "Usage: /lean-spec:start-spec <slug> [brief or @path/to/PRD.md]"; exit 1
fi
if ! [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Invalid slug '$SLUG': lowercase/digits/hyphens only"; exit 1
fi
if [ -d "features/$SLUG" ]; then
  echo "Feature '$SLUG' already exists. Use /lean-spec:update-spec $SLUG."; exit 1
fi

mkdir -p "features/$SLUG"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "features/$SLUG/workflow.json" <<EOF
{
  "slug": "$SLUG",
  "phase": "specifying",
  "created_at": "$NOW",
  "updated_at": "$NOW",
  "history": [{ "phase": "specifying", "entered_at": "$NOW" }],
  "artifacts": { "spec": "spec.md", "notes": "notes.md", "review": "review.md" }
}
EOF
echo "Created features/$SLUG/ (phase=specifying)"
```

## Step 2 — Draft spec.md

Act as the Architect (per your agent definition). Draft `features/<slug>/spec.md`:
- Brief: everything after the slug in `$ARGUMENTS` (if it references `@path/to/file`, read that file)
- Mode: new
- Cap: ~80 lines
- **If the feature has UI and the project PRD references a binding visual contract, AC4 MUST be a one-liner deferring to a numbered V1/V2/... Visual Checklist table in Technical Notes.** (Post-experiment finding #78 — prose visual ACs let drift through review.)

## Step 3 — Hand off

Confirm `features/<slug>/spec.md` exists and tell the user:
> "Spec drafted at `features/<slug>/spec.md`. Review it. For revisions: `/lean-spec:update-spec <slug>`. When ready: `/lean-spec:submit-implementation <slug>`."
