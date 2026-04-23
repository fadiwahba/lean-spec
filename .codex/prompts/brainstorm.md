# lean-spec — brainstorm (Codex)

Greenfield entry: draft a project-level `docs/PRD.md` from a topic.

## Inputs

- **Topic**: <one-line pitch or topic>
- **Refs** (optional): paths to context files (will be read inline)

## Steps

### 1. Pre-flight

```bash
TOPIC="<paste topic>"
[ -n "$TOPIC" ] || { echo "Usage: supply a topic"; exit 1; }
[ -f "docs/PRD.md" ] && { echo "docs/PRD.md already exists. Edit or back up first."; exit 1; }
mkdir -p docs
```

### 2. Draft

Read `templates/PRD.md` (in the lean-spec repo) for the canonical shape. Apply it to the topic above.

Structure (from the template):
- Implementation Contract (binding visual — omit if no UI)
- §1 Overview
- §2 Design Language (token table + typography — omit if no UI)
- §3 Layout
- §4 Features (named elements, tables over prose, max ~3)
- §5 State Model
- §6 Derived Values
- §7 Interactions Summary
- §8 Out of Scope

**Be honest** — use `<TODO — clarify with user>` where the topic doesn't give enough signal. Do not invent stakeholders, timelines, or constraints.

Write the draft to `docs/PRD.md`.

### 3. Hand off

Tell the user: "Draft PRD at `docs/PRD.md`. Review — `<TODO>` placeholders need your input. When happy, paste `decompose-prd` to emit feature skeletons."
