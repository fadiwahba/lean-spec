# lean-spec — start-spec (Codex)

Fill in the two fields below, then paste the rest into Codex.

## Inputs

- **Slug**: <kebab-case-feature-name>
- **Brief**: <one paragraph describing the feature, or a reference like `@docs/PRD.md §4.1`>

## Steps

### 1. Pre-flight

Run this bash to validate and create `features/<slug>/workflow.json`:

```bash
SLUG="<paste slug here>"
BRIEF="<paste brief here>"

if ! [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Invalid slug '$SLUG'"; exit 1
fi
[ -d "features/$SLUG" ] && { echo "Feature '$SLUG' already exists"; exit 1; }

mkdir -p "features/$SLUG"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "features/$SLUG/workflow.json" <<EOF
{
  "slug": "$SLUG",
  "phase": "specifying",
  "created_at": "$NOW",
  "updated_at": "$NOW",
  "history": [{"phase": "specifying", "entered_at": "$NOW"}],
  "artifacts": {"spec": "spec.md", "notes": "notes.md", "review": "review.md"}
}
EOF
echo "Created features/$SLUG/ (phase=specifying)"
```

### 2. Act as architect

Produce `features/<slug>/spec.md` with this structure (cap ~80 lines):

```yaml
---
slug: <slug>
phase: specifying
handoffs:
  next_command: /lean-spec:submit-implementation <slug>
  blocks_on: []
  consumed_by: [coder, reviewer]
---
```

Sections:
- **Scope** — one paragraph. What the feature does and why.
- **Acceptance Criteria** — 1–4 testable, specific, atomic criteria.
- **Out of Scope** — bullets. What's explicitly excluded.
- **Technical Notes** — tables/bullets only (no prose paragraphs).
- **Coder Guardrails** — 5–8 stack-specific anti-patterns.

**For UI features with a binding visual contract** (e.g. `docs/ux-design.png` referenced in the PRD): AC4 MUST be a one-liner that defers to a numbered V1/V2/V3... Visual Checklist table in Technical Notes. Each V-row names an exact token (hex color, px size, typography weight/size/letter-spacing) or a layout invariant. Prose visual ACs are rejected — they let drift through review.

### 3. Hand off

Tell the user: "Spec drafted at `features/<slug>/spec.md`. Review it. When ready: paste the `submit-implementation` prompt."
