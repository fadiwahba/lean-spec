#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"

build_json() {
  local message="$1"
  /usr/bin/python3 - "$message" <<'PY'
import json, sys
print(json.dumps({
    "decision": "allow",
    "continue": True,
    "systemMessage": sys.argv[1],
    "suppressOutput": False
}))
PY
}

TOOL_NAME="$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
print(data.get("tool_name", ""))
')"

PROMPT_TEXT="$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
print(data.get("prompt", ""))
')"

PROMPT_LOWER="$(printf '%s' "$PROMPT_TEXT" | tr '[:upper:]' '[:lower:]')"

FILE_PATH="$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
tool_input = data.get("tool_input", {})
if isinstance(tool_input, dict):
    for key in ("file_path", "path"):
        value = tool_input.get(key)
        if isinstance(value, str):
            print(value)
            raise SystemExit(0)
print("")
')"

if [ -n "$FILE_PATH" ]; then
  case "$FILE_PATH" in
    */lean-spec/features/*/spec.md)
      if printf '%s' "$PROMPT_LOWER" | grep -q '/lean-spec:implement'; then
        /usr/bin/python3 - <<'PY'
import json
print(json.dumps({
    "decision": "deny",
    "reason": "Lean-spec guard: /lean-spec:implement must not edit spec.md. The Coder role may update notes.md and implementation code only."
}))
PY
        exit 0
      fi
      build_json "Lean-spec reminder: spec.md is owned by the Architect role in a Gemini Pro session. Before editing it, make sure this is the intended Pro session."
      exit 0
      ;;
    */lean-spec/features/*/review.md)
      if printf '%s' "$PROMPT_LOWER" | grep -q '/lean-spec:implement'; then
        /usr/bin/python3 - <<'PY'
import json
print(json.dumps({
    "decision": "deny",
    "reason": "Lean-spec guard: /lean-spec:implement must not edit review.md. The Coder role may update notes.md and implementation code only."
}))
PY
        exit 0
      fi
      build_json "Lean-spec reminder: review.md is owned by the Architect role in a Gemini Pro session. Before editing it, make sure this is the intended Pro session."
      exit 0
      ;;
    */lean-spec/features/*/notes.md)
      build_json "Lean-spec reminder: notes.md is owned by the Coder role in a Gemini Flash session. Before editing it, make sure this is the intended Flash session."
      exit 0
      ;;
  esac
fi

if [ "$TOOL_NAME" = "run_shell_command" ]; then
  COMMAND_TEXT="$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
tool_input = data.get("tool_input", {})
if isinstance(tool_input, dict):
    for key in ("command", "cmd"):
        value = tool_input.get(key)
        if isinstance(value, str):
            print(value)
            raise SystemExit(0)
print("")
')"

  if printf '%s' "$COMMAND_TEXT" | grep -qE 'rm -rf .*lean-spec/features/.*/(spec|notes|review)\.md'; then
    /usr/bin/python3 - <<'PY'
import json
print(json.dumps({
    "decision": "deny",
    "reason": "Lean-spec guard: do not delete canonical feature artifacts with shell commands."
}))
PY
    exit 0
  fi
fi

exit 0
