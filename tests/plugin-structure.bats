#!/usr/bin/env bats
#
# plugin-structure.bats — validate shape of plugin artifacts.
#
# These tests are static-only: they verify that plugin.json, agent/command/
# skill frontmatter, and hook scripts are well-formed. They don't dispatch
# subagents or run claude -- those are tested via live experiments.
#
# Requires: bats, jq, python3 (PyYAML), bash.

setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# ---------- helpers ----------

# Extract the YAML frontmatter (between the first two `---` lines) of a file.
extract_frontmatter() {
  awk 'BEGIN{c=0} /^---$/ { c++; if(c==2) exit; next } c==1 { print }' "$1"
}

# Read a top-level YAML field from a markdown file's frontmatter.
# Prints empty string and exits non-zero if the field is missing or file has no frontmatter.
yaml_field() {
  local file="$1" field="$2"
  extract_frontmatter "$file" | python3 -c "
import sys, yaml
try:
    d = yaml.safe_load(sys.stdin) or {}
except Exception as e:
    sys.stderr.write(f'yaml parse error: {e}\n'); sys.exit(2)
v = d.get('$field')
if v is None:
    sys.exit(1)
if isinstance(v, (list, dict)):
    import json; print(json.dumps(v))
else:
    print(v)
"
}

# ---------- plugin.json ----------

@test "plugin.json exists and is valid JSON" {
  [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]
  run jq . "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  [ "$status" -eq 0 ]
}

@test "plugin.json has required top-level fields" {
  local f="$PLUGIN_ROOT/.claude-plugin/plugin.json"
  for field in name version description author license; do
    run jq -r ".$field // \"\"" "$f"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
  done
}

@test "plugin.json name is 'lean-spec'" {
  run jq -r .name "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  [ "$output" = "lean-spec" ]
}

@test "plugin.json version is semver-like" {
  run jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]
}

# ---------- agents ----------

