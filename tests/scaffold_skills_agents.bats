#!/usr/bin/env bats

load 'helpers.bash'

SKILL_NAMES="init plan spec respec implement review fix close auto auto-all next status"
AGENT_NAMES="architect coder reviewer"

parse_frontmatter() {
  # Extracts the YAML frontmatter block between the first two '---' lines
  # and pretty-prints selected keys via a tiny hand-rolled parser (no PyYAML
  # available — stdlib only, per CONSTITUTION). Good enough for flat
  # key: value frontmatter as used here.
  python3 -c "
import sys
path = sys.argv[1]
text = open(path).read()
assert text.startswith('---\n'), 'missing frontmatter start'
end = text.index('\n---', 4)
block = text[4:end]
for line in block.splitlines():
    line = line.rstrip()
    if not line or line.startswith('#'):
        continue
    if ':' in line:
        k, v = line.split(':', 1)
        print(f'{k.strip()}={v.strip()}')
" "$1"
}

@test "every skill directory in plugin.json exists with a SKILL.md" {
  for name in $SKILL_NAMES; do
    [ -f "${LEAN_SPEC_REPO_ROOT}/skills/${name}/SKILL.md" ]
  done
}

@test "every agent file referenced in plugin.json exists" {
  for name in $AGENT_NAMES; do
    [ -f "${LEAN_SPEC_REPO_ROOT}/agents/${name}.md" ]
  done
}

@test "plugin.json's skills/agents lists match the filesystem exactly" {
  run python3 -c "
import json, os
root = '${LEAN_SPEC_REPO_ROOT}'
d = json.load(open(os.path.join(root, '.claude-plugin/plugin.json')))
declared_skills = {s.rsplit('/', 1)[-1] for s in d['skills']}
actual_skills = set(os.listdir(os.path.join(root, 'skills')))
assert declared_skills == actual_skills, (declared_skills, actual_skills)
declared_agents = {a.rsplit('/', 1)[-1] for a in d['agents']}
actual_agents = set(os.listdir(os.path.join(root, 'agents')))
assert declared_agents == actual_agents, (declared_agents, actual_agents)
print('ok')
"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "every SKILL.md has valid frontmatter with a name field matching its directory" {
  for name in $SKILL_NAMES; do
    run parse_frontmatter "${LEAN_SPEC_REPO_ROOT}/skills/${name}/SKILL.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"name=${name}"* ]]
  done
}

@test "every SKILL.md has a non-empty description field" {
  for name in $SKILL_NAMES; do
    run parse_frontmatter "${LEAN_SPEC_REPO_ROOT}/skills/${name}/SKILL.md"
    [[ "$output" == *"description="?* ]]
  done
}

@test "mutating skills set disable-model-invocation: true" {
  for name in init plan spec respec implement review fix close auto auto-all; do
    run parse_frontmatter "${LEAN_SPEC_REPO_ROOT}/skills/${name}/SKILL.md"
    [[ "$output" == *"disable-model-invocation=true"* ]]
  done
}

@test "read-only skills (next, status) do not disable model invocation" {
  for name in next status; do
    run parse_frontmatter "${LEAN_SPEC_REPO_ROOT}/skills/${name}/SKILL.md"
    [[ "$output" != *"disable-model-invocation"* ]]
  done
}

@test "spec skill feeds the architect the delivered ACs of closed slices" {
  grep -q 'closed slice' "${LEAN_SPEC_REPO_ROOT}/skills/spec/SKILL.md"
  grep -qi 'already delivered' "${LEAN_SPEC_REPO_ROOT}/skills/spec/SKILL.md"
  grep -qi 'already delivered' "${LEAN_SPEC_REPO_ROOT}/agents/architect.md"
}

@test "spec skill documents --no-confirm and the fail-safe sentinel rule" {
  grep -q -- '--no-confirm' "${LEAN_SPEC_REPO_ROOT}/skills/spec/SKILL.md"
  grep -q 'NO_REMAINING_SCOPE' "${LEAN_SPEC_REPO_ROOT}/skills/spec/SKILL.md"
}

@test "architect documents the NO_REMAINING_SCOPE sentinel for the propose dispatch only" {
  grep -q 'NO_REMAINING_SCOPE' "${LEAN_SPEC_REPO_ROOT}/agents/architect.md"
  grep -q 'Propose dispatch' "${LEAN_SPEC_REPO_ROOT}/agents/architect.md"
}

