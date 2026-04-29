# lean-spec — spec-all (Codex)

## Purpose

Write `spec.md` for every feature currently in `specifying` phase. Equivalent of running `update-spec` for each slug, but in one shot.

## Steps

### 1. Discover specifying-phase features

```bash
find features -name workflow.json 2>/dev/null \
  | xargs -I{} sh -c 'jq -r "select(.phase==\"specifying\") | .slug" "{}" 2>/dev/null' \
  | sort
```

If the list is empty, stop: "No features in specifying phase."

### 2. Check for model override

```bash
MODEL_OVERRIDE=""
if [ -f ".lean-spec/rules.yaml" ]; then
  MODEL_OVERRIDE=$(grep -E "^\s+architect:" .lean-spec/rules.yaml | awk '{print $2}' | tr -d '"' 2>/dev/null || true)
fi
[ -n "$MODEL_OVERRIDE" ] && echo "Model override: $MODEL_OVERRIDE" || echo "Using default model"
```

(In Codex, model overrides are informational — Codex uses whichever model is active.)

### 3. Act as architect for each slug

For each slug from Step 1:

1. Read `docs/PRD.md` to find the feature section matching the slug.
2. Read `features/<slug>/spec.md` (may be a skeleton).
3. Write a complete `features/<slug>/spec.md` following the structure in `skills/writing-specs/SKILL.md`:
   - Frontmatter (slug, phase: specifying, blocks_on: [])
   - Scope
   - Acceptance Criteria (functional + visual if applicable)
   - Out of Scope
   - Coder Guardrails
4. Cap at ~80 lines.

Work sequentially. After all: "spec-all complete — N features specced: <slug-list>."

### 4. Hand off

Tell the user the next prompt to paste: `submit-implementation` for each slug, or `auto-all` to drive all automatically.
