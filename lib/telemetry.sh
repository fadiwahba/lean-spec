#!/usr/bin/env bash
#
# lib/telemetry.sh — opt-in local telemetry for lean-spec lifecycle transitions.
#
# Opts in when EITHER is true:
#   - Env var  LEAN_SPEC_TELEMETRY=1
#   - Marker   ~/.lean-spec/telemetry  (content = "on")
#
# Writes one JSONL record per phase transition to ~/.lean-spec/telemetry.jsonl.
# Record shape:
#   {
#     "slug": "<feature slug>",
#     "phase": "<new phase>",
#     "prev_phase": "<phase before this one or null for the first history entry>",
#     "entered_at": "<ISO 8601 from workflow.json history>",
#     "logged_at":  "<ISO 8601 when this record was written>",
#     "elapsed_prev_ms": <ms spent in prev_phase, or null for the first entry>
#   }
#
# Sync is IDEMPOTENT — re-running never duplicates. The sync reads the current
# JSONL (if any) to know which (slug, entered_at) tuples are already logged.
#
# No network calls. No aggregation service. No hostname or user identity is
# written. Purpose is strictly to let a skeptical user verify the cost-arbitrage
# claim empirically on their own machine (PRD §12.4).

TELEMETRY_DIR="${LEAN_SPEC_TELEMETRY_DIR:-$HOME/.lean-spec}"
TELEMETRY_FILE="$TELEMETRY_DIR/telemetry.jsonl"
TELEMETRY_MARKER="$TELEMETRY_DIR/telemetry"

# Returns 0 (true) if telemetry is enabled.
telemetry_enabled() {
  if [ "${LEAN_SPEC_TELEMETRY:-}" = "1" ]; then return 0; fi
  if [ -f "$TELEMETRY_MARKER" ] && [ "$(cat "$TELEMETRY_MARKER" 2>/dev/null)" = "on" ]; then return 0; fi
  return 1
}

# Sync telemetry from a workflow.json. Appends any history entries that aren't
# already in the JSONL. Idempotent.
#
# Usage: telemetry_sync <workflow.json path>
telemetry_sync() {
  telemetry_enabled || return 0
  local wf="$1"
  [ -f "$wf" ] || return 0

  mkdir -p "$TELEMETRY_DIR"
  touch "$TELEMETRY_FILE"

  local slug
  slug=$(jq -r '.slug // empty' "$wf" 2>/dev/null)
  [ -z "$slug" ] && return 0

  # Read history as tab-separated (phase, entered_at) pairs, process in order
  local prev_phase=""
  local prev_entered=""
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  while IFS=$'\t' read -r phase entered; do
    [ -z "$phase" ] && continue
    # Skip if already logged
    if grep -qF "\"slug\":\"$slug\"" "$TELEMETRY_FILE" 2>/dev/null && \
       grep -qF "\"entered_at\":\"$entered\"" "$TELEMETRY_FILE" 2>/dev/null && \
       # combined check: same slug AND same entered_at on the same line
       awk -v s="$slug" -v e="$entered" '
         $0 ~ ("\"slug\":\""s"\"") && $0 ~ ("\"entered_at\":\""e"\"") { found=1; exit }
         END { exit found ? 0 : 1 }
       ' "$TELEMETRY_FILE" >/dev/null 2>&1; then
      prev_phase="$phase"
      prev_entered="$entered"
      continue
    fi

    # Compute elapsed ms from prev_entered → entered
    local elapsed="null"
    if [ -n "$prev_entered" ]; then
      # Use python for portable ISO 8601 arithmetic (macOS date doesn't parse ISO natively)
      elapsed=$(python3 -c "
from datetime import datetime
try:
    a = datetime.fromisoformat('$prev_entered'.replace('Z','+00:00'))
    b = datetime.fromisoformat('$entered'.replace('Z','+00:00'))
    ms = int((b - a).total_seconds() * 1000)
    print(ms)
except Exception:
    print('null')
")
    fi

    local prev_json="null"
    [ -n "$prev_phase" ] && prev_json="\"$prev_phase\""

    jq -n -c \
      --arg slug "$slug" \
      --arg phase "$phase" \
      --argjson prev "$prev_json" \
      --arg entered "$entered" \
      --arg logged "$now" \
      --argjson elapsed "$elapsed" \
      '{
        slug: $slug,
        phase: $phase,
        prev_phase: $prev,
        entered_at: $entered,
        logged_at: $logged,
        elapsed_prev_ms: $elapsed
      }' >> "$TELEMETRY_FILE"

    prev_phase="$phase"
    prev_entered="$entered"
  done < <(jq -r '.history[]? | [.phase, .entered_at] | @tsv' "$wf" 2>/dev/null)
}

# Sync every workflow.json under a project root. Called by the Stop hook.
#
# Usage: telemetry_sync_all <project-root>
telemetry_sync_all() {
  telemetry_enabled || return 0
  local root="$1"
  [ -d "$root/features" ] || return 0
  while IFS= read -r wf; do
    telemetry_sync "$wf"
  done < <(find "$root/features" -name "workflow.json" 2>/dev/null)
}

# Print a per-feature summary table.
#
# Usage: telemetry_report [slug-filter]
telemetry_report() {
  local filter="${1:-}"
  if [ ! -s "$TELEMETRY_FILE" ]; then
    echo "No telemetry records yet. Opt in with LEAN_SPEC_TELEMETRY=1 or ~/.lean-spec/telemetry=on."
    return 0
  fi

  python3 - <<PY
import json, sys
from collections import defaultdict

path = '$TELEMETRY_FILE'
filter_slug = '$filter' or None

records = []
with open(path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except Exception:
            continue

if filter_slug:
    records = [r for r in records if r.get('slug') == filter_slug]

by_slug = defaultdict(list)
for r in records:
    by_slug[r['slug']].append(r)

if not by_slug:
    print(f"No records for slug '{filter_slug}'" if filter_slug else "No records.")
    sys.exit(0)

# Per-feature summary
print(f"{'Feature':<30} {'Phases':<40} {'Total (s)':>10}")
print('-' * 82)

for slug, rs in sorted(by_slug.items()):
    rs_sorted = sorted(rs, key=lambda r: r['entered_at'])
    phases = ' → '.join(r['phase'] for r in rs_sorted)
    elapsed_ms = sum((r.get('elapsed_prev_ms') or 0) for r in rs_sorted if r.get('elapsed_prev_ms'))
    elapsed_s = int(elapsed_ms / 1000) if elapsed_ms else 0
    print(f"{slug:<30} {phases:<40} {elapsed_s:>10}")

print()
print(f"Total features tracked: {len(by_slug)}")
print(f"Source: {path}")
PY
}
