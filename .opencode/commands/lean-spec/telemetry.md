---
description: Print per-feature phase durations from the opt-in telemetry log
---

Arguments: `$ARGUMENTS` (optional slug to filter; empty = all features).

```bash
LEAN_HOME="${HOME}/.lean-spec"
TFILE="$LEAN_HOME/telemetry.jsonl"
MARKER="$LEAN_HOME/telemetry"

if [ ! -f "$MARKER" ] && [ "${LEAN_SPEC_TELEMETRY:-0}" != "1" ]; then
  echo "Telemetry is disabled."
  echo ""
  echo "Enable (persistent):  mkdir -p ~/.lean-spec && echo on > ~/.lean-spec/telemetry"
  echo "Enable (session):     export LEAN_SPEC_TELEMETRY=1"
  echo ""
  echo "OpenCode note: the Stop hook is unavailable; records are written at phase-advance"
  echo "time rather than on session end."
  exit 0
fi

if [ ! -f "$TFILE" ]; then
  echo "No telemetry data yet (log is empty)."
  exit 0
fi

FILTER="$ARGUMENTS"
if [ -n "$FILTER" ]; then
  jq -r --arg s "$FILTER" \
    'select(.slug == $s) | "\(.slug)\t\(.prev_phase) → \(.phase)\t\(.elapsed_prev_ms // "?")ms"' \
    "$TFILE" | column -t
else
  jq -r '"\(.slug)\t\(.prev_phase) → \(.phase)\t\(.elapsed_prev_ms // "?")ms"' \
    "$TFILE" | column -t
fi
```
