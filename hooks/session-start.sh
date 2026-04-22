#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

FEATURES_DIR="$CWD/features"
SUMMARY=""

if [ -d "$FEATURES_DIR" ]; then
  while IFS= read -r wf; do
    SLUG=$(jq -r '.slug // "unknown"' "$wf" 2>/dev/null) || continue
    PHASE=$(jq -r '.phase // "unknown"' "$wf" 2>/dev/null) || continue
    [ "$PHASE" = "closed" ] && continue
    UPDATED=$(jq -r '.updated_at // ""' "$wf" 2>/dev/null)
    SUMMARY="${SUMMARY}\n- ${SLUG}: [${PHASE}] last updated ${UPDATED}"
  done < <(find "$FEATURES_DIR" -name "workflow.json" 2>/dev/null | sort)
fi

if [ -z "$SUMMARY" ]; then
  CONTEXT="lean-spec v3 active. No in-progress features. Run /lean-spec:start-spec <slug> to begin."
else
  CONTEXT="lean-spec v3 active. In-progress features:$(printf '%b' "$SUMMARY")\n\nRun /lean-spec:spec-status for details or /lean-spec:resume-spec <slug> to re-enter a feature."
fi

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
