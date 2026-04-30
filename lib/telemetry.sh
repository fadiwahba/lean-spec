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
#     "elapsed_prev_ms": <ms spent in prev_phase, or null for the first entry>,
#     "artifact_bytes": <bytes of artifact produced in prev_phase, 0 if not applicable>,
#     "estimated_tokens": <artifact_bytes / 4, output token estimate>,
#     "model": "<Opus|Haiku|null>",
#     "estimated_cost_usd": <output-token cost estimate, null if not applicable>,
#     "precision": "estimated" | null
#   }
#
# Token/cost estimates are output-only and based on artifact file sizes.
# Actual cost is typically 2-5x higher (input context not included).
# Opus output: $75/M tokens. Haiku output: $4/M tokens.
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
# Usage: telemetry_sync <workflow.json path> [project-root]
telemetry_sync() {
  telemetry_enabled || return 0
  local wf="$1"
  local project_root="${2:-}"
  local project_name=""
  [ -n "$project_root" ] && project_name=$(basename "$project_root")
  [ -f "$wf" ] || return 0

  mkdir -p "$TELEMETRY_DIR"
  touch "$TELEMETRY_FILE"

  local slug
  slug=$(jq -r '.slug // empty' "$wf" 2>/dev/null)
  [ -z "$slug" ] && return 0

  local feature_dir
  feature_dir=$(dirname "$wf")

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

    # Artifact measurement for token/cost estimation
    # Maps: prev_phase → artifact file + model tier used to produce it
    local artifact_bytes=0
    local estimated_tokens=0
    local model_name=""
    local estimated_cost_usd="null"

    if [ -n "$prev_phase" ]; then
      local artifact_file=""
      case "$prev_phase" in
        specifying)   artifact_file="$feature_dir/spec.md";   model_name="Opus" ;;
        implementing) artifact_file="$feature_dir/notes.md";  model_name="Haiku" ;;
        reviewing)    artifact_file="$feature_dir/review.md"; model_name="Opus" ;;
      esac

      if [ -n "$artifact_file" ] && [ -f "$artifact_file" ]; then
        artifact_bytes=$(wc -c < "$artifact_file" | tr -d ' ')
        estimated_tokens=$((artifact_bytes / 4))
        estimated_cost_usd=$(python3 -c "
tokens = $estimated_tokens
prices = {'Opus': 75.0 / 1000000, 'Haiku': 4.0 / 1000000}
cost = tokens * prices.get('$model_name', 0)
print(f'{cost:.6f}')
" 2>/dev/null || echo "null")
        # Validate it's a number; fall back to null on parse failure
        if ! [[ "$estimated_cost_usd" =~ ^[0-9]+\.[0-9]+$ ]]; then
          estimated_cost_usd="null"
        fi
      fi
    fi

    # Build jq args for nullable string fields (model, precision)
    local model_json="null"
    local precision_json="null"
    [ -n "$model_name" ] && model_json="\"$model_name\""
    [ -n "$model_name" ] && [ "$estimated_cost_usd" != "null" ] && precision_json='"estimated"'

    jq -n -c \
      --arg slug "$slug" \
      --arg phase "$phase" \
      --argjson prev "$prev_json" \
      --arg entered "$entered" \
      --arg logged "$now" \
      --argjson elapsed "$elapsed" \
      --argjson artifact_bytes "$artifact_bytes" \
      --argjson estimated_tokens "$estimated_tokens" \
      --argjson model "$model_json" \
      --argjson estimated_cost_usd "$estimated_cost_usd" \
      --argjson precision "$precision_json" \
      --arg project "$project_name" \
      '{
        slug: $slug,
        phase: $phase,
        prev_phase: $prev,
        entered_at: $entered,
        logged_at: $logged,
        elapsed_prev_ms: $elapsed,
        artifact_bytes: $artifact_bytes,
        estimated_tokens: $estimated_tokens,
        model: $model,
        estimated_cost_usd: $estimated_cost_usd,
        precision: $precision,
        project: $project
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
    telemetry_sync "$wf" "$root"
  done < <(find "$root/features" -name "workflow.json" 2>/dev/null)
}

# Print a per-feature summary table with token/cost estimates.
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

print(f"{'Feature':<28} {'Phases':<48} {'Total(s)':>9}  {'Est.tokens':>10}  {'Est.cost':>9}  {'Est.total(×7)':>13}")
print('-' * 125)

total_cost_all = 0.0
total_tokens_all = 0

for slug, rs in sorted(by_slug.items()):
    rs_sorted = sorted(rs, key=lambda r: r['entered_at'])
    phases = ' → '.join(r['phase'] for r in rs_sorted)
    if len(phases) > 47:
        phases = phases[:44] + '...'
    elapsed_ms = sum((r.get('elapsed_prev_ms') or 0) for r in rs_sorted if r.get('elapsed_prev_ms'))
    elapsed_s = int(elapsed_ms / 1000) if elapsed_ms else 0

    tokens = sum((r.get('estimated_tokens') or 0) for r in rs_sorted)
    cost_vals = [r['estimated_cost_usd'] for r in rs_sorted if r.get('estimated_cost_usd') is not None]
    cost = sum(cost_vals) if cost_vals else None

    cost_str = f"\${cost:.4f}" if cost is not None else "-"
    tokens_str = f"~{tokens:,}" if tokens else "-"
    rough_total = cost * 7 if cost is not None else None
    rough_str = f"~\${rough_total:.2f}" if rough_total is not None else "-"

    if cost is not None:
        total_cost_all += cost
    total_tokens_all += tokens

    print(f"{slug:<28} {phases:<48} {elapsed_s:>9}  {tokens_str:>10}  {cost_str:>9}  {rough_str:>13}")

print()
rough_grand = total_cost_all * 7
print(f"{'TOTAL':<28} {'':<48} {'':>9}  {('~'+f'{total_tokens_all:,}'):>10}  \${total_cost_all:.4f}  {'~$'+f'{rough_grand:.2f}':>13}")
print()
print(f"Total features tracked: {len(by_slug)}")
print(f"Source: {path}")
print(f"Note: estimates based on artifact output size (+-30%). Output tokens only (~15% of actual); Est.total(×7) ≈ rough full cost.")
PY
}
