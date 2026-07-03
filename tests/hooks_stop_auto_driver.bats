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
  [[ "$output" != *'\'* ]]
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

@test "keeps driving when stop_hook_active is true and auto.json is live (PRD R4)" {
  # stop_hook_active is true on EVERY stop after the first hook-driven
  # continuation; exiting on it would cap auto mode at one cycle per user
  # prompt. The max_cycles cap is the runaway guard, not this flag.
  lean_spec ensure demo
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":0}
EOF
  run driver '{"stop_hook_active": true}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *"/lean-spec:implement demo"* ]]
}

@test "stop_hook_active continuation still increments cycles toward the cap" {
  lean_spec ensure demo
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":0}
EOF
  driver '{"stop_hook_active": true}' >/dev/null
  run python3 -c "import json; print(json.load(open('.lean-spec/auto.json'))['cycles'])"
  [ "$output" = "1" ]
}

@test "cycle cap still stops the loop when stop_hook_active is true" {
  lean_spec ensure demo
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":2,"cycles":2}
EOF
  run driver '{"stop_hook_active": true}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f .lean-spec/auto.json ]
}

@test "disarms and allows stop when next-resolution fails (unknown slug)" {
  # auto.json points at a feature with no workflow.json: `lean-spec next`
  # errors, so the driver must disarm loudly instead of burning cycles
  # blocking on a step it can never resolve.
  write_auto <<'EOF'
{"slug":"ghost","gates_on":false,"max_cycles":20,"cycles":0}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [[ "$output" != *'"decision"'* ]]
  [ ! -f .lean-spec/auto.json ]
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

@test "coerces string-numeric cycles/max_cycles and still blocks and increments" {
  lean_spec ensure demo
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":"20","cycles":"0"}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *"/lean-spec:implement demo"* ]]
  run python3 -c "import json; print(json.load(open('.lean-spec/auto.json'))['cycles'])"
  [ "$output" = "1" ]
}

@test "disarms and removes auto.json when cycles is null (nonsensical)" {
  lean_spec ensure demo
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":null}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [[ "$output" != *'"decision"'* ]]
  [ ! -f .lean-spec/auto.json ]
}

@test "disarms and removes auto.json when max_cycles is garbage text" {
  lean_spec ensure demo
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":"abc","cycles":0}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [[ "$output" != *'"decision"'* ]]
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

@test "chain_all: chaining to a blocked feature stops the chain and escalates" {
  # After a chain_all "closed" -> chained hop, the driver re-resolves
  # `lean-spec next` on the newly chained slug and must re-check its action.
  # A chained-to feature that is not actionable (here "second" is in
  # "reviewing" with no review.md, so `next` -> action "blocked") stops the
  # whole chain and disarms auto mode — per the CONSTITUTION ("BLOCKED
  # verdicts stop the line and escalate") — instead of emitting a block
  # round pointing at a step that cannot run.
  lean_spec ensure demo
  lean_spec ensure second
  lean_spec advance demo specifying implementing
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  lean_spec advance second specifying implementing
  lean_spec advance second implementing reviewing
  # No features/second/review.md: `lean-spec next second` -> action "blocked".
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":3,"chain_all":true}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [[ "$output" != *'"decision"'* ]]
  [ ! -f .lean-spec/auto.json ]
}

@test "block reason contains no stray backslash-backtick (regression guard)" {
  # `\`` is not a Python escape; leaving it in the reason f-strings leaked
  # literal backslashes into the user-facing block reason. Guard statically
  # so the fix holds even though the defensive fallback branch is no longer
  # reachable on the happy path (chained-to-blocked now stops the chain).
  run grep -F '\`' "${LEAN_SPEC_HOOKS}/stop-auto-driver.sh"
  [ "$status" -ne 0 ]
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
