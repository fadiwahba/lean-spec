#!/usr/bin/env bash
# Stop hook adapter. The CLI owns every read-modify-write of auto.json; this
# file only turns a host stop event into an explicit, duplicate-safe tick.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LEAN_SPEC="${PLUGIN_ROOT}/bin/lean-spec"
payload="$(cat || true)"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -d "$PROJECT_ROOT/.agents/skills/lean-spec-spec" ]; then
  SKILL_PATH_FORMAT="$PROJECT_ROOT/.agents/skills/lean-spec-{step}/SKILL.md"
else
  SKILL_PATH_FORMAT="$PLUGIN_ROOT/skills/{step}/SKILL.md"
fi

status_json="$(cd "$PROJECT_ROOT" && "$LEAN_SPEC" auto status --json)"
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
result="$(cd "$PROJECT_ROOT" && "$LEAN_SPEC" auto tick --run-id "$run_id" --event-id "$event_id" --json)"

reason="$(printf '%s' "$result" | python3 -c '
import json, sys
skill_path_format, lean_spec = sys.argv[1:]
try:
    result = json.load(sys.stdin)
except Exception:
    result = {}
if result.get("outcome") != "READY":
    sys.exit(0)
step = result.get("next_step")
slug = result.get("slug", "")
if step == "spec":
    run_id = result.get("run_id", "")
    print(f"lean-spec auto-all: read {skill_path_format.format(step=step)} now and perform its no-confirm steps. Stop safely with NEEDS_INPUT if a required decision is missing. Only if the architect returns exactly NO_REMAINING_SCOPE, run `{lean_spec} auto complete --run-id {run_id} --no-remaining-scope` and stop. If the output is malformed, stop and ask one targeted question; never run auto complete.")
elif isinstance(step, str) and step:
    print(f"lean-spec auto: read {skill_path_format.format(step=step)} now and perform its steps for {slug!r}.")
' "$SKILL_PATH_FORMAT" "$LEAN_SPEC")"

if [ -n "$reason" ]; then
  python3 -c 'import json, sys; print(json.dumps({"decision": "block", "reason": sys.stdin.read()}))' <<< "$reason"
fi
