#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Map command → required current phase (case-based; no associative arrays for bash 3 compat)
required_phase_for() {
  case "$1" in
    submit-implementation) echo "specifying" ;;
    submit-review)         echo "implementing" ;;
    submit-fixes)          echo "reviewing" ;;
    close-spec)            echo "reviewing" ;;
    *)                     echo "" ;;
  esac
}

# Check if prompt contains a /lean-spec:* command that advances phase
if [[ "$PROMPT" =~ /lean-spec:(submit-implementation|submit-review|submit-fixes|close-spec)[[:space:]]+([a-z0-9][a-z0-9-]*) ]]; then
  COMMAND="${BASH_REMATCH[1]}"
  SLUG="${BASH_REMATCH[2]}"
  REQUIRED=$(required_phase_for "$COMMAND")

  WF="$CWD/features/$SLUG/workflow.json"

  if [ ! -f "$WF" ]; then
    jq -n --arg slug "$SLUG" '{
      decision: "block",
      reason: ("Feature '\''"+$slug+"'\'' not found. Run /lean-spec:start-spec "+$slug+" first."),
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: ("No workflow.json found for feature "+$slug)
      }
    }'
    exit 2
  fi

  CURRENT=$(jq -r '.phase // ""' "$WF" 2>/dev/null)

  if [ "$CURRENT" != "$REQUIRED" ]; then
    MSG="Phase gate: /lean-spec:${COMMAND} requires phase '${REQUIRED}', but '${SLUG}' is in phase '${CURRENT}'."
    jq -n --arg msg "$MSG" --arg current "$CURRENT" --arg required "$REQUIRED" --arg cmd "$COMMAND" --arg slug "$SLUG" '{
      decision: "block",
      reason: $msg,
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: ("Phase gate blocked: current="+$current+" required="+$required+". Check /lean-spec:spec-status "+$slug+" for current state.")
      }
    }'
    exit 2
  fi
fi

# Allow (with context injection noting lean-spec is active)
exit 0
