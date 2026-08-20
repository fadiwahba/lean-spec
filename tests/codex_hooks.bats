#!/usr/bin/env bats

load 'helpers.bash'

guard() {
  printf '%s' "$1" | bash "${LEAN_SPEC_HOOKS}/pre-tool-use-guard.sh"
}

@test "Codex apply_patch denies a multi-file patch with a protected absolute path" {
  run guard '{"tool_name":"apply_patch","tool_input":{"patch":"*** Begin Patch\n*** Update File: README.md\n*** End Patch\n*** Begin Patch\n*** Update File: /repo/.lean-spec/features/demo/../demo/Workflow.json\n*** End Patch"}}'

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "Codex apply_patch allows a multi-file patch with no protected target" {
  run guard '{"tool_name":"apply_patch","tool_input":{"patch":"*** Begin Patch\n*** Update File: README.md\n*** End Patch\n*** Begin Patch\n*** Add File: .lean-spec/features/demo/spec.md\n*** End Patch"}}'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
