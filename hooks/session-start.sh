#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Source the next-command helper (F9 semi-auto driver).
NEXT_LIB="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/lib/next-command.sh"
if [ -f "$NEXT_LIB" ]; then
  # shellcheck disable=SC1090
  source "$NEXT_LIB"
fi

FEATURES_DIR="$CWD/features"
SUMMARY=""

if [ -d "$FEATURES_DIR" ]; then
  while IFS= read -r wf; do
    SLUG=$(jq -r '.slug // "unknown"' "$wf" 2>/dev/null) || continue
    PHASE=$(jq -r '.phase // "unknown"' "$wf" 2>/dev/null) || continue
    [ "$PHASE" = "closed" ] && continue
    UPDATED=$(jq -r '.updated_at // ""' "$wf" 2>/dev/null)
    # Compute phase-appropriate next command when the helper is available.
    NEXT=""
    if declare -f next_command_for >/dev/null 2>&1; then
      NEXT=$(next_command_for "$wf" 2>/dev/null || echo "")
    fi
    if [ -n "$NEXT" ]; then
      SUMMARY="${SUMMARY}\n- ${SLUG}: [${PHASE}] last updated ${UPDATED} — next: \`${NEXT}\`"
    else
      SUMMARY="${SUMMARY}\n- ${SLUG}: [${PHASE}] last updated ${UPDATED}"
    fi
  done < <(find "$FEATURES_DIR" -name "workflow.json" 2>/dev/null | sort)
fi

if [ -z "$SUMMARY" ]; then
  CONTEXT="lean-spec v3 active. No in-progress features. Run /lean-spec:start-spec <slug> to begin."
else
  CONTEXT="lean-spec v3 active. In-progress features:$(printf '%b' "$SUMMARY")\n\nRun /lean-spec:next to advance the most-recently-updated feature, /lean-spec:spec-status for details, or /lean-spec:resume-spec <slug> to re-enter a feature."
fi

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
