#!/usr/bin/env bats
# cmd_advance's read-modify-write (load_workflow -> gate -> mutate -> write)
# had no lock, so racing invocations on the same slug could interleave. An
# advisory flock around the critical section must serialize them: under
# parallel load exactly one transition commits and the on-disk state stays
# consistent (valid JSON, one history entry, correct phase).

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
  lean_spec ensure demo
  mkdir -p features/demo
  echo "# spec" > features/demo/spec.md
}

teardown() {
  lean_spec_teardown_repo
}

@test "advance still works normally with locking in place" {
  lean_spec advance demo specifying implementing
  [ "$status" -eq 0 ]
  lean_spec assert demo implementing
  [ "$status" -eq 0 ]
}

@test "concurrent advances on the same slug serialize to one consistent transition" {
  # Fire many identical specifying->implementing advances at once.
  for i in $(seq 1 12); do
    "${LEAN_SPEC_BIN}" advance demo specifying implementing >/dev/null 2>&1 &
  done
  wait
  # Exactly one committed: phase is implementing, history has one entry,
  # and the file is still valid JSON (no interleaved/corrupt write).
  run python3 -c "
import json
d = json.load(open('features/demo/workflow.json'))
assert d['phase'] == 'implementing', d['phase']
assert isinstance(d['history'], list) and len(d['history']) == 1, d['history']
print('ok')
"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}
