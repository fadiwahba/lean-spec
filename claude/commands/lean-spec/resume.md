---
name: resume
description: Rebuild lean-spec workflow state after context compaction, session pause, or model change.
---

Resume the lean-spec feature identified by `$ARGUMENTS`.

## Rules

- Require a slug. If none is provided, ask for one.
- Do not make code changes before completing the state rebuild.
- Do not jump into implementation or review before re-establishing workflow state.
- This framework is human-controlled. `resume` rebuilds state and reports the correct next step; it does not auto-continue unless the human explicitly asked to proceed.
- Rebuild state from the canonical feature artifacts only.

## Step 1: Read Artifacts in Order

Read these files in this exact sequence:

1. `lean-spec/features/<slug>/spec.md`
2. `lean-spec/features/<slug>/review.md`
3. `lean-spec/features/<slug>/notes.md`

## Step 2: Rebuild and Report State

Report:
- current phase and who owns it
- feature status from `spec.md`
- count of open notes and review findings
- whether the spec appears stale relative to notes or review findings
- the single correct next action
- whether the workflow should pause for the human or can continue because the human explicitly asked it to proceed

## Step 3: Continue or Pause

- If the human asked for a summary only: stop after the report and wait.
- If the human explicitly asked to proceed: continue from the correct phase.
- Do not ask vague follow-up questions.

## Phase Inference

Infer the current phase from artifact state:
1. Use `spec.md` status as the primary signal.
2. Use open findings in `review.md` to determine whether the feature is in review or needs another implementation pass.
3. Use open items in `notes.md` to determine whether work is blocked or partially complete.
4. Infer the current owner from the next correct manual phase:
   - planning or review -> `architect`
   - implementation or review fixes -> `coder`
   - final summary / stop -> default session agent
5. Report that state was reconstructed from the canonical feature artifacts.
