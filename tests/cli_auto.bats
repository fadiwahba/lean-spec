#!/usr/bin/env bats
# `lean-spec auto arm|disarm|status` — the SINGLE writer of .lean-spec/auto.json.
# Mirrors the workflow.json discipline (CONSTITUTION principle 2): the file has a
# designated CLI writer, so the PreToolUse guard can deny model writes outright
# without breaking the product.

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

auto_field() {
  python3 -c "import json,sys; print(json.load(open('.lean-spec/auto.json')).get(sys.argv[1]))" "$1"
}

# ── arm ────────────────────────────────────────────────────────────────────

@test "auto arm writes .lean-spec/auto.json with the default shape" {
  lean_spec ensure demo
  lean_spec auto arm demo
  [ "$status" -eq 0 ]
  [ -f .lean-spec/auto.json ]
  run auto_field slug
  [ "$output" = "demo" ]
  run auto_field cycles
  [ "$output" = "0" ]
  run auto_field max_cycles
  [ "$output" = "20" ]
  run auto_field gates_on
  [ "$output" = "False" ]
}

@test "auto arm records provenance (armed_by=command + armed_at)" {
  lean_spec ensure demo
  lean_spec auto arm demo
  run auto_field armed_by
  [ "$output" = "command" ]
  run python3 -c "
import json
d = json.load(open('.lean-spec/auto.json'))
assert d['armed_at'].endswith('Z'), d['armed_at']
print('ok')
"
  [ "$output" = "ok" ]
}

@test "auto arm --gates-on sets gates_on true" {
  lean_spec ensure demo
  lean_spec auto arm demo --gates-on
  run auto_field gates_on
  [ "$output" = "True" ]
}

@test "auto arm --max-cycles=N overrides the cap" {
  lean_spec ensure demo
  lean_spec auto arm demo --max-cycles=3
  run auto_field max_cycles
  [ "$output" = "3" ]
}

@test "auto arm --chain-all sets chain_all and omits no_confirm keys" {
  lean_spec ensure demo
  lean_spec auto arm demo --chain-all
  run auto_field chain_all
  [ "$output" = "True" ]
  run python3 -c "
import json
d = json.load(open('.lean-spec/auto.json'))
assert 'no_confirm' not in d, d
assert 'max_features' not in d, d
assert 'features_specced' not in d, d
print('ok')
"
  [ "$output" = "ok" ]
}

@test "auto arm --chain-all --no-confirm adds the no-confirm bookkeeping keys" {
  lean_spec ensure demo
  lean_spec auto arm demo --chain-all --no-confirm --max-features=5
  run auto_field no_confirm
  [ "$output" = "True" ]
  run auto_field max_features
  [ "$output" = "5" ]
  run auto_field features_specced
  [ "$output" = "0" ]
}

@test "auto arm rejects an unknown slug (no such feature)" {
  lean_spec auto arm nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"no such feature"* ]]
  [ ! -f .lean-spec/auto.json ]
}

@test "auto arm rejects a traversal slug before touching disk" {
  lean_spec auto arm ../evil
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid slug"* ]]
}

@test "auto arm rejects an unknown flag (fails loudly, principle 8)" {
  lean_spec ensure demo
  lean_spec auto arm demo --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"--bogus"* ]]
}

@test "auto arm rejects a non-integer --max-cycles" {
  lean_spec ensure demo
  lean_spec auto arm demo --max-cycles=abc
  [ "$status" -ne 0 ]
  [ ! -f .lean-spec/auto.json ]
}

@test "auto arm rejects --max-cycles below 1" {
  lean_spec ensure demo
  lean_spec auto arm demo --max-cycles=0
  [ "$status" -ne 0 ]
}

@test "auto arm is idempotent-ish: re-arming resets cycles to 0" {
  lean_spec ensure demo
  lean_spec auto arm demo
  python3 -c "
import json
p = '.lean-spec/auto.json'
d = json.load(open(p)); d['cycles'] = 7
json.dump(d, open(p, 'w'))
"
  lean_spec auto arm demo
  [ "$status" -eq 0 ]
  run auto_field cycles
  [ "$output" = "0" ]
}

@test "auto arm writes atomically (no .auto tmp litter left behind)" {
  lean_spec ensure demo
  lean_spec auto arm demo
  run bash -c "ls -a .lean-spec | grep -c '^\.auto' || true"
  [ "$output" = "0" ]
}

# ── disarm ─────────────────────────────────────────────────────────────────

@test "auto disarm removes the file" {
  lean_spec ensure demo
  lean_spec auto arm demo
  lean_spec auto disarm
  [ "$status" -eq 0 ]
  [ ! -f .lean-spec/auto.json ]
}

@test "auto disarm is idempotent when nothing is armed" {
  lean_spec auto disarm
  [ "$status" -eq 0 ]
}

# ── status ─────────────────────────────────────────────────────────────────

@test "auto status reports disarmed when no auto.json exists" {
  lean_spec auto status
  [ "$status" -eq 0 ]
  [[ "$output" == *"disarmed"* ]]
}

@test "auto status --json reports armed state" {
  lean_spec ensure demo
  lean_spec auto arm demo
  lean_spec auto status --json
  [ "$status" -eq 0 ]
  run python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d['armed'] is True, d
assert d['slug'] == 'demo', d
print('ok')
" <<< "$output"
  [ "$output" = "ok" ]
}

@test "auto status does not crash on a corrupt auto.json" {
  mkdir -p .lean-spec
  echo 'not json' > .lean-spec/auto.json
  lean_spec auto status
  [ "$status" -ne 0 ]
  [[ "$output" == *"corrupt"* ]]
}

# ── dispatch ───────────────────────────────────────────────────────────────

@test "auto with no subcommand fails loudly with usage" {
  lean_spec auto
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage"* ]]
}

@test "auto with an unknown subcommand fails loudly" {
  lean_spec auto frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"frobnicate"* ]]
}

@test "auto appears in the top-level usage line" {
  lean_spec --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"auto"* ]]
}