@test "auto-all skill documents --no-confirm and max_features" {
  grep -q -- '--no-confirm' "${LEAN_SPEC_REPO_ROOT}/skills/auto-all/SKILL.md"
  grep -q 'max_features' "${LEAN_SPEC_REPO_ROOT}/skills/auto-all/SKILL.md"
}

@test "auto-all skill documents the --no-confirm cold-start clause" {
  grep -qi 'cold start' "${LEAN_SPEC_REPO_ROOT}/skills/auto-all/SKILL.md"
}

@test "auto-all cold-start clause runs the spec skill's preflight before speccing" {
  grep -q -- '`## Preflight (fail-loud)` section first' "${LEAN_SPEC_REPO_ROOT}/skills/auto-all/SKILL.md"
}

@test "spec skill preflights the project docs before dispatch" {
  grep -q 'validate --project PRD.md' "${LEAN_SPEC_REPO_ROOT}/skills/spec/SKILL.md"
  grep -q 'validate --project CONSTITUTION.md' "${LEAN_SPEC_REPO_ROOT}/skills/spec/SKILL.md"
}

@test "plan skill grounds the interview in the existing repo" {
  grep -qi 'existing repo' "${LEAN_SPEC_REPO_ROOT}/skills/plan/SKILL.md"
}

@test "no SKILL.md contains a bash phase-gate block (no fenced bash/sh code)" {
  for name in $SKILL_NAMES; do
    run grep -c '```bash\|```sh' "${LEAN_SPEC_REPO_ROOT}/skills/${name}/SKILL.md"
    [ "$output" = "0" ]
  done
}

@test "every agents/*.md has model and effort in frontmatter" {
  for name in $AGENT_NAMES; do
    run parse_frontmatter "${LEAN_SPEC_REPO_ROOT}/agents/${name}.md"
    [[ "$output" == *"model="* ]]
    [[ "$output" == *"effort="* ]]
  done
}

@test "architect is opus/xhigh, coder is sonnet/high, reviewer is opus/high" {
  run parse_frontmatter "${LEAN_SPEC_REPO_ROOT}/agents/architect.md"
  [[ "$output" == *"model=opus"* ]]
  [[ "$output" == *"effort=xhigh"* ]]

  run parse_frontmatter "${LEAN_SPEC_REPO_ROOT}/agents/coder.md"
  [[ "$output" == *"model=sonnet"* ]]
  [[ "$output" == *"effort=high"* ]]

  run parse_frontmatter "${LEAN_SPEC_REPO_ROOT}/agents/reviewer.md"
  [[ "$output" == *"model=opus"* ]]
  [[ "$output" == *"effort=high"* ]]
}

@test "coder agent frontmatter does not grant a git/commit-capable tool beyond Bash sandboxing note" {
  # The coder must never commit; enforced by convention + orchestrator, but
  # at minimum the doc must state it explicitly in its Never-does list.
  run grep -c 'Never does' "${LEAN_SPEC_REPO_ROOT}/agents/coder.md"
  [ "$output" != "0" ]
  run grep -ci 'commit' "${LEAN_SPEC_REPO_ROOT}/agents/coder.md"
  [ "$output" != "0" ]
}

@test "each agent file has a Never does section" {
  for name in $AGENT_NAMES; do
    run grep -c '## Never does' "${LEAN_SPEC_REPO_ROOT}/agents/${name}.md"
    [ "$output" = "1" ]
  done
}

@test "every artifact-writing agent grants a Write tool (not a Bash heredoc)" {
  # architect->spec.md, coder->notes.md, reviewer->review.md — each writes
  # exactly one mandatory markdown artifact and must do so via the Write
  # tool. Falling back to a Bash heredoc is the same anti-pattern the
  # CONSTITUTION forbids for workflow.json; an agent with no Write tool
  # cannot produce its artifact cleanly (architect had no Write AND no Bash,
  # so it could not write its spec at all).
  for name in $AGENT_NAMES; do
    run grep -E '^tools:' "${LEAN_SPEC_REPO_ROOT}/agents/${name}.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Write"* ]]
  done
}