@test "all agents have frontmatter with required fields" {
  for agent in "$PLUGIN_ROOT"/agents/*.md; do
    [ -f "$agent" ] || continue
    for field in name description tools model color; do
      run yaml_field "$agent" "$field"
      [ "$status" -eq 0 ] || { echo "agent $agent missing field: $field"; false; }
      [ -n "$output" ] || { echo "agent $agent field '$field' is empty"; false; }
    done
  done
}

@test "agent name matches filename" {
  for agent in "$PLUGIN_ROOT"/agents/*.md; do
    [ -f "$agent" ] || continue
    expected="$(basename "$agent" .md)"
    run yaml_field "$agent" "name"
    [ "$output" = "$expected" ] || { echo "agent $agent name='$output' but filename implies '$expected'"; false; }
  done
}

@test "agent model is one of opus|sonnet|haiku|inherit" {
  for agent in "$PLUGIN_ROOT"/agents/*.md; do
    [ -f "$agent" ] || continue
    run yaml_field "$agent" "model"
    [[ "$output" =~ ^(opus|sonnet|haiku|inherit)$ ]] || { echo "agent $agent has invalid model: $output"; false; }
  done
}

@test "agent color is in the Claude Code runtime palette" {
  # Runtime palette as surfaced by the /agents UI
  for agent in "$PLUGIN_ROOT"/agents/*.md; do
    [ -f "$agent" ] || continue
    run yaml_field "$agent" "color"
    [[ "$output" =~ ^(red|blue|green|yellow|purple|orange|pink|cyan)$ ]] || { echo "agent $agent has invalid color: $output"; false; }
  done
}

@test "agent tools is a YAML list (array) — not a comma-separated string" {
  # Experiment A pointed out that comma-separated `tools: Read, Write, Bash`
  # produces "Unrecognized: Write" warnings at load. Must be a YAML array.
  for agent in "$PLUGIN_ROOT"/agents/*.md; do
    [ -f "$agent" ] || continue
    run yaml_field "$agent" "tools"
    [ "$status" -eq 0 ]
    # Output is JSON-encoded when the YAML value is a list
    [[ "$output" =~ ^\[.*\]$ ]] || { echo "agent $agent tools is not a list: $output"; false; }
  done
}

@test "canonical agent model pins are enforced" {
  # Post-experiment canonical defaults. If someone pushes a branch that flipped
  # these for testing, this test catches it before merge.
  run yaml_field "$PLUGIN_ROOT/agents/architect.md" "model"
  [ "$output" = "opus" ]
  run yaml_field "$PLUGIN_ROOT/agents/coder.md" "model"
  [ "$output" = "haiku" ]
  run yaml_field "$PLUGIN_ROOT/agents/reviewer.md" "model"
  [ "$output" = "sonnet" ]
}

# ---------- commands ----------

@test "all commands have frontmatter with required fields" {
  for cmd in "$PLUGIN_ROOT"/commands/*.md; do
    [ -f "$cmd" ] || continue
    for field in description argument-hint allowed-tools; do
      run yaml_field "$cmd" "$field"
      # argument-hint can be empty for commands that take no args
      if [ "$field" = "argument-hint" ]; then
        [ "$status" -le 1 ]
      else
        [ "$status" -eq 0 ] || { echo "command $cmd missing field: $field"; false; }
        [ -n "$output" ] || { echo "command $cmd field '$field' is empty"; false; }
      fi
    done
  done
}

@test "command allowed-tools includes Bash (all commands mutate workflow.json)" {
  # start-spec and close-spec delegate all filesystem mutation to the UserPromptSubmit
  # hook (hook-based architecture, v0.3.4+). They use Task/Read only — no Bash needed.
  local hook_delegated="start-spec.md close-spec.md"
  for cmd in "$PLUGIN_ROOT"/commands/*.md; do
    [ -f "$cmd" ] || continue
    base=$(basename "$cmd")
    [[ " $hook_delegated " == *" $base "* ]] && continue
    run yaml_field "$cmd" "allowed-tools"
    [[ "$output" == *"Bash"* ]] || { echo "command $cmd missing Bash: $output"; false; }
  done
}

@test "phase-mutating commands use the mv -f + post-advance assertion pattern" {
  # Lesson from the lean-spec-v3 session: mv without -f triggers the macOS rm -i
  # alias and silently fails. Commands that own their own workflow.json mutation must
  # use `mv -f`. close-spec is exempt — mutation moved to UserPromptSubmit hook (v0.3.4+).
  for cmd in submit-implementation.md submit-review.md submit-fixes.md; do
    f="$PLUGIN_ROOT/commands/$cmd"
    [ -f "$f" ] || continue
    grep -q "mv -f" "$f" || { echo "$cmd missing 'mv -f' in body"; false; }
  done
  # Verify hook carries the mv -f pattern for hook-delegated commands
  grep -q "mv -f" "$PLUGIN_ROOT/hooks/user-prompt-submit.sh" \
    || { echo "user-prompt-submit.sh missing 'mv -f' (hook-delegated mutation)"; false; }
}

# ---------- skills ----------

@test "all skills have SKILL.md with name + description frontmatter" {
  for skill_dir in "$PLUGIN_ROOT"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_file="$skill_dir/SKILL.md"
    [ -f "$skill_file" ] || { echo "missing SKILL.md in $skill_dir"; false; }
    for field in name description; do
      run yaml_field "$skill_file" "$field"
      [ "$status" -eq 0 ] || { echo "skill $skill_file missing field: $field"; false; }
      [ -n "$output" ] || { echo "skill $skill_file field '$field' is empty"; false; }
    done
  done
}

@test "writing-specs skill mandates V1/V2 numbered visual-checklist table" {
  # Regression test for experiment-B2 finding: without this rule, Sonnet architect
  # writes prose AC4 and the reviewer can't enforce visual tokens.
  f="$PLUGIN_ROOT/skills/writing-specs/SKILL.md"
  grep -q "numbered" "$f" || { echo "writing-specs missing 'numbered' keyword"; false; }
  grep -qE "V1|V2" "$f" || { echo "writing-specs missing V1/V2 example"; false; }
  grep -q "Visual Acceptance Criteria" "$f" || { echo "writing-specs missing 'Visual Acceptance Criteria' section"; false; }
}

# ---------- hooks ----------

@test "claude-hooks.json exists and is valid JSON" {
  [ -f "$PLUGIN_ROOT/hooks/claude-hooks.json" ]
  run jq . "$PLUGIN_ROOT/hooks/claude-hooks.json"
  [ "$status" -eq 0 ]
}

@test "every hook referenced in claude-hooks.json exists and is executable" {
  # Extract all referenced script paths and verify each exists as executable.
  run jq -r '.. | .command? // empty' "$PLUGIN_ROOT/hooks/claude-hooks.json"
  [ "$status" -eq 0 ]
  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    # Commands may be fully-qualified like "bash $CLAUDE_PLUGIN_ROOT/hooks/foo.sh".
    # Extract the .sh path.
    script=$(echo "$cmd" | grep -oE '[^ ]+\.sh' | head -1)
    [ -z "$script" ] && continue
    # Resolve both $CLAUDE_PLUGIN_ROOT and ${CLAUDE_PLUGIN_ROOT} forms for the test
    resolved="${script//\$\{CLAUDE_PLUGIN_ROOT\}/$PLUGIN_ROOT}"
    resolved="${resolved//\$CLAUDE_PLUGIN_ROOT/$PLUGIN_ROOT}"
    [ -f "$resolved" ] || { echo "hook script missing: $resolved"; false; }
    [ -x "$resolved" ] || { echo "hook script not executable: $resolved"; false; }
  done <<< "$output"
}

@test "all hook scripts pass bash -n syntax check" {
  for script in "$PLUGIN_ROOT"/hooks/*.sh; do
    [ -f "$script" ] || continue
    run bash -n "$script"
    [ "$status" -eq 0 ] || { echo "syntax error in $script"; false; }
  done
}

# ---------- agent-forbidden-edits rule (post-experiment #83) ----------

@test "coder.md enumerates hard-forbidden edits" {
  f="$PLUGIN_ROOT/agents/coder.md"
  grep -q "Hard-forbidden edits" "$f" || { echo "coder.md missing 'Hard-forbidden edits' section"; false; }
  grep -q "package.json" "$f" || { echo "coder.md forbidden list missing package.json"; false; }
  grep -q "lockfile" "$f" || { echo "coder.md forbidden list missing lockfile mention"; false; }
}

@test "reviewer.md has scope-violation sweep step" {
  f="$PLUGIN_ROOT/agents/reviewer.md"
  grep -q "Scope-violation sweep" "$f" || { echo "reviewer.md missing 'Scope-violation sweep'"; false; }
}

@test "reviewer.md archives prior review.md before writing" {
  f="$PLUGIN_ROOT/agents/reviewer.md"
  grep -q "review-cycle-" "$f" || { echo "reviewer.md missing review-cycle archiving"; false; }
}
