---
description: Advance to reviewing phase and dispatch the reviewer subagent. Optional extra skills via trailing args (e.g. security, performance, full).
argument-hint: <slug> [extra-skills...]
allowed-tools: Bash, Read, Task
---

# /lean-spec:submit-review

Advance a feature from `implementing` to `reviewing` and dispatch the reviewer subagent.

**Default review runs:** `spec-compliance` + `code-quality` (always) + `visual-fidelity` (auto, IF Playwright MCP is available in this session).

**Optional extras** via trailing arguments — reviewer runs additional review skills:

```
/lean-spec:submit-review <slug>                           # default only
/lean-spec:submit-review <slug> security                  # + security
/lean-spec:submit-review <slug> security performance      # + both
/lean-spec:submit-review <slug> full                      # all available extras
```

Extras map to `skills/reviewing-<name>/SKILL.md`. Unknown extras are noted in `review.md` summary and skipped; they never fail the dispatch.

## Pre-flight

Parse `$ARGUMENTS`. First token = slug; remaining tokens = extras list (may be empty).

```bash
ARGS="$ARGUMENTS"
SLUG="${ARGS%% *}"
EXTRAS="${ARGS#$SLUG}"
EXTRAS="${EXTRAS# }"   # trim leading space
```

1. Check `$SLUG` provided and non-empty.
2. Verify `features/$SLUG/workflow.json` exists.
3. Read `features/$SLUG/workflow.json` and verify current phase is `implementing`. If not, say: "Phase gate: expected 'implementing', got '<phase>'."
4. Verify `features/$SLUG/notes.md` exists. If not, say: "notes.md not found. The coder subagent must produce notes.md before review can proceed."

## Steps

1. Advance phase to `reviewing`. **If this block exits non-zero, STOP — do not dispatch the subagent. Report the error verbatim to the user.**
```bash
set -e
WF="features/$SLUG/workflow.json"
CURRENT=$(jq -r '.phase // ""' "$WF" 2>/dev/null)
if [ "$CURRENT" != "implementing" ]; then
  echo "Phase gate: expected 'implementing', got '$CURRENT'" >&2; exit 1
fi
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp "${WF}.tmp.XXXXXX")
jq --arg p "reviewing" --arg now "$NOW" \
  '.phase = $p | .updated_at = $now | .history += [{"phase": $p, "entered_at": $now}]' \
  "$WF" > "$tmp"
mv -f "$tmp" "$WF" || { echo "ERROR: mv failed — workflow.json not updated. Orphan tmp: $tmp" >&2; exit 1; }
NEW_PHASE=$(jq -r '.phase // ""' "$WF" 2>/dev/null)
if [ "$NEW_PHASE" != "reviewing" ]; then
  echo "ERROR: phase did not advance — expected 'reviewing', still '$NEW_PHASE'. Aborting before subagent dispatch." >&2
  exit 1
fi
echo "phase advanced: implementing → reviewing"
```

2. Determine a diff reference for the reviewer. Prefer an explicit git range (e.g. `git log --oneline -n 10` to find the last pre-implementation commit), or fall back to "list files modified since the `implementing` phase began" via `git status`/`git diff --name-only`.

3. Dispatch the **reviewer subagent** using the `Task` tool:

   - `subagent_type`: `"lean-spec:reviewer"` — the plugin-provided reviewer (see `agents/reviewer.md`). Its frontmatter pins `model: opus`; do not override.
   - `description`: `"Review <slug>"`
   - `prompt`: build a fresh invocation payload like this (the reviewer's system prompt comes from `agents/reviewer.md`; do not include it yourself). Include the `Extras:` line ONLY if `$EXTRAS` is non-empty:

     ```
     Slug: <slug>
     Spec path: features/<slug>/spec.md
     Notes path: features/<slug>/notes.md
     Review path: features/<slug>/review.md
     Diff reference: <git range or list of modified files from step 2>
     Extras: <contents of $EXTRAS — e.g. "security performance" or "full">
     ```

4. Tell the user: "Dispatching reviewer subagent for '$SLUG'. Extras: `<extras or 'none'>`. Expected output: features/$SLUG/review.md with verdict APPROVE | NEEDS_FIXES | BLOCKED."
