#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

@test "ensure creates workflow state below .lean-spec" {
  lean_spec ensure demo
  [ "$status" -eq 0 ]
  [ -f .lean-spec/features/demo/workflow.json ]
  [ ! -e features/demo/workflow.json ]
}

@test "migrate-layout dry run reports legacy moves without changing paths" {
  mkdir -p docs features/demo
  echo '# PRD' > docs/PRD.md
  echo '{}' > features/demo/workflow.json

  lean_spec migrate-layout --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"docs/PRD.md -> .lean-spec/PRD.md"* ]]
  [[ "$output" == *"features -> .lean-spec/features"* ]]
  [ -f docs/PRD.md ]
  [ -f features/demo/workflow.json ]
  [ ! -e .lean-spec/PRD.md ]
}

@test "migrate-layout moves legacy docs and features to the canonical root" {
  mkdir -p docs features/demo
  echo '# PRD' > docs/PRD.md
  echo '# Constitution' > docs/CONSTITUTION.md
  echo '{}' > features/demo/workflow.json

  lean_spec migrate-layout
  [ "$status" -eq 0 ]
  [ -f .lean-spec/PRD.md ]
  [ -f .lean-spec/CONSTITUTION.md ]
  [ -f .lean-spec/features/demo/workflow.json ]
  [ ! -e docs/PRD.md ]
  [ ! -e features ]
}

@test "migrate-layout rejects a legacy and canonical path conflict without moving anything" {
  mkdir -p docs .lean-spec
  echo '# old' > docs/PRD.md
  echo '# new' > .lean-spec/PRD.md

  lean_spec migrate-layout
  [ "$status" -eq 1 ]
  [[ "$output" == *"conflict"* ]]
  [ -f docs/PRD.md ]
  [ -f .lean-spec/PRD.md ]
}
