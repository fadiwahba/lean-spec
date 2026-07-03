#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

driver() {
  echo "$1" | bash "${LEAN_SPEC_HOOKS}/stop-auto-driver.sh"
}

write_auto() {
  mkdir -p .lean-spec
  cat > .lean-spec/auto.json
}

@test "allows stop when no auto.json exists" {
  run driver '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "blocks stop and instructs next skill when auto.json is active" {
  lean_spec ensure demo
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":0}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *"/lean-spec:implement demo"* ]]
}

@test "increments cycles atomically on each block" {
  lean_spec ensure demo
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":0}
EOF
  driver '{}' >/dev/null
  run python3 -c "import json; print(json.load(open('.lean-spec/auto.json'))['cycles'])"
  [ "$output" = "1" ]
}

@test "respects stop_hook_active to prevent infinite loop (no block)" {
  lean_spec ensure demo
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":0}
EOF
  run driver '{"stop_hook_active": true}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stop_hook_active guard does not increment cycles" {
  lean_spec ensure demo
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":0}
EOF
  driver '{"stop_hook_active": true}' >/dev/null
  run python3 -c "import json; print(json.load(open('.lean-spec/auto.json'))['cycles'])"
  [ "$output" = "0" ]
}

@test "stops and removes auto.json once feature is closed" {
  lean_spec ensure demo
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":3}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f .lean-spec/auto.json ]
}

@test "stops and removes auto.json when review verdict is BLOCKED" {
  lean_spec ensure demo
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: BLOCKED" > features/demo/review.md
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":1}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f .lean-spec/auto.json ]
}

@test "stops and removes auto.json once cycle cap is reached" {
  lean_spec ensure demo
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":2,"cycles":2}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f .lean-spec/auto.json ]
}

@test "removes auto.json and allows when slug field is missing/blank" {
  write_auto <<'EOF'
{"gates_on":false,"max_cycles":20,"cycles":0}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [ ! -f .lean-spec/auto.json ]
}

@test "chain_all: closing one feature chains to the next non-closed feature" {
  lean_spec ensure demo
  lean_spec ensure second
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":3,"chain_all":true}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *"second"* ]]
  run python3 -c "import json; d=json.load(open('.lean-spec/auto.json')); print(d['slug'], d['cycles'])"
  [ "$output" = "second 0" ]
}

@test "chain_all: stops entirely once every feature is closed" {
  lean_spec ensure demo
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":1,"chain_all":true}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f .lean-spec/auto.json ]
}

@test "chain_all: a BLOCKED verdict stops the whole chain (does not skip to next feature)" {
  lean_spec ensure demo
  lean_spec ensure second
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: BLOCKED" > features/demo/review.md
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":1,"chain_all":true}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f .lean-spec/auto.json ]
}
