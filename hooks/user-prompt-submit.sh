#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Source rules library (best-effort — hooks/ and lib/ are siblings in the plugin root).
# CLAUDE_PLUGIN_ROOT is exported by Claude Code at hook-execution time.
RULES_LIB="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/lib/rules.sh"
if [ -f "$RULES_LIB" ]; then
  # shellcheck disable=SC1090
  source "$RULES_LIB"
fi

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

# Map phase-advancing command → (artifact_type, artifact_path_tail) to validate
# before allowing the phase advance. submit-fixes is intentionally exempt — no
# new artifact has been produced at that point (coder is about to run again).
artifact_for() {
  case "$1" in
    submit-implementation) echo "spec.md" ;;
    submit-review)         echo "notes.md" ;;
    close-spec)            echo "review.md" ;;
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
    echo "lean-spec block: feature '$SLUG' not found — run /lean-spec:start-spec $SLUG first." >&2
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
    echo "lean-spec block: $MSG" >&2
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

  # --- rules.yaml enforcement (F11) ---------------------------------------
  # Only runs if:
  #   (1) rules library loaded successfully
  #   (2) .lean-spec/rules.yaml exists in the project (rules_exist)
  #   (3) this command has an artifact to validate (submit-fixes is skipped)
  if declare -f rules_enforce >/dev/null 2>&1; then
    cd "$CWD"
    if rules_exist; then
      ARTIFACT=$(artifact_for "$COMMAND")
      if [ -n "$ARTIFACT" ]; then
        ARTIFACT_PATH="features/$SLUG/$ARTIFACT"
        # Capture stderr from rules_enforce to surface violations to the user.
        RULES_OUTPUT=$(rules_enforce "$ARTIFACT" "$ARTIFACT_PATH" 2>&1 || true)
        if [ -n "$RULES_OUTPUT" ] && echo "$RULES_OUTPUT" | grep -q "rules violation"; then
          MSG="$RULES_OUTPUT"
          HINT="Fix the violations above (edit $ARTIFACT_PATH) or relax the rule in $(rules_path) before re-running /lean-spec:$COMMAND $SLUG."
          echo "lean-spec block (rules): $MSG" >&2
          jq -n --arg msg "$MSG" --arg hint "$HINT" --arg slug "$SLUG" --arg artifact "$ARTIFACT" '{
            decision: "block",
            reason: $msg,
            hookSpecificOutput: {
              hookEventName: "UserPromptSubmit",
              additionalContext: ($msg + "\n\n" + $hint)
            }
          }'
          exit 2
        fi
      fi
    fi
  fi
fi

# Allow (with context injection noting lean-spec is active)
exit 0
