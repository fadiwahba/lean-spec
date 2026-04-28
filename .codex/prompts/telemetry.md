# lean-spec — telemetry (Codex)

Read or manage the opt-in local telemetry log (`~/.lean-spec/telemetry.jsonl`).

## Enable / disable

```bash
# Enable (persistent marker file)
mkdir -p ~/.lean-spec && echo "on" > ~/.lean-spec/telemetry

# Enable (session env var)
export LEAN_SPEC_TELEMETRY=1

# Disable
unset LEAN_SPEC_TELEMETRY
rm -f ~/.lean-spec/telemetry

# Wipe history
rm -f ~/.lean-spec/telemetry.jsonl
```

## View report

```bash
SLUG=""   # optional: set to a slug to filter; leave empty for all features
TFILE="$HOME/.lean-spec/telemetry.jsonl"

if [ ! -f "$TFILE" ]; then
  echo "No telemetry data yet."
  exit 0
fi

if [ -n "$SLUG" ]; then
  jq -r --arg s "$SLUG" \
    'select(.slug == $s) | "\(.slug)\t\(.prev_phase) → \(.phase)\t\(.elapsed_prev_ms // "?")ms"' \
    "$TFILE" | column -t
else
  jq -r '"\(.slug)\t\(.prev_phase) → \(.phase)\t\(.elapsed_prev_ms // "?")ms"' \
    "$TFILE" | column -t
fi
```

## Note

In Codex, the `Stop` hook is unavailable, so telemetry records are not auto-synced at session end. Phase advances write records directly when each Codex prompt executes the relevant lifecycle bash block.
