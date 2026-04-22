#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

FEATURES_DIR="$CWD/features"
[ -d "$FEATURES_DIR" ] || exit 0

case "$AGENT_TYPE" in
  architect)
    EXPECTED_ARTIFACT="spec.md"
    EXPECTED_PHASE="specifying"
    ;;
  coder)
    EXPECTED_ARTIFACT="notes.md"
    EXPECTED_PHASE="implementing"
    ;;
  reviewer)
    EXPECTED_ARTIFACT="review.md"
    EXPECTED_PHASE="reviewing"
    ;;
  *)
    exit 0
    ;;
esac

MISSING=""

while IFS= read -r wf; do
  SLUG=$(jq -r '.slug // ""' "$wf" 2>/dev/null) || continue
  PHASE=$(jq -r '.phase // ""' "$wf" 2>/dev/null) || continue
  [ "$PHASE" = "$EXPECTED_PHASE" ] || continue

  ARTIFACT="$FEATURES_DIR/$SLUG/$EXPECTED_ARTIFACT"
  if [ ! -f "$ARTIFACT" ]; then
    MISSING="${MISSING}\n- '${SLUG}': ${EXPECTED_ARTIFACT} not found"
  fi
done < <(find "$FEATURES_DIR" -name "workflow.json" 2>/dev/null | sort)

if [ -n "$MISSING" ]; then
  MSG="${AGENT_TYPE} subagent must produce ${EXPECTED_ARTIFACT} before stopping:$(printf '%b' "$MISSING")"
  jq -n --arg reason "$MSG" '{ decision: "block", reason: $reason }'
  exit 0
fi

exit 0
