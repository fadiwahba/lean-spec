#!/usr/bin/env bash
# Bind Codex's documented SubagentStart identity to the CLI-prepared work item.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LEAN_SPEC="${PLUGIN_ROOT}/bin/lean-spec"
payload="$(cat || true)"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

read -r agent_id agent_type <<< "$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except (ValueError, json.JSONDecodeError):
    data = {}
if isinstance(data, dict):
    print(data.get("agent_id", ""), data.get("agent_type", ""))
')"
[ -n "$agent_id" ] && [ -n "$agent_type" ] || exit 0
cd "$PROJECT_ROOT" && "$LEAN_SPEC" dispatch bind "$agent_id" "$agent_type"
