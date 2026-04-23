#!/usr/bin/env bats
#
# opencode-commands.bats — verify the OpenCode port shipping:
#   - .opencode/agents/*.md present with correct mode + model frontmatter
#   - .opencode/commands/lean-spec/*.md present with correct frontmatter
#   - 1:1 correspondence with the Claude commands (all 11 ports exist)
#   - INSTALL.md present with the subagent-works-here note

setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# Reuse yaml_field helper style.
extract_frontmatter() {
  awk 'BEGIN{c=0} /^---$/ { c++; if(c==2) exit; next } c==1 { print }' "$1"
}
yaml_field() {
  local file="$1" field="$2"
  extract_frontmatter "$file" | python3 -c "
import sys, yaml
try: d = yaml.safe_load(sys.stdin) or {}
except: sys.exit(2)
v = d.get('$field')
if v is None: sys.exit(1)
print(v if not isinstance(v,(list,dict)) else __import__('json').dumps(v))
"
}

# ---------- agent definitions ----------

@test "all 4 OpenCode agents exist" {
  for a in architect coder reviewer brainstormer; do
    [ -f "$PLUGIN_ROOT/.opencode/agents/$a.md" ] || { echo "missing .opencode/agents/$a.md"; false; }
  done
}

@test "every OpenCode agent has mode=subagent" {
  for a in "$PLUGIN_ROOT"/.opencode/agents/*.md; do
    run yaml_field "$a" "mode"
    [ "$output" = "subagent" ] || { echo "$a has mode=$output, expected subagent"; false; }
  done
}

@test "every OpenCode agent pins a provider/model identifier" {
  for a in "$PLUGIN_ROOT"/.opencode/agents/*.md; do
    run yaml_field "$a" "model"
    [ "$status" -eq 0 ]
    # model must be in provider/id format, not bare "opus"/"haiku"
    [[ "$output" == *"/"* ]] || { echo "$a model='$output' — expected provider/model-id format"; false; }
  done
}

@test "canonical OpenCode model pins match the Claude tier mapping" {
  # architect=opus, coder=haiku, reviewer=opus, brainstormer=opus (per spec)
  run yaml_field "$PLUGIN_ROOT/.opencode/agents/architect.md" "model"
  [[ "$output" == *"opus"* ]]
  run yaml_field "$PLUGIN_ROOT/.opencode/agents/reviewer.md" "model"
  [[ "$output" == *"opus"* ]]
  run yaml_field "$PLUGIN_ROOT/.opencode/agents/brainstormer.md" "model"
  [[ "$output" == *"opus"* ]]
  run yaml_field "$PLUGIN_ROOT/.opencode/agents/coder.md" "model"
  [[ "$output" == *"haiku"* ]]
}

# ---------- command files ----------

@test "every Claude command has an OpenCode sibling" {
  for md in "$PLUGIN_ROOT"/commands/*.md; do
    name=$(basename "$md" .md)
    [ -f "$PLUGIN_ROOT/.opencode/commands/lean-spec/$name.md" ] || {
      echo "missing .opencode/commands/lean-spec/$name.md"
      false
    }
  done
}

@test "every OpenCode command has description frontmatter" {
  for cmd in "$PLUGIN_ROOT"/.opencode/commands/lean-spec/*.md; do
    run yaml_field "$cmd" "description"
    [ "$status" -eq 0 ] && [ -n "$output" ] || {
      echo "$(basename "$cmd") missing description"
      false
    }
  done
}

@test "lifecycle OpenCode commands specify agent + subtask=true" {
  # start-spec, update-spec → architect
  # submit-implementation, submit-fixes → coder
  # submit-review → reviewer
  # brainstorm → brainstormer
  for cmd in start-spec update-spec submit-implementation submit-fixes submit-review brainstorm; do
    f="$PLUGIN_ROOT/.opencode/commands/lean-spec/$cmd.md"
    run yaml_field "$f" "agent"
    [ -n "$output" ] || { echo "$cmd missing agent frontmatter"; false; }
    run yaml_field "$f" "subtask"
    [ "$output" = "True" ] || [ "$output" = "true" ] || { echo "$cmd missing subtask=true"; false; }
  done
}

@test "every OpenCode command references \$ARGUMENTS" {
  for cmd in "$PLUGIN_ROOT"/.opencode/commands/lean-spec/*.md; do
    grep -q '\$ARGUMENTS' "$cmd" || {
      echo "$(basename "$cmd") missing \$ARGUMENTS placeholder"
      false
    }
  done
}

# ---------- INSTALL.md ----------

@test ".opencode/INSTALL.md exists and names subagent-mode parity" {
  f="$PLUGIN_ROOT/.opencode/INSTALL.md"
  [ -f "$f" ]
  grep -qi "subagent" "$f"
  grep -qi "model" "$f"
}

@test ".opencode/INSTALL.md documents the symlink install flow" {
  f="$PLUGIN_ROOT/.opencode/INSTALL.md"
  grep -q "ln -s" "$f"
  grep -q "\.config/opencode" "$f"
}
