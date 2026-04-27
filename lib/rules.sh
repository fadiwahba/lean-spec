#!/usr/bin/env bash
#
# lib/rules.sh — load and enforce .lean-spec/rules.yaml constraints.
#
# Sourced by hooks (user-prompt-submit.sh) before phase-advancing commands.
#
# Rules file format (all fields optional):
#
#   required_sections:
#     spec.md:   ["Scope", "Acceptance Criteria", "Out of Scope"]
#     notes.md:  ["What was built", "How to verify"]
#     review.md: ["Verdict", "Spec Compliance", "Code Quality"]
#
#   max_tokens:
#     spec.md:  2000      # approximated as chars / 4
#     notes.md: 5000
#
#   required_verdict: APPROVE       # for close-spec to succeed
#
#   require_line_references:
#     review.md: true               # findings must cite backtick-quoted `path:NNN`
#
# Exit conventions: functions that validate return 0 on pass, 1 on violation
# (printing a human-readable message to stderr). `rules_enforce` aggregates.
#
# Dependencies: python3 + PyYAML (auto-installed via `uv run --with pyyaml` when uv is available;
#               falls back to bare python3 which requires PyYAML in the active environment), jq, awk, grep, wc.

# Path to rules.yaml relative to the project root (CWD when hook runs).
# Override with LEAN_SPEC_RULES_PATH for tests.
rules_path() {
  echo "${LEAN_SPEC_RULES_PATH:-.lean-spec/rules.yaml}"
}

# True if a rules file exists in the project.
rules_exist() {
  [ -f "$(rules_path)" ]
}

# Parse rules.yaml and emit its JSON representation on stdout.
# Emits "{}" if the file is missing (caller checks rules_exist first for clarity,
# but this is safe either way).
rules_load() {
  local path
  path="$(rules_path)"
  if [ ! -f "$path" ]; then
    echo "{}"
    return 0
  fi
  # Use uv to auto-install pyyaml when available (portable across fresh sandboxes).
  # Fall back to bare python3 for environments where PyYAML is pre-installed.
  local py_script='import sys, yaml, json
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f) or {}
print(json.dumps(d))'
  if command -v uv >/dev/null 2>&1; then
    uv run --quiet --with pyyaml python3 -c "$py_script" "$path"
  else
    python3 -c "$py_script" "$path"
  fi
}

# -----------------------------------------------------------------------------
# Individual validators (return 0 on pass, 1 on violation).
# All take: $1 = rules_json, $2 = artifact_type (e.g. "spec.md"), $3 = artifact_path.
# -----------------------------------------------------------------------------

# Required sections — a section is "present" if there's a markdown heading
# (any level) whose text contains the section name (case-insensitive substring).
validate_required_sections() {
  local rules_json="$1" artifact_type="$2" artifact_path="$3"
  local sections
  sections=$(echo "$rules_json" | jq -r ".required_sections[\"$artifact_type\"][]? // empty")
  [ -z "$sections" ] && return 0
  [ -f "$artifact_path" ] || {
    echo "rules violation: $artifact_type not found at $artifact_path" >&2
    return 1
  }
  local missing=()
  while IFS= read -r section; do
    [ -z "$section" ] && continue
    if ! grep -qiE "^#+[[:space:]].*$section" "$artifact_path"; then
      missing+=("$section")
    fi
  done <<< "$sections"
  if [ ${#missing[@]} -gt 0 ]; then
    echo "rules violation: $artifact_type missing required section(s): ${missing[*]}" >&2
    return 1
  fi
  return 0
}

# Max tokens — approximated as character count / 4 (a common rule of thumb).
validate_max_tokens() {
  local rules_json="$1" artifact_type="$2" artifact_path="$3"
  local max
  max=$(echo "$rules_json" | jq -r ".max_tokens[\"$artifact_type\"] // empty")
  [ -z "$max" ] && return 0
  [ -f "$artifact_path" ] || return 0  # missing file handled elsewhere
  local chars tokens
  chars=$(wc -c < "$artifact_path" | tr -d ' ')
  tokens=$((chars / 4))
  if [ "$tokens" -gt "$max" ]; then
    echo "rules violation: $artifact_type is ~$tokens tokens, exceeds max_tokens.$artifact_type=$max" >&2
    return 1
  fi
  return 0
}

# Required verdict — only checked for review.md (argument name kept generic for uniformity).
validate_verdict() {
  local rules_json="$1" artifact_type="$2" artifact_path="$3"
  # Only applies to review.md
  [ "$artifact_type" = "review.md" ] || return 0
  local required
  required=$(echo "$rules_json" | jq -r '.required_verdict // empty')
  [ -z "$required" ] && return 0
  [ -f "$artifact_path" ] || return 0
  local actual
  actual=$(awk '/^verdict:/ { gsub(/[[:space:]]/, "", $0); sub(/^verdict:/, "", $0); print; exit }' "$artifact_path")
  if [ "$actual" != "$required" ]; then
    echo "rules violation: review.md verdict='$actual' but required_verdict='$required'" >&2
    return 1
  fi
  return 0
}

# Line-references — heuristic: the file must contain at least one `path:NNN`
# pattern inside backticks. A stricter rule could scan per finding, but this
# catches "no refs at all" which is the common drift vector.
validate_line_references() {
  local rules_json="$1" artifact_type="$2" artifact_path="$3"
  local required
  required=$(echo "$rules_json" | jq -r ".require_line_references[\"$artifact_type\"] // false")
  [ "$required" != "true" ] && return 0
  [ -f "$artifact_path" ] || return 0
  if ! grep -qE '`[^`]+:[0-9]+' "$artifact_path"; then
    echo "rules violation: $artifact_type lacks any \`file:line\` references (require_line_references.$artifact_type=true)" >&2
    return 1
  fi
  return 0
}

# -----------------------------------------------------------------------------
# Aggregator
# -----------------------------------------------------------------------------

# rules_enforce <artifact_type> <artifact_path>
# Loads rules from $(rules_path) and runs all validators.
# Returns 0 if rules don't exist OR all validators pass.
# Returns 1 and prints messages to stderr if any violation is found.
rules_enforce() {
  local artifact_type="$1" artifact_path="$2"
  if ! rules_exist; then
    return 0
  fi
  local rules_json
  rules_json=$(rules_load) || {
    echo "rules violation: failed to parse $(rules_path)" >&2
    return 1
  }
  local failed=0
  validate_required_sections "$rules_json" "$artifact_type" "$artifact_path" || failed=1
  validate_max_tokens        "$rules_json" "$artifact_type" "$artifact_path" || failed=1
  validate_verdict           "$rules_json" "$artifact_type" "$artifact_path" || failed=1
  validate_line_references   "$rules_json" "$artifact_type" "$artifact_path" || failed=1
  return $failed
}
