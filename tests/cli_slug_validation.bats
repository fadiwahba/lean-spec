#!/usr/bin/env bats
# Guards finding [MEDIUM]: unvalidated slug -> path traversal / absolute
# write. feature_dir() joins root/.lean-spec/features/<slug> with no sanitization, so
# a slug containing '/' (or being an absolute path) escapes .lean-spec/features/.

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

@test "ensure rejects a slug with path traversal ('../evil')" {
  lean_spec ensure '../evil'
  [ "$status" -ne 0 ]
  [ ! -e "../evil" ]
  [ ! -d "../evil" ]
}

@test "ensure rejects an absolute-path slug ('/tmp/abs')" {
  lean_spec ensure '/tmp/abs'
  [ "$status" -ne 0 ]
  [ ! -e "/tmp/abs/workflow.json" ]
}

@test "ensure still works for a normal slug" {
  lean_spec ensure demo
  [ "$status" -eq 0 ]
  [ -f .lean-spec/features/demo/workflow.json ]
}

@test "advance rejects a slug with path traversal" {
  lean_spec advance '../evil' specifying implementing
  [ "$status" -ne 0 ]
}

@test "assert rejects a slug with path traversal" {
  lean_spec assert '../evil' specifying
  [ "$status" -ne 0 ]
}

@test "validate rejects a slug with path traversal" {
  lean_spec validate '../evil' spec.md
  [ "$status" -ne 0 ]
}

@test "next <slug> rejects a slug with path traversal" {
  lean_spec next '../evil'
  [ "$status" -ne 0 ]
}

@test "status <slug> rejects a slug with path traversal" {
  lean_spec status '../evil'
  [ "$status" -ne 0 ]
}

@test "ensure rejects an empty slug" {
  lean_spec ensure ''
  [ "$status" -ne 0 ]
}

@test "ensure rejects a slug of just '.'" {
  lean_spec ensure '.'
  [ "$status" -ne 0 ]
}

@test "ensure rejects a slug of just '..'" {
  lean_spec ensure '..'
  [ "$status" -ne 0 ]
}

@test "ensure rejects a slug containing a slash mid-string" {
  lean_spec ensure 'foo/bar'
  [ "$status" -ne 0 ]
  [ ! -d ".lean-spec/features/foo" ]
}
