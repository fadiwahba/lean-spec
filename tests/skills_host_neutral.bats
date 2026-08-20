#!/usr/bin/env bats

load 'helpers.bash'

@test "canonical skills contain no Claude command or tool syntax" {
  run rg -n '/lean-spec:|AskUserQuestion|Task tool|Claude Code' "${LEAN_SPEC_REPO_ROOT}/skills"

  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "canonical skills define no host-specific invocation policy" {
  run rg -n '^disable-model-invocation:' "${LEAN_SPEC_REPO_ROOT}/skills"

  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "Codex policy generation keeps mutating skills explicit-only" {
  run python3 "${LEAN_SPEC_REPO_ROOT}/adapters/codex/render_skill_policies.py" --check

  [ "$status" -eq 0 ]
  for skill in init plan spec respec implement review fix close auto auto-all; do
    grep -Fx '  allow_implicit_invocation: false' "${LEAN_SPEC_REPO_ROOT}/skills/${skill}/agents/openai.yaml"
  done
  [ ! -e "${LEAN_SPEC_REPO_ROOT}/skills/status/agents/openai.yaml" ]
}
