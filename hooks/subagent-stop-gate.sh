#!/usr/bin/env bash
# SubagentStop hook: the moment an agent finishes, validate the artifact its
# phase requires. Backstops the phase-gate check that skills also run via
# bin/lean-spec, per CONSTITUTION principle 4 (validation runs at
# SubagentStop early, and at the phase gate as a backstop).
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LEAN_SPEC="${PLUGIN_ROOT}/bin/lean-spec"

# Active feature is resolved from on-disk state; the payload is only
# consulted for stop_hook_active: an invalid artifact is blocked once (one
# retry for the agent), and a continuation that still fails passes through —
# the phase gate is the backstop (CONSTITUTION principle 4). Without this,
# an agent that can never satisfy validation would be re-blocked forever.
payload="$(cat || true)"
# NOTE: pass payload on stdin, not argv — the SubagentStop payload can be
# arbitrarily large (transcript-derived fields), and Linux caps a single
# argv string at roughly 128KB (MAX_ARG_STRLEN). A large payload passed as
# an argument makes python3 abort with Argument list too long, which under
# set -euo pipefail kills this hook (fails OPEN). Stdin has no such limit.
stop_hook_active="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read())
except (json.JSONDecodeError, ValueError):
    data = {}
print("true" if data.get("stop_hook_active") else "false")
')"
if [ "$stop_hook_active" = "true" ]; then
  exit 0
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

resolved="$(python3 - "$PROJECT_ROOT" <<'PYEOF'
import json
import os
import sys

root = sys.argv[1]
auto_path = os.path.join(root, ".lean-spec", "auto.json")
slug = None

if os.path.isfile(auto_path):
    try:
        with open(auto_path) as f:
            slug = json.load(f).get("slug")
    except (json.JSONDecodeError, OSError):
        slug = None

features_root = os.path.join(root, "features")
if slug is None and os.path.isdir(features_root):
    best = None
    best_mtime = -1
    for name in os.listdir(features_root):
        wf_path = os.path.join(features_root, name, "workflow.json")
        if os.path.isfile(wf_path):
            mtime = os.path.getmtime(wf_path)
            if mtime > best_mtime:
                best_mtime = mtime
                best = name
    slug = best

if slug is None:
    print("__none__ __none__")
    sys.exit(0)

wf_path = os.path.join(features_root, slug, "workflow.json")
try:
    with open(wf_path) as f:
        phase = json.load(f).get("phase", "__none__")
except (json.JSONDecodeError, OSError):
    phase = "__none__"

print(f"{slug} {phase}")
PYEOF
)"
read -r slug phase <<< "$resolved"

if [ "$slug" = "__none__" ] || [ -z "$slug" ]; then
  exit 0
fi

case "$phase" in
  specifying) artifact="spec.md" ;;
  implementing) artifact="notes.md" ;;
  reviewing) artifact="review.md" ;;
  *) exit 0 ;;
esac

set +e
validator_output="$(cd "$PROJECT_ROOT" && "$LEAN_SPEC" validate "$slug" "$artifact" 2>&1)"
status=$?
set -e

if [ "$status" -ne 0 ]; then
  # Same stdin-not-argv fix as above: the validator output is bounded in
  # practice but is not exempt from the argv limit, so route it the same way.
  printf '%s' "$validator_output" | python3 -c '
import json
import sys

print(json.dumps({"decision": "block", "reason": sys.stdin.read()}))
'
fi

exit 0
