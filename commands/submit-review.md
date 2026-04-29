---
description: Advance to reviewing phase and dispatch the reviewer subagent. Optional extra skills via trailing args (e.g. security, performance, full).
argument-hint: <slug> [--visual] [extra-skills...] [--no-rules]
allowed-tools: Bash, Read, Task
---

# /lean-spec:submit-review

Advance a feature from `implementing` to `reviewing` and dispatch the reviewer subagent.

**Default review runs:** `spec-compliance` + `code-quality`. Add `--visual` to also run Playwright visual-fidelity check. Alternatively, run `/lean-spec:visual-check <slug>` as a standalone step after review.

**Optional extras** via trailing arguments — reviewer runs additional review skills:

```
/lean-spec:submit-review <slug>                           # default only (text review)
/lean-spec:submit-review <slug> --visual                  # + Playwright visual check
/lean-spec:submit-review <slug> security                  # + security
/lean-spec:submit-review <slug> --visual security         # + visual + security
/lean-spec:submit-review <slug> full                      # all available extras
```

Extras map to `skills/reviewing-<name>/SKILL.md`. Unknown extras are noted in `review.md` summary and skipped; they never fail the dispatch.

Pass `--no-rules` to skip `rules.yaml` validation for this invocation.

## Pre-flight

Parse `$ARGUMENTS`. First token = slug; remaining tokens = flags + extras list.

```bash
ARGS="$ARGUMENTS"
SLUG="${ARGS%% *}"
REST="${ARGS#$SLUG}"
REST="${REST# }"   # trim leading space

# Detect --visual flag and strip it from extras
VISUAL=no
EXTRAS=""
for tok in $REST; do
  case "$tok" in
    --visual) VISUAL=yes ;;
    *)        EXTRAS="$EXTRAS $tok" ;;
  esac
done
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

3. Read the model override for the reviewer (if any): check if `.lean-spec/rules.yaml` exists and contains a `models.reviewer:` key. If found, use that value as `model` in the Task call. If not, omit `model` — the agent's frontmatter default (`sonnet`) applies.

4. Dispatch the **reviewer subagent** using the `Task` tool:

   - `subagent_type`: `"lean-spec:reviewer"` — the plugin-provided reviewer (see `agents/reviewer.md`). Its frontmatter default is `model: sonnet`. Override via `.lean-spec/rules.yaml` models block if present.
   - `description`: `"Review <slug>"`
   - `prompt`: build a fresh invocation payload like this (the reviewer's system prompt comes from `agents/reviewer.md`; do not include it yourself). Include the `Extras:` line ONLY if `$EXTRAS` is non-empty:

     ```
     Slug: <slug>
     Spec path: features/<slug>/spec.md
     Notes path: features/<slug>/notes.md
     Review path: features/<slug>/review.md
     Diff reference: <git range or list of modified files from step 3>
     Visual: <yes|no>
     Extras: <contents of $EXTRAS — e.g. "security performance" or "full">
     ```

     Include the `Extras:` line ONLY if `$EXTRAS` is non-empty. Always include the `Visual:` line.

5. Tell the user: "Dispatching reviewer subagent for '$SLUG'. Visual: `<yes|no>`. Extras: `<extras or 'none'>`. Expected output: features/$SLUG/review.md with verdict APPROVE | NEEDS_FIXES | BLOCKED."
