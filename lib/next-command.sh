#!/usr/bin/env bash
#
# lib/next-command.sh — compute the next lifecycle command for a feature.
#
# Given a workflow.json path (and optionally a review.md path), returns the
# lean-spec slash command the user should run to advance, or empty string if
# no advance is possible.
#
# Used by:
#   - hooks/session-start.sh to annotate the session summary
#   - commands/next.md to resolve "what's next" for the active feature
#
# Exit code is always 0 unless inputs are malformed. On success, prints the
# command to stdout. An empty stdout means "no actionable next step".

# next_command_for <workflow.json path>
# Prints the phase-appropriate next command, e.g.
#   /lean-spec:submit-implementation pomodoro
# For reviewing phase, consults features/<slug>/review.md verdict.
next_command_for() {
  local wf="$1"
  [ -f "$wf" ] || return 0
  local slug phase review
  slug=$(jq -r '.slug // empty' "$wf" 2>/dev/null)
  phase=$(jq -r '.phase // empty' "$wf" 2>/dev/null)
  [ -z "$slug" ] && return 0

  case "$phase" in
    specifying)
      echo "/lean-spec:submit-implementation $slug"
      ;;
    implementing)
      echo "/lean-spec:submit-review $slug"
      ;;
    reviewing)
      # Verdict determines next step
      review="$(dirname "$wf")/review.md"
      if [ -f "$review" ]; then
        local verdict
        verdict=$(awk '/^verdict:/ { gsub(/[[:space:]]/, "", $0); sub(/^verdict:/, "", $0); print; exit }' "$review")
        case "$verdict" in
          APPROVE)      echo "/lean-spec:close-spec $slug" ;;
          NEEDS_FIXES)  echo "/lean-spec:submit-fixes $slug" ;;
          BLOCKED)      echo "# BLOCKED — human intervention required for '$slug'" ;;
          *)            echo "/lean-spec:spec-status $slug  # verdict unclear" ;;
        esac
      else
        echo "/lean-spec:spec-status $slug  # awaiting reviewer output"
      fi
      ;;
    closed)
      # No advance — feature is done
      ;;
    *)
      # Unknown phase
      ;;
  esac
}

# active_feature <features-dir>
# Prints the path to the most-recently-updated workflow.json of a non-closed feature.
# Empty output means no active feature.
active_feature() {
  local features_dir="$1"
  [ -d "$features_dir" ] || return 0
  local best="" best_time=""
  while IFS= read -r wf; do
    local phase updated
    phase=$(jq -r '.phase // ""' "$wf" 2>/dev/null)
    updated=$(jq -r '.updated_at // ""' "$wf" 2>/dev/null)
    [ "$phase" = "closed" ] && continue
    [ -z "$phase" ] && continue
    if [ -z "$best_time" ] || [[ "$updated" > "$best_time" ]]; then
      best="$wf"
      best_time="$updated"
    fi
  done < <(find "$features_dir" -name "workflow.json" 2>/dev/null)
  [ -n "$best" ] && echo "$best"
}
