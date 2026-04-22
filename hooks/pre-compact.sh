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
    SPEC="$FEATURES_DIR/$SLUG/spec.md"
    SPEC_SNIPPET=""
    if [ -f "$SPEC" ]; then
      SPEC_SNIPPET=$(head -20 "$SPEC" 2>/dev/null | tr '\n' ' ')
    fi
    SUMMARY="${SUMMARY}\n### $SLUG [$PHASE]\n$SPEC_SNIPPET"
  done < <(find "$FEATURES_DIR" -name "workflow.json" 2>/dev/null | sort)
fi

if [ -z "$SUMMARY" ]; then
  CONTEXT="lean-spec: no in-progress features to preserve."
else
  CONTEXT="lean-spec pre-compact snapshot:$(printf '%b' "$SUMMARY")"
fi

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "PreCompact",
    additionalContext: $ctx
  }
}'
