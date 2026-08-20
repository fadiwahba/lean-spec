#!/usr/bin/env bats

load 'helpers.bash'

INSTALLER="${LEAN_SPEC_REPO_ROOT}/adapters/codex/install.py"

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

@test "installed Codex runtime creates state and rejects direct state edits" {
  run python3 "$INSTALLER" --project "$LEAN_SPEC_TESTDIR"
  [ "$status" -eq 0 ]

  run .lean-spec/runtime/bin/lean-spec ensure codex-demo
  [ "$status" -eq 0 ]
  [ -f .lean-spec/features/codex-demo/workflow.json ]

  run bash .lean-spec/runtime/hooks/pre-tool-use-guard.sh <<'EOF'
{"tool_name":"apply_patch","tool_input":{"patch":"*** Begin Patch\n*** Update File: .lean-spec/features/codex-demo/workflow.json\n*** End Patch"}}
EOF
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "installed Codex runtime drives a feature from specifying to closed through CLI gates" {
  run python3 "$INSTALLER" --project "$LEAN_SPEC_TESTDIR"
  [ "$status" -eq 0 ]

  run bash -c '
    set -euo pipefail
    cli=.lean-spec/runtime/bin/lean-spec
    "$cli" ensure codex-lifecycle
    cat > .lean-spec/features/codex-lifecycle/spec.md <<"EOF"
## Scope
One deterministic slice.
## Acceptance Criteria
The lifecycle closes.
## Out of Scope
None.
## Coder Guardrails
Use the CLI.
EOF
    "$cli" advance codex-lifecycle specifying implementing
    cat > .lean-spec/features/codex-lifecycle/notes.md <<"EOF"
## What was built
The lifecycle fixture.
## How to verify
Run the CLI checks.
## TDD
Red then green.
EOF
    "$cli" advance codex-lifecycle implementing reviewing
    cat > .lean-spec/features/codex-lifecycle/review.md <<"EOF"
## Verdict
verdict: APPROVE
## Spec Compliance
Meets the fixture scope.
## Code Quality
CLI gates were used.
EOF
    "$cli" advance codex-lifecycle reviewing closed
    "$cli" assert codex-lifecycle closed
  '
  [ "$status" -eq 0 ]
}
