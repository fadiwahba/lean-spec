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

@test "concurrent advances on the same slug: exactly one commits (lock serializes)" {
  # Fire many identical specifying->implementing advances at once, recording
  # each racer's exit code. The lock guarantees exactly one sees phase
  # specifying and commits (exit 0); every other loses the race, re-reads
  # implementing, and fails the current!=frm check (exit 2). Without the lock
  # two racers could both read specifying and both exit 0.
  d="$(mktemp -d "${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}/racesXXXXXX")"
  for i in $(seq 1 12); do
    ( "${LEAN_SPEC_BIN}" advance demo specifying implementing >/dev/null 2>&1; echo "$?" > "${d}/${i}" ) &
  done
  wait
  successes="$(grep -l '^0$' "${d}"/* | wc -l | tr -d ' ')"
  [ "$successes" = "1" ]
  # ...and the on-disk state is consistent: implementing, one history entry.
  run python3 -c "
import json
o = json.load(open('features/demo/workflow.json'))
assert o['phase'] == 'implementing', o['phase']
assert isinstance(o['history'], list) and len(o['history']) == 1, o['history']
print('ok')
"
  [ "$output" = "ok" ]
}

@test "advance on a never-ensured slug fails without creating a lock directory" {
  lean_spec advance neverexisted specifying implementing
  [ "$status" -eq 1 ]
  [[ "$output" == *"no such feature"* ]]
  [ ! -d features/neverexisted ]
}
