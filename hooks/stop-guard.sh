#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

FEATURES_DIR="$CWD/features"

# F19 telemetry sync (opt-in; no-ops if disabled). Runs BEFORE the artifact
# guard so even blocked stops still flush completed phase transitions.
TELE_LIB="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/lib/telemetry.sh"
if [ -f "$TELE_LIB" ]; then
  # shellcheck disable=SC1090
  source "$TELE_LIB"
  telemetry_sync_all "$CWD" 2>/dev/null || true
fi

[ -d "$FEATURES_DIR" ] || exit 0

# Cross-provider mode: sentinel disables artifact guard (Gemini writes artifacts asynchronously)
[ -f "$CWD/.lean-spec/cross-provider" ] && exit 0

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
