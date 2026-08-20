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
