---
description: Create a new feature spec and initialize the lean-spec lifecycle
argument-hint: <slug>
allowed-tools: Bash, Read, Write
---

# /lean-spec:start-spec

Initialize a new feature spec. Creates `features/<slug>/` with `workflow.json` and `spec.md`.

## Pre-flight

1. Check that `$ARGUMENTS` is provided and is a valid slug (lowercase, hyphens only). If not, say: "Usage: /lean-spec:start-spec <slug>". Stop.
```bash
SLUG="$ARGUMENTS"
if [[ -z "$SLUG" ]]; then
  echo "Usage: /lean-spec:start-spec <slug>"
  exit 1
fi
if ! [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Invalid slug '$SLUG': use lowercase letters, digits, and hyphens only (e.g. 'add-user-export')"
  exit 1
fi
```
2. Check that `features/$ARGUMENTS/` does NOT already exist. If it does, say "Feature '<slug>' already exists. Use /lean-spec:update-spec to modify it." Stop.

## Steps

1. Create `features/$ARGUMENTS/` directory.

2. Use Bash to create `features/$ARGUMENTS/workflow.json`:
```bash
SLUG="$ARGUMENTS"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "features/$SLUG/workflow.json" <<EOF
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
```

3. Create `features/$ARGUMENTS/spec.md` with this template:
```markdown
---
slug: $ARGUMENTS
phase: specifying
handoffs:
  next_command: /lean-spec:submit-implementation
  blocks_on: []
  consumed_by: [coder, reviewer]
---

# Spec: $ARGUMENTS

## Scope

<!-- What this feature does and why it matters. 2–4 sentences. -->

## Acceptance Criteria

<!-- Numbered list of verifiable criteria. -->
1. 

## Out of Scope

<!-- Explicit exclusions to prevent scope creep. -->

## Technical Notes

<!-- Implementation constraints, relevant files, design decisions. Optional. -->
```

4. Tell the user: "Feature '$ARGUMENTS' created. Fill in `features/$ARGUMENTS/spec.md`, then run `/lean-spec:submit-implementation $ARGUMENTS`."

5. Open `features/$ARGUMENTS/spec.md` for editing (Read it to show the user its content).
