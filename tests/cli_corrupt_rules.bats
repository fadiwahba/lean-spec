#!/usr/bin/env bats
# CONSTITUTION principle 8 (fail loudly): a rules.toml whose TOP-LEVEL key is
# the wrong container type (e.g. required_sections = "foo" instead of a table)
# must produce a one-line actionable error, never a raw Python traceback from
# the .update() call in load_rules.

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

write_rules() {
  mkdir -p .lean-spec
  cat > .lean-spec/rules.toml
}

@test "required_sections as a string fails loudly, no traceback" {
  write_rules <<'EOF'
required_sections = "foo"
EOF
  lean_spec validate demo spec.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"rules.toml"* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "defaults as a scalar fails loudly, no traceback" {
  write_rules <<'EOF'
defaults = 5
EOF
  lean_spec validate demo spec.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"rules.toml"* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "max_tokens as an array fails loudly, no traceback" {
  write_rules <<'EOF'
max_tokens = [1, 2]
EOF
  lean_spec validate demo spec.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"rules.toml"* ]]
  [[ "$output" != *"Traceback"* ]]
}
