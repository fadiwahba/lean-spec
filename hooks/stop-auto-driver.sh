#!/usr/bin/env bash
# Stop hook adapter. The CLI owns every read-modify-write of auto.json; this
# file only turns a host stop event into an explicit, duplicate-safe tick.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LEAN_SPEC="${PLUGIN_ROOT}/bin/lean-spec"
payload="$(cat || true)"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

status_json="$(cd "$PROJECT_ROOT" && "$LEAN_SPEC" auto status --json 2>/dev/null || true)"
run_id="$(printf '%s' "$status_json" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
print(data.get("run_id", "") if isinstance(data, dict) and data.get("armed") else "")
')"
[ -n "$run_id" ] || exit 0

event_id="$(printf '%s\n%s\n%s' "$run_id" "$(printf '%s' "$status_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cycles", 0))')" "$payload" | python3 -c '
import hashlib, sys
print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())
')"
result="$(cd "$PROJECT_ROOT" && "$LEAN_SPEC" auto tick --run-id "$run_id" --event-id "$event_id" --json 2>/dev/null || true)"

reason="$(printf '%s' "$result" | python3 -c '
import json, sys
root = sys.argv[1]
try:
    result = json.load(sys.stdin)
except Exception:
    result = {}
if result.get("outcome") != "READY":
    sys.exit(0)
step = result.get("next_step")
slug = result.get("slug", "")
if step == "spec":
    print(f"lean-spec auto-all: read {root}/skills/spec/SKILL.md now and perform its no-confirm steps. Stop safely with NEEDS_INPUT if a required decision is missing.")
elif isinstance(step, str) and step:
    print(f"lean-spec auto: read {root}/skills/{step}/SKILL.md now and perform its steps for {slug!r}.")
' "$PLUGIN_ROOT")"

if [ -n "$reason" ]; then
  python3 -c 'import json, sys; print(json.dumps({"decision": "block", "reason": sys.stdin.read()}))' <<< "$reason"
fi
