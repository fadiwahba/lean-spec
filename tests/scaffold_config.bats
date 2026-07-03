#!/usr/bin/env bats

load 'helpers.bash'

@test "examples/rules.toml required_sections match templates/*.md headings" {
  run python3 -c "
import tomllib
rules = tomllib.load(open('${LEAN_SPEC_REPO_ROOT}/examples/rules.toml', 'rb'))
expect = {
    'spec.md': ['Scope', 'Acceptance Criteria', 'Out of Scope', 'Coder Guardrails'],
    'notes.md': ['What was built', 'How to verify'],
    'review.md': ['Verdict', 'Spec Compliance', 'Code Quality'],
}
for artifact, sections in expect.items():
    text = open('${LEAN_SPEC_REPO_ROOT}/templates/' + artifact).read()
    headings = {l[3:].strip() for l in text.splitlines() if l.startswith('## ')}
    for s in sections:
        assert s in headings, (artifact, s, headings)
    assert rules['required_sections'][artifact] == sections
print('ok')
"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "examples/rules.toml defaults.tdd is true and required_verdict is APPROVE" {
  run python3 -c "
import tomllib
rules = tomllib.load(open('${LEAN_SPEC_REPO_ROOT}/examples/rules.toml', 'rb'))
assert rules['defaults']['tdd'] is True
assert rules['defaults']['required_verdict'] == 'APPROVE'
print('ok')
"
  [ "$output" = "ok" ]
}

@test "CI workflow references the bats bootstrap and test run" {
  grep -q 'bootstrap-bats.sh' "${LEAN_SPEC_REPO_ROOT}/.github/workflows/ci.yml"
  grep -q 'bats tests/' "${LEAN_SPEC_REPO_ROOT}/.github/workflows/ci.yml"
}

@test "CI workflow checks python3 >= 3.11" {
  grep -q '3, 11' "${LEAN_SPEC_REPO_ROOT}/.github/workflows/ci.yml"
}
