#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

FEATURES_DIR="$CWD/features"
[ -d "$FEATURES_DIR" ] || exit 0

MISSING=""

while IFS= read -r wf; do
  SLUG=$(jq -r '.slug // ""' "$wf" 2>/dev/null) || continue
  PHASE=$(jq -r '.phase // ""' "$wf" 2>/dev/null) || continue

  case "$PHASE" in
    implementing)
      ARTIFACT="$FEATURES_DIR/$SLUG/notes.md"
      if [ ! -f "$ARTIFACT" ]; then
        MISSING="${MISSING}\n- '${SLUG}' is in 'implementing' but notes.md is missing"
      fi
      ;;
    reviewing)
      ARTIFACT="$FEATURES_DIR/$SLUG/review.md"
      if [ ! -f "$ARTIFACT" ]; then
        MISSING="${MISSING}\n- '${SLUG}' is in 'reviewing' but review.md is missing"
      fi
      ;;
  esac
done < <(find "$FEATURES_DIR" -name "workflow.json" 2>/dev/null | sort)

if [ -n "$MISSING" ]; then
  MSG="lean-spec stop guard: expected artifacts are missing:$(printf '%b' "$MISSING")\n\nProduce the missing artifacts before ending this turn."
  jq -n --arg reason "$MSG" '{ decision: "block", reason: $reason }'
  exit 0
fi

exit 0
