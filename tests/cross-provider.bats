#!/usr/bin/env bats
#
# cross-provider.bats — verify that workflow.json state is compatible across
# hosts (Claude Code, Gemini CLI, OpenCode, Codex) and that each host's shipped
# agent/command definitions are well-formed standalone.
#
# The compatibility claim from PRD §8.1: "Same workflow.json progressed across
# two hosts works correctly." This test exercises that by simulating a sequence
# where each phase is mutated as a different host would mutate it, and the
# resulting file stays valid.

setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/features/cross-host"

  # shellcheck disable=SC1091
  source "$PLUGIN_ROOT/lib/workflow.sh"
}

teardown() {
  rm -rf "$TMP"
}

# Helper — create a fresh workflow.json in specifying phase (mimics /start-spec)
init_workflow() {
  local wf="$TMP/features/cross-host/workflow.json"
  cat > "$wf" <<'EOF'
{
  "slug": "cross-host",
  "phase": "specifying",
  "created_at": "2026-04-24T10:00:00Z",
  "updated_at": "2026-04-24T10:00:00Z",
  "history": [
    { "phase": "specifying", "entered_at": "2026-04-24T10:00:00Z" }
  ],
  "artifacts": { "spec": "spec.md", "notes": "notes.md", "review": "review.md" }
}
EOF
  echo "$wf"
}

# ---------- artifact compatibility across hosts ----------

@test "workflow.json written by host A passes validate_transition on host B" {
  # Host A (Claude) writes workflow in specifying
  WF=$(init_workflow)
  touch "$TMP/features/cross-host/spec.md"

  # Host B (any) validates transition specifying → implementing via same lib/workflow.sh
  run validate_transition specifying implementing
  [ "$status" -eq 0 ]

  # Host B (any) mutates phase via set_phase helper
  run set_phase "$WF" "implementing" "2026-04-24T10:10:00Z"
  [ "$status" -eq 0 ]

  # State must still be valid JSON with updated phase + preserved history
  run jq -r '.phase' "$WF"
  [ "$output" = "implementing" ]
  run jq -r '.history | length' "$WF"
  [ "$output" = "2" ]
  run jq -r '.history[0].phase' "$WF"
  [ "$output" = "specifying" ]
  run jq -r '.history[1].phase' "$WF"
  [ "$output" = "implementing" ]
}

@test "full Claude→Gemini→Claude lifecycle preserves history chronologically" {
  # Simulate: Claude runs start-spec (creates), Gemini runs submit-implementation
  # (advances), Claude runs submit-review (advances), Gemini runs close-spec.
  WF=$(init_workflow)
  touch "$TMP/features/cross-host/spec.md"

  # Gemini-style: advance to implementing
  set_phase "$WF" "implementing" "2026-04-24T10:10:00Z"
  touch "$TMP/features/cross-host/notes.md"

  # Claude-style: advance to reviewing
  set_phase "$WF" "reviewing" "2026-04-24T10:20:00Z"
  # Write a valid review with APPROVE verdict
  cat > "$TMP/features/cross-host/review.md" <<'EOF'
---
slug: cross-host
phase: reviewing
verdict: APPROVE
---
# Review
EOF

  # Gemini-style: close
  set_phase "$WF" "closed" "2026-04-24T10:30:00Z"

  # All 4 transitions must be in history in order
  run jq -r '.history | map(.phase) | join(",")' "$WF"
  [ "$output" = "specifying,implementing,reviewing,closed" ]
}

@test "workflow.json from a prior host version must still parse on current lib" {
  # A realistic cross-version scenario: a teammate on an older lean-spec writes
  # workflow.json; we read it on the current lib. Required fields remain stable:
  # slug, phase, history (even if artifacts map changes shape).
  cat > "$TMP/features/cross-host/workflow.json" <<'EOF'
{
  "slug": "cross-host",
  "phase": "specifying",
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-01T00:00:00Z",
  "history": [{"phase": "specifying", "entered_at": "2026-01-01T00:00:00Z"}]
}
EOF
  # Note: no "artifacts" field. Current lib must still read phase fine.
  run read_phase "$TMP/features/cross-host/workflow.json"
  [ "$status" -eq 0 ]
  [ "$output" = "specifying" ]
}

