#!/usr/bin/env bash
# lib/workflow.sh — workflow.json read/write helpers for lean-spec v3
# Source with: source lib/workflow.sh
# Requires: bash, jq

# Legal phase transitions map: "from:to" pairs that are allowed
_LEGAL_TRANSITIONS=(
  "specifying:implementing"
  "implementing:reviewing"
  "reviewing:implementing"
  "reviewing:closed"
)

# validate_transition <current_phase> <target_phase>
# Exit 0 if legal, exit 1 if illegal (prints reason to stderr).
validate_transition() {
  local current="$1"
  local target="$2"

  if [[ -z "$current" || -z "$target" ]]; then
    echo "validate_transition: missing arguments" >&2
    return 1
  fi

  # closed is a terminal state — nothing can leave it
  if [[ "$current" == "closed" ]]; then
    echo "validate_transition: 'closed' is a terminal state — no transitions allowed" >&2
    return 1
  fi

  local pair="${current}:${target}"
  for legal in "${_LEGAL_TRANSITIONS[@]}"; do
    if [[ "$pair" == "$legal" ]]; then
      return 0
    fi
  done

  echo "validate_transition: illegal transition '${current}' → '${target}'" >&2
  return 1
}

# read_phase <workflow_json_path>
# Outputs the current phase string to stdout.
# Exit 1 if file not found or not valid JSON.
read_phase() {
  local path="$1"

  if [[ -z "$path" ]]; then
    echo "read_phase: path argument required" >&2
    return 1
  fi

  if [[ ! -f "$path" ]]; then
    echo "read_phase: file not found: $path" >&2
    return 1
  fi

  local phase
  phase=$(jq -e -r '.phase' "$path" 2>/dev/null)
  local jq_exit=$?

  if [[ $jq_exit -ne 0 ]]; then
    echo "read_phase: invalid JSON or missing .phase in: $path" >&2
    return 1
  fi

  echo "$phase"
}

# append_history <workflow_json_path> <phase>
# Appends { "phase": "<phase>", "entered_at": "<ISO8601 now>" } to history array.
# Can be called standalone; set_phase calls it internally.
# Exit 1 if file not found or not valid JSON.
append_history() {
  local path="$1"
  local phase="$2"

  if [[ -z "$path" || -z "$phase" ]]; then
    echo "append_history: path and phase arguments required" >&2
    return 1
  fi

  if [[ ! -f "$path" ]]; then
    echo "append_history: file not found: $path" >&2
    return 1
  fi

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmp
  tmp=$(mktemp "${path}.tmp.XXXXXX")

  jq --arg phase "$phase" --arg now "$now" \
    '.history += [{"phase": $phase, "entered_at": $now}]' \
    "$path" > "$tmp" 2>/dev/null

  if [[ $? -ne 0 ]]; then
    rm -f "$tmp"
    echo "append_history: jq failed to parse: $path" >&2
    return 1
  fi

  if ! jq empty "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    echo "workflow: jq produced invalid JSON output" >&2
    return 1
  fi

  mv -f "$tmp" "$path"
}

# set_phase <workflow_json_path> <new_phase>
# Validates transition, writes new phase, updates updated_at, appends history entry.
# Writes atomically via temp file + mv.
# Exit 0 on success, exit 1 on illegal transition or file errors.
set_phase() {
  local path="$1"
  local new_phase="$2"

  if [[ -z "$path" || -z "$new_phase" ]]; then
    echo "set_phase: path and new_phase arguments required" >&2
    return 1
  fi

  if [[ ! -f "$path" ]]; then
    echo "set_phase: file not found: $path" >&2
    return 1
  fi

  local current_phase
  current_phase=$(read_phase "$path") || return 1

  validate_transition "$current_phase" "$new_phase" || return 1

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmp
  tmp=$(mktemp "${path}.tmp.XXXXXX")

  jq --arg phase "$new_phase" --arg now "$now" \
    '.phase = $phase | .updated_at = $now | .history += [{"phase": $phase, "entered_at": $now}]' \
    "$path" > "$tmp" 2>/dev/null

  if [[ $? -ne 0 ]]; then
    rm -f "$tmp"
    echo "set_phase: jq failed to parse: $path" >&2
    return 1
  fi

  if ! jq empty "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    echo "workflow: jq produced invalid JSON output" >&2
    return 1
  fi

  mv -f "$tmp" "$path"
}
