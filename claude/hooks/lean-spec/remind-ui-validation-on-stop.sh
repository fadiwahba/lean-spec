#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"

TEXT="$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)

parts = []
for key in ("task", "summary", "message", "prompt"):
    value = data.get(key)
    if isinstance(value, str):
        parts.append(value)

print("\n".join(parts))
')"

LOWER="$(printf '%s' "$TEXT" | tr '[:upper:]' '[:lower:]')"

if printf '%s' "$LOWER" | grep -qE 'frontend|ui|playwright|tailwind|css|layout|design|component|responsive|visual|shadcn'; then
  /usr/bin/python3 - <<'PY'
import json
print(json.dumps({
    "continue": True,
    "suppressOutput": False,
    "systemMessage": (
        "Lean-spec optional stop reminder: this task appears UI-related. "
        "Before concluding the turn, make sure rendered validation was considered. "
        "Use Playwright or equivalent browser validation when available, and treat visible regressions, broken layout, or mismatch with the spec as real review issues."
    )
}))
PY
else
  /usr/bin/python3 - <<'PY'
import json
print(json.dumps({
    "continue": True,
    "suppressOutput": True
}))
PY
fi
