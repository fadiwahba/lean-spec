#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"

PROMPT="$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
print(data.get("prompt", ""))
')"

RESPONSE="$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
print(data.get("prompt_response", ""))
')"

TEXT="$(printf '%s\n%s' "$PROMPT" "$RESPONSE" | tr '[:upper:]' '[:lower:]')"
RESPONSE_LOWER="$(printf '%s' "$RESPONSE" | tr '[:upper:]' '[:lower:]')"
PROMPT_LOWER="$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')"

if ! printf '%s' "$PROMPT_LOWER" | grep -q '/lean-spec:'; then
  exit 0
fi

if printf '%s' "$PROMPT_LOWER" | grep -q '/lean-spec:close-spec'; then
  if printf '%s' "$TEXT" | grep -qE 'ready to close|feature is complete|workflow is complete|closure complete|close cleanly'; then
    /usr/bin/python3 - <<'PY'
import json
print(json.dumps({
    "decision": "deny",
    "reason": "Lean-spec validation: do not claim completion or readiness to close unless review findings and notes are already clean and spec.md is reconciled.",
    "systemMessage": "lean-spec final-response validation requested a correction pass."
}))
PY
    exit 0
  fi
fi

if printf '%s' "$PROMPT_LOWER" | grep -q '/lean-spec:spec-status\|/lean-spec:resume-spec\|/lean-spec:start-spec\|/lean-spec:update-spec'; then
  exit 0
fi

if printf '%s' "$TEXT" | grep -qE 'ready to close|feature is complete|workflow is complete|closure complete'; then
  /usr/bin/python3 - <<'PY'
import json
print(json.dumps({
    "decision": "deny",
    "reason": "Lean-spec validation: do not claim completion or readiness to close unless review findings and notes are already clean and spec.md is reconciled.",
    "systemMessage": "lean-spec final-response validation requested a correction pass."
}))
PY
  exit 0
fi

require_tool_report() {
  local tool_name="$1"
  local message="$2"
  if ! printf '%s' "$RESPONSE_LOWER" | grep -q "$tool_name"; then
    /usr/bin/python3 - "$message" <<'PY'
import json, sys
print(json.dumps({
    "decision": "deny",
    "reason": sys.argv[1],
    "systemMessage": "lean-spec final-response validation requested a correction pass."
}))
PY
    exit 0
  fi
}

if printf '%s' "$PROMPT_LOWER" | grep -q '/lean-spec:implement-spec'; then
  if printf '%s' "$RESPONSE_LOWER" | grep -qE 'implementation complete|implemented|ready for review'; then
    require_tool_report "context7" "Lean-spec validation: implementation reports must explicitly say whether context7 was used when relevant, or that it was unavailable."
    require_tool_report "sequential" "Lean-spec validation: implementation reports must explicitly say whether sequential_thinking was used when relevant, or that it was unavailable."
    require_tool_report "playwright" "Lean-spec validation: frontend implementation reports must explicitly say whether playwright was used when relevant, or that it was unavailable."
  fi
fi

if printf '%s' "$PROMPT_LOWER" | grep -q '/lean-spec:review-spec'; then
  if printf '%s' "$RESPONSE_LOWER" | grep -qE 'review complete|review is complete|ready to close|no findings'; then
    require_tool_report "context7" "Lean-spec validation: review reports must explicitly say whether context7 was used when relevant, or that it was unavailable."
    require_tool_report "sequential" "Lean-spec validation: review reports must explicitly say whether sequential_thinking was used when relevant, or that it was unavailable."
    require_tool_report "playwright" "Lean-spec validation: frontend review reports must explicitly say whether playwright was used when relevant, or that it was unavailable."
  fi
fi
