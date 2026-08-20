#!/usr/bin/env bash
# Codex SubagentStop hook. Codex supplies agent_id/agent_type, not arbitrary
# caller metadata. The CLI binds that identity to prepared lean-spec work at
# SubagentStart, then this hook validates the recorded artifact.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LEAN_SPEC="${PLUGIN_ROOT}/bin/lean-spec"
payload="$(cat || true)"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

agent_id="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except (ValueError, json.JSONDecodeError):
    data = {}
print(data.get("agent_id", "") if isinstance(data, dict) else "")
')"
if [ -z "$agent_id" ]; then
  # Claude does not provide Codex's agent_id binding. Keep its established
  # payload/auto-state resolution path so the same canonical hook continues
  # to validate artifacts for both hosts.
  stop_hook_active="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read())
except (json.JSONDecodeError, ValueError):
    data = {}
print("true" if isinstance(data, dict) and data.get("stop_hook_active") else "false")
')"
  [ "$stop_hook_active" = "true" ] && exit 0
  payload_slug="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read())
except (json.JSONDecodeError, ValueError):
    data = {}
lean_spec = data.get("lean_spec") if isinstance(data, dict) else {}
slug = lean_spec.get("slug") if isinstance(lean_spec, dict) else ""
print(slug if isinstance(slug, str) else "")
')"
  resolved="$(python3 - "$PROJECT_ROOT" "$payload_slug" <<'PYEOF'
import json
import os
import sys

root, slug = sys.argv[1:]
if not slug:
    try:
        with open(os.path.join(root, ".lean-spec", "auto.json")) as f:
            auto = json.load(f)
        slug = auto.get("slug") if isinstance(auto, dict) else None
    except (OSError, json.JSONDecodeError):
        slug = None
if not isinstance(slug, str) or not slug:
    print("__none__ __none__")
    raise SystemExit(0)
try:
    with open(os.path.join(root, ".lean-spec", "features", slug, "workflow.json")) as f:
        workflow = json.load(f)
    phase = workflow.get("phase") if isinstance(workflow, dict) else None
except (OSError, json.JSONDecodeError):
    phase = None
artifact = {"specifying": "spec.md", "implementing": "notes.md", "reviewing": "review.md"}.get(phase)
print(f"{slug} {artifact or '__none__'}")
PYEOF
)"
  read -r slug artifact <<< "$resolved"
  [ "$slug" = "__none__" ] || [ "$artifact" = "__none__" ] || [ -z "$slug" ] && exit 0
  set +e
  validator_output="$(cd "$PROJECT_ROOT" && "$LEAN_SPEC" validate "$slug" "$artifact" 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    printf '%s' "$validator_output" | python3 -c '
import json, sys
print(json.dumps({"decision": "block", "reason": sys.stdin.read()}))
'
  fi
  exit 0
fi

set +e
identity="$(cd "$PROJECT_ROOT" && "$LEAN_SPEC" dispatch resolve "$agent_id" 2>/dev/null)"
status=$?
set -e
[ "$status" -eq 0 ] || exit 0

read -r slug artifact <<< "$(printf '%s' "$identity" | python3 -c '
import json, sys
data = json.load(sys.stdin)
print(data["slug"], data["artifact"])
')"

set +e
validator_output="$(cd "$PROJECT_ROOT" && "$LEAN_SPEC" validate "$slug" "$artifact" 2>&1)"
status=$?
set -e
if [ "$status" -ne 0 ]; then
  printf '%s' "$validator_output" | python3 -c '
import json, sys
print(json.dumps({"decision": "block", "reason": sys.stdin.read()}))
'
  exit 0
fi

cd "$PROJECT_ROOT" && "$LEAN_SPEC" dispatch complete "$agent_id"
