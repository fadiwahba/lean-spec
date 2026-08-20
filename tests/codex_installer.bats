#!/usr/bin/env bats

load 'helpers.bash'

INSTALLER="${LEAN_SPEC_REPO_ROOT}/adapters/codex/install.py"

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

install_adapter() {
  run python3 "${INSTALLER}" --project "$LEAN_SPEC_TESTDIR" "$@"
}

@test "dry-run reports the Codex adapter without changing the project" {
  install_adapter --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *".agents/skills/lean-spec-plan"* ]]
  [ ! -e .agents ]
  [ ! -e .codex ]
  [ ! -e .lean-spec ]
  [ ! -e AGENTS.md ]
}

@test "installs idempotently and preserves existing AGENTS and hooks" {
  printf '%s\n' '# Local rules' > AGENTS.md
  mkdir -p .codex
  printf '%s\n' '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"local-start"}]}]}}' > .codex/hooks.json

  install_adapter
  [ "$status" -eq 0 ]
  install_adapter
  [ "$status" -eq 0 ]

  [ "$(grep -c '<!-- lean-spec:begin -->' AGENTS.md)" -eq 1 ]
  grep -F '# Local rules' AGENTS.md
  python3 - <<'PY'
import json
from pathlib import Path

hooks = json.loads(Path('.codex/hooks.json').read_text())['hooks']
assert hooks['SessionStart'][0]['hooks'][0]['command'] == 'local-start'
assert len(hooks['PreToolUse']) == 1
assert hooks['PreToolUse'][0]['matcher'] == '^(apply_patch|Bash)$'
assert len(hooks['Stop']) == 1
PY
  [ -x .lean-spec/runtime/bin/lean-spec ]
  [ -f .agents/skills/lean-spec-plan/SKILL.md ]
  [ -f .codex/agents/lean-spec-architect.toml ]
  grep -Fx 'model = "gpt-5.6-sol"' .codex/agents/lean-spec-architect.toml
  grep -Fx 'model = "gpt-5.6-terra"' .codex/agents/lean-spec-coder.toml
  grep -Fx 'model_reasoning_effort = "medium"' .codex/agents/lean-spec-coder.toml
}

@test "refuses an unsupported existing Codex hooks shape without writing" {
  mkdir -p .codex
  printf '%s\n' '{"hooks":[]}' > .codex/hooks.json

  install_adapter

  [ "$status" -ne 0 ]
  [[ "$output" == *"hooks"* ]]
  [ "$(cat .codex/hooks.json)" = '{"hooks":[]}' ]
  [ ! -e .lean-spec ]
  [ ! -e AGENTS.md ]
}

@test "uses explicit Codex role mappings from project rules" {
  mkdir -p .lean-spec
  cat > .lean-spec/rules.toml <<'EOF'
[hosts.codex]
spec = { model = "gpt-5.6-terra", effort = "medium" }
EOF

  install_adapter

  [ "$status" -eq 0 ]
  grep -Fx 'model = "gpt-5.6-terra"' .codex/agents/lean-spec-architect.toml
  grep -Fx 'model_reasoning_effort = "medium"' .codex/agents/lean-spec-architect.toml
}