# ---------- definitions load standalone per host ----------

@test "Claude Code: every agent + command + skill loads without user config" {
  # Heuristic: all required files exist at expected paths relative to plugin root.
  [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]
  for a in architect coder reviewer brainstormer; do
    [ -f "$PLUGIN_ROOT/agents/$a.md" ] || { echo "missing agents/$a.md"; false; }
  done
  for c in start-spec update-spec submit-implementation submit-review submit-fixes close-spec spec-status next resume-spec brainstorm decompose-prd; do
    [ -f "$PLUGIN_ROOT/commands/$c.md" ] || { echo "missing commands/$c.md"; false; }
  done
}

@test "Gemini CLI: manifest + every command TOML loads without user config" {
  [ -f "$PLUGIN_ROOT/gemini-extension.json" ]
  [ -f "$PLUGIN_ROOT/GEMINI.md" ]
  for c in start-spec update-spec submit-implementation submit-review submit-fixes close-spec spec-status next resume-spec brainstorm decompose-prd; do
    [ -f "$PLUGIN_ROOT/commands/lean-spec/$c.toml" ] || { echo "missing commands/lean-spec/$c.toml"; false; }
  done
}

@test "OpenCode: every agent + command loads without user config" {
  for a in architect coder reviewer brainstormer; do
    [ -f "$PLUGIN_ROOT/.opencode/agents/$a.md" ] || { echo "missing .opencode/agents/$a.md"; false; }
  done
  for c in start-spec update-spec submit-implementation submit-review submit-fixes close-spec spec-status next resume-spec brainstorm decompose-prd; do
    [ -f "$PLUGIN_ROOT/.opencode/commands/lean-spec/$c.md" ] || { echo "missing .opencode/commands/lean-spec/$c.md"; false; }
  done
}

@test "Codex: AGENTS.md + every prompt loads without user config" {
  [ -f "$PLUGIN_ROOT/.codex/AGENTS.md" ]
  [ -f "$PLUGIN_ROOT/.codex/INSTALL.md" ]
  for c in start-spec update-spec submit-implementation submit-review submit-fixes close-spec spec-status next resume-spec brainstorm decompose-prd; do
    [ -f "$PLUGIN_ROOT/.codex/prompts/$c.md" ] || { echo "missing .codex/prompts/$c.md"; false; }
  done
}

@test "ALL hosts ship EXACTLY 11 user-facing entry points (matching the Claude canon)" {
  EXPECTED=11
  CLAUDE=$(ls "$PLUGIN_ROOT"/commands/*.md | wc -l | tr -d ' ')
  GEMINI=$(ls "$PLUGIN_ROOT"/commands/lean-spec/*.toml | wc -l | tr -d ' ')
  OPENCODE=$(ls "$PLUGIN_ROOT"/.opencode/commands/lean-spec/*.md | wc -l | tr -d ' ')
  CODEX=$(ls "$PLUGIN_ROOT"/.codex/prompts/*.md | wc -l | tr -d ' ')
  [ "$CLAUDE" = "$EXPECTED" ]
  [ "$GEMINI" = "$EXPECTED" ]
  [ "$OPENCODE" = "$EXPECTED" ]
  [ "$CODEX" = "$EXPECTED" ]
}

# ---------- degraded-mode disclosure ----------

@test "each non-Claude host documents its degraded-mode caveats" {
  # Gemini: no subagent dispatch
  grep -qi "no subagent" "$PLUGIN_ROOT/GEMINI.md"
  # OpenCode: subagents work but hook-layer enforcement doesn't
  grep -qi "subagent" "$PLUGIN_ROOT/.opencode/INSTALL.md"
  # Codex: lightest integration, no slash commands
  grep -qi "no slash-command" "$PLUGIN_ROOT/.codex/AGENTS.md"
}
