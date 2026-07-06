#!/usr/bin/env bats
# atomic_write_json used tempfile.mkstemp (mode 0600) + os.replace, so every
# CLI-driven write silently downgraded workflow.json's permissions to
# owner-only, regardless of the file's prior mode or the process umask. The
# write must preserve an existing file's mode and create new files per umask.

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

mode_of() {
  python3 -c "import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777)[2:])" "$1"
}

@test "advance preserves an existing workflow.json's file mode (does not downgrade to 600)" {
  lean_spec ensure demo
  mkdir -p features/demo
  echo "# spec" > features/demo/spec.md
  chmod 644 features/demo/workflow.json
  lean_spec advance demo specifying implementing
  [ "$status" -eq 0 ]
  run mode_of features/demo/workflow.json
  [ "$output" = "644" ]
}

@test "ensure creates a new workflow.json per umask, not owner-only 600" {
  run bash -c "umask 022; '${LEAN_SPEC_BIN}' ensure demo >/dev/null && python3 -c \"import os; print(oct(os.stat('features/demo/workflow.json').st_mode & 0o777)[2:])\""
  [ "$status" -eq 0 ]
  [ "$output" = "644" ]
}
