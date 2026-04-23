#!/usr/bin/env bats
#
# codex-install.bats — verify the Codex install-path surface:
#   - .codex/AGENTS.md exists and names the degraded-mode caveat
#   - .codex/INSTALL.md exists and documents the limitations
#   - .codex/prompts/*.md has one prompt per Claude command (1:1 correspondence)
#   - Each prompt includes a phase-gate bash block

setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test ".codex/AGENTS.md exists and documents the lifecycle" {
  f="$PLUGIN_ROOT/.codex/AGENTS.md"
  [ -f "$f" ]
  grep -qi "specifying" "$f"
  grep -qi "implementing" "$f"
  grep -qi "reviewing" "$f"
  grep -qi "closed" "$f"
}

@test ".codex/AGENTS.md documents the degraded-mode caveats" {
  f="$PLUGIN_ROOT/.codex/AGENTS.md"
  grep -qi "no subagent" "$f" || grep -qi "no slash-command" "$f"
  grep -qi "tier enforcement" "$f" || grep -qi "degraded" "$f"
}

@test ".codex/AGENTS.md names the hard-forbidden edits list" {
  f="$PLUGIN_ROOT/.codex/AGENTS.md"
  grep -qi "package.json" "$f"
  grep -qi "lockfile" "$f" || grep -qi "pnpm-lock" "$f" || grep -qi "package-lock" "$f"
  grep -qi "layout.tsx" "$f"
}

@test ".codex/INSTALL.md exists and documents install + use" {
  f="$PLUGIN_ROOT/.codex/INSTALL.md"
  [ -f "$f" ]
  grep -qi "install" "$f"
  grep -qi "codex" "$f"
}

@test "every Claude command has a Codex prompt sibling" {
  for md in "$PLUGIN_ROOT"/commands/*.md; do
    name=$(basename "$md" .md)
    [ -f "$PLUGIN_ROOT/.codex/prompts/$name.md" ] || {
      echo "missing .codex/prompts/$name.md"
      false
    }
  done
}

@test "every Codex prompt has a Claude MD sibling" {
  for p in "$PLUGIN_ROOT"/.codex/prompts/*.md; do
    name=$(basename "$p" .md)
    [ -f "$PLUGIN_ROOT/commands/$name.md" ] || {
      echo "orphan .codex/prompts/$name.md"
      false
    }
  done
}

@test "phase-advancing Codex prompts include a phase-gate bash block" {
  for name in submit-implementation submit-review submit-fixes close-spec; do
    f="$PLUGIN_ROOT/.codex/prompts/$name.md"
    grep -q '```bash' "$f" || { echo "$name missing bash block"; false; }
    grep -q "Phase gate" "$f" || { echo "$name missing 'Phase gate' reference"; false; }
  done
}

@test "submit-review Codex prompt archives prior review.md" {
  f="$PLUGIN_ROOT/.codex/prompts/submit-review.md"
  grep -q "review-cycle-" "$f"
}

@test "submit-fixes Codex prompt instructs APPEND (not rewrite)" {
  f="$PLUGIN_ROOT/.codex/prompts/submit-fixes.md"
  grep -qi "append" "$f"
  grep -qi "Cycle" "$f"
}
