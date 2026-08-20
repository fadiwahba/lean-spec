#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
  lean_spec ensure demo
  lean_spec auto arm demo
  run python3 -c "import json; print(json.load(open('.lean-spec/auto.json'))['run_id'])"
  run_id="$output"
}

teardown() {
  lean_spec_teardown_repo
}

@test "auto arm records explicit run and expected phase identity" {
  run python3 -c "import json; d=json.load(open('.lean-spec/auto.json')); print(d['schema_version'], d['expected_phase'], bool(d['run_id']))"
  [ "$status" -eq 0 ]
  [ "$output" = "1 specifying True" ]
}

@test "auto tick returns READY and stores a duplicate-safe result" {
  lean_spec auto tick --run-id "$run_id" --event-id event-1 --json
  [ "$status" -eq 0 ]
  first="$output"
  [[ "$first" == *'"outcome": "READY"'* ]]

  lean_spec auto tick --run-id "$run_id" --event-id event-1 --json
  [ "$status" -eq 0 ]
  [ "$output" = "$first" ]
}

@test "auto tick rejects a stale run id without mutating auto state" {
  before="$(cat .lean-spec/auto.json)"
  lean_spec auto tick --run-id stale --event-id event-1 --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"run id"* ]]
  [ "$(cat .lean-spec/auto.json)" = "$before" ]
}

@test "auto tick rejects an unexpected feature phase without mutating auto state" {
  lean_spec_write_artifact demo spec.md <<'EOF'
# spec
EOF
  lean_spec advance demo specifying implementing
  before="$(cat .lean-spec/auto.json)"

  lean_spec auto tick --run-id "$run_id" --event-id event-1 --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"expected phase"* ]]
  [ "$(cat .lean-spec/auto.json)" = "$before" ]
}
