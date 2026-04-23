---
description: Draft a project-level docs/PRD.md from a topic
agent: brainstormer
subtask: true
---

Arguments: `$ARGUMENTS` (topic / pitch, optionally with `@path/to/refs`).

## Step 1 — Pre-flight

```bash
[ -n "$ARGUMENTS" ] || { echo "Usage: /lean-spec:brainstorm <topic>"; exit 1; }
if [ -f "docs/PRD.md" ]; then
  echo "docs/PRD.md already exists. Either edit, back up, or delete first."
  exit 1
fi
mkdir -p docs
```

## Step 2 — Draft

Act as the Brainstormer (per your agent definition). Read `templates/PRD.md` for shape. Apply it to the topic `$ARGUMENTS`. Use `<TODO — clarify with user>` for fields with insufficient signal. Do not invent stakeholders/timelines/constraints.

If the project has no UI, omit Implementation Contract + Design Language sections.

Write the draft to `docs/PRD.md`.

## Step 3 — Hand off

Tell the user: "Draft PRD written. Review — `<TODO>` placeholders need your input. When happy, run `/lean-spec:decompose-prd`."
