#!/usr/bin/env bats

load 'helpers.bash'

@test "plugin.json is valid JSON" {
  run python3 -m json.tool "${LEAN_SPEC_REPO_ROOT}/.claude-plugin/plugin.json"
  [ "$status" -eq 0 ]
}

@test "plugin.json declares name lean-spec and version" {
  run python3 -c "
import json
d = json.load(open('${LEAN_SPEC_REPO_ROOT}/.claude-plugin/plugin.json'))
assert d['name'] == 'lean-spec'
assert d['version']
print('ok')
"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "plugin.json wires all three hooks" {
  run python3 -c "
import json
d = json.load(open('${LEAN_SPEC_REPO_ROOT}/.claude-plugin/plugin.json'))
for ev in ('PreToolUse', 'SubagentStop', 'Stop'):
    assert ev in d['hooks'], ev
print('ok')
"
  [ "$output" = "ok" ]
}

@test "examples/rules.toml is valid TOML" {
  run python3 -c "import tomllib; tomllib.load(open('${LEAN_SPEC_REPO_ROOT}/examples/rules.toml','rb'))"
  [ "$status" -eq 0 ]
}

@test "every hooks/*.sh passes bash -n" {
  for f in "${LEAN_SPEC_REPO_ROOT}"/hooks/*.sh; do
    run bash -n "$f"
    [ "$status" -eq 0 ]
  done
}

@test "scripts/bootstrap-bats.sh passes bash -n" {
  run bash -n "${LEAN_SPEC_REPO_ROOT}/scripts/bootstrap-bats.sh"
  [ "$status" -eq 0 ]
}

@test "scripts/bootstrap-bats.sh pins a default bats-core version, overridable via env" {
  local script="${LEAN_SPEC_REPO_ROOT}/scripts/bootstrap-bats.sh"
  grep -qE 'BATS_CORE_VERSION:-v1\.13\.0' "$script"
  grep -qE -- '--branch "\$BATS_CORE_VERSION"' "$script"
  grep -qE -- '--depth 1' "$script"
}

@test "bin/lean-spec is a valid python3 file" {
  run python3 -c "import ast; ast.parse(open('${LEAN_SPEC_BIN}').read())"
  [ "$status" -eq 0 ]
}

@test "bin/lean-spec is executable" {
  [ -x "${LEAN_SPEC_BIN}" ]
}

@test "hooks are executable" {
  for f in "${LEAN_SPEC_REPO_ROOT}"/hooks/*.sh; do
    [ -x "$f" ]
  done
}

@test "lean-spec fails loudly with an unknown command" {
  run "${LEAN_SPEC_BIN}" bogus-command
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown command"* ]]
}

@test "lean-spec with no arguments prints usage and exits non-zero" {
  run "${LEAN_SPEC_BIN}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "every templates/*.md file exists" {
  for f in PRD.md CONSTITUTION.md spec.md notes.md review.md; do
    [ -f "${LEAN_SPEC_REPO_ROOT}/templates/${f}" ]
  done
}

@test "gitignore excludes features/*/evidence/ and .tools/" {
  grep -q 'features/\*/evidence/' "${LEAN_SPEC_REPO_ROOT}/.gitignore"
  grep -q '.tools/' "${LEAN_SPEC_REPO_ROOT}/.gitignore"
}
