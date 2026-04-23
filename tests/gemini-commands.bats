#!/usr/bin/env bats
#
# gemini-commands.bats — verify the Gemini CLI extension surface:
#   - gemini-extension.json is valid + has required fields
#   - GEMINI.md context file exists and references lean-spec
#   - Every Claude commands/*.md has a matching commands/lean-spec/*.toml
#   - Every TOML has description + prompt fields
#   - scripts/verify-gemini-commands.sh passes
#
# Requires: bats, jq, python3 (tomllib — stdlib >=3.11).

setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# ---------- manifest ----------

@test "gemini-extension.json exists and is valid JSON" {
  [ -f "$PLUGIN_ROOT/gemini-extension.json" ]
  run jq . "$PLUGIN_ROOT/gemini-extension.json"
  [ "$status" -eq 0 ]
}

@test "gemini-extension.json has required fields (name, version, description)" {
  f="$PLUGIN_ROOT/gemini-extension.json"
  run jq -r '.name' "$f"; [ "$output" = "lean-spec" ]
  run jq -r '.version' "$f"; [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]
  run jq -r '.description' "$f"; [ -n "$output" ]
}

@test "gemini-extension.json contextFileName points at GEMINI.md (which exists)" {
  f="$PLUGIN_ROOT/gemini-extension.json"
  run jq -r '.contextFileName // ""' "$f"
  [ "$output" = "GEMINI.md" ]
  [ -f "$PLUGIN_ROOT/GEMINI.md" ]
}

@test "GEMINI.md names the degraded-mode caveat (no subagent dispatch)" {
  f="$PLUGIN_ROOT/GEMINI.md"
  grep -qi "no subagent dispatch" "$f" || grep -qi "degraded mode" "$f"
}

# ---------- command 1:1 ----------

@test "every Claude command has a Gemini TOML sibling" {
  for md in "$PLUGIN_ROOT"/commands/*.md; do
    name=$(basename "$md" .md)
    [ -f "$PLUGIN_ROOT/commands/lean-spec/$name.toml" ] || {
      echo "missing commands/lean-spec/$name.toml"
      false
    }
  done
}

@test "every Gemini TOML has a Claude MD sibling" {
  for toml in "$PLUGIN_ROOT"/commands/lean-spec/*.toml; do
    name=$(basename "$toml" .toml)
    [ -f "$PLUGIN_ROOT/commands/$name.md" ] || {
      echo "orphan commands/lean-spec/$name.toml"
      false
    }
  done
}

@test "every Gemini TOML parses and has non-empty description + prompt" {
  for toml in "$PLUGIN_ROOT"/commands/lean-spec/*.toml; do
    run python3 -c "
import tomllib
with open('$toml', 'rb') as f: d = tomllib.load(f)
assert d.get('description','').strip(), 'empty description'
assert d.get('prompt','').strip(), 'empty prompt'
"
    [ "$status" -eq 0 ] || {
      echo "TOML issue in $(basename "$toml"): $output"
      false
    }
  done
}

@test "every Gemini TOML references {{args}} for user-provided arguments" {
  # Except close-spec / spec-status / next / resume-spec which can take args but also work without
  # We check the minimum: every TOML that needs an argument has {{args}} somewhere in the prompt.
  # All 11 of ours reference args at least once.
  for toml in "$PLUGIN_ROOT"/commands/lean-spec/*.toml; do
    grep -q "{{args}}" "$toml" || {
      echo "TOML missing {{args}} placeholder: $(basename "$toml")"
      false
    }
  done
}

# ---------- drift-check script ----------

@test "scripts/verify-gemini-commands.sh exits 0 on current tree" {
  run "$PLUGIN_ROOT/scripts/verify-gemini-commands.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"in sync"* ]]
}

# ---------- hooks template ----------

@test ".gemini/hooks-template.json is valid JSON" {
  run jq . "$PLUGIN_ROOT/.gemini/hooks-template.json"
  [ "$status" -eq 0 ]
}

@test ".gemini/hooks-template.json references pre-tool-use-workflow.sh" {
  f="$PLUGIN_ROOT/.gemini/hooks-template.json"
  grep -q "pre-tool-use-workflow.sh" "$f"
}

@test ".gemini/INSTALL.md documents the degraded-mode caveats" {
  f="$PLUGIN_ROOT/.gemini/INSTALL.md"
  [ -f "$f" ]
  grep -qi "degraded" "$f"
  grep -qi "no subagent" "$f" || grep -qi "no per-role model pinning" "$f"
}
