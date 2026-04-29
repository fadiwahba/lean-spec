---
description: Dispatch architect for every feature currently in specifying phase (batch spec-all)
argument-hint: (no arguments)
allowed-tools: Bash, Read, Task
---

# /lean-spec:spec-all

Dispatch the architect subagent for every feature in `specifying` phase, in parallel. Use this after `/lean-spec:decompose-prd` to write all specs in one shot before handing off to a coder (or another provider).

## Pre-flight

```bash
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
FEATURES_DIR="$PROJ/features"
if [ ! -d "$FEATURES_DIR" ]; then
  echo "No features/ directory found. Run /lean-spec:decompose-prd first."
  exit 1
fi
```

## Steps

1. Discover all features in `specifying` phase:

   ```bash
   find features -name workflow.json 2>/dev/null \
     | xargs -I{} sh -c 'jq -r "select(.phase==\"specifying\") | .slug" "{}" 2>/dev/null' \
     | sort
   ```

   If the list is empty, tell the user "No features in specifying phase." and stop.

2. Read `.lean-spec/rules.yaml` if it exists. Extract `models.architect` if present — this overrides the default model for each dispatch. If absent, omit the model parameter (agent frontmatter default applies).

3. For each slug in the list, read `features/<slug>/spec.md` (may be a skeleton — that is expected).

4. Dispatch one **architect subagent** per slug **in parallel** using the `Task` tool. For each:

   - `subagent_type`: `"lean-spec:architect"`
   - `description`: `"Spec <slug>"`
   - `model`: the value from step 2 if present, otherwise omit this field
   - `prompt`:

     ```
     Slug: <slug>
     Spec path: features/<slug>/spec.md
     PRD path: docs/PRD.md
     Mode: initial — write the full spec from the PRD feature section

     Read docs/PRD.md to find the section for this slug. Write a complete spec.md
     following the writing-specs skill. Cap at ~80 lines.
     ```

5. After all subagents return, report:

   ```
   spec-all complete — N features specced: <slug-list>
   Run /lean-spec:submit-implementation <slug> to start each, or /lean-spec:auto-all to drive all automatically.
   ```

## Notes

- **Do not invoke the `writing-specs` skill in the orchestrator context.** That skill is for the architect subagent.
- **Do not edit `spec.md` directly.** Every spec must be written by a dispatched architect so the strong-model tier is enforced at runtime.
- Features already in `implementing`, `reviewing`, or `closed` are skipped — only `specifying` phase features are dispatched.
