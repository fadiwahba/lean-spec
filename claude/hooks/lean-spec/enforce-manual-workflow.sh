#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"

build_json() {
  local message="$1"
  /usr/bin/python3 - "$message" <<'PY'
import json, sys
print(json.dumps({
    "continue": True,
    "suppressOutput": False,
    "systemMessage": sys.argv[1]
}))
PY
}

parse_field() {
  local field="$1"
  printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json, sys
field = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)

value = data.get(field, "")
if isinstance(value, str):
    print(value)
else:
    print("")
' "$field"
}

if [ "$TOOL_NAME" = "Agent" ]; then
  SUBAGENT_TYPE="$(parse_field subagent_type | tr '[:upper:]' '[:lower:]')"
  DESCRIPTION="$(parse_field description | tr '[:upper:]' '[:lower:]')"

  if printf '%s %s' "$SUBAGENT_TYPE" "$DESCRIPTION" | grep -qE 'code-reviewer|code reviewer|reviewer'; then
    build_json "Lean-spec reminder: formal review must use architect, not a generic reviewer agent. The orchestrator should route planning and review to architect, and implementation to coder."
    exit 0
  fi

  if [ -n "$SUBAGENT_TYPE" ] && ! printf '%s' "$SUBAGENT_TYPE" | grep -qE 'architect|coder'; then
    build_json "Lean-spec reminder: when delegating lean-spec work, use the named specialist agents only. architect owns planning and review. coder owns implementation and notes.md."
    exit 0
  fi

  exit 0
fi

FILE_PATH="$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)

for key in ("file_path", "path"):
    value = data.get(key)
    if isinstance(value, str):
        print(value)
        break
else:
    print("")
')"

[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  */lean-spec/features/*/spec.md)
    build_json "Lean-spec reminder: spec.md is owned by architect. If you are the orchestrator or coder, do not author or rewrite this file directly. During implementation, coder must not edit spec.md status, checklist items, or timestamps."
    ;;
  */lean-spec/features/*/review.md)
    build_json "Lean-spec reminder: review.md is owned by architect. If you are the orchestrator or coder, do not author review findings directly. During implementation, coder must not edit review.md. Delegate review work to architect."
    ;;
  */lean-spec/features/*/notes.md)
    build_json "Lean-spec reminder: notes.md is owned by coder. If you are the orchestrator or architect, do not author implementation notes directly. Delegate implementation and blocker logging to coder."
    ;;
  *)
    build_json "Lean-spec reminder: source code changes in lean-spec should be delegated by the orchestrator to coder. architect should not implement code. The default session agent should route and report, not code directly, when delegation is available."
    ;;
esac
