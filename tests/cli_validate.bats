#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
  lean_spec ensure demo
}

teardown() {
  lean_spec_teardown_repo
}

write_rules() {
  mkdir -p .lean-spec
  cat > .lean-spec/rules.toml
}

@test "validate fails loudly when artifact file is missing" {
  lean_spec validate demo spec.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "validate passes with no rules.toml (zero-config enforces nothing but TDD default)" {
  lean_spec_write_artifact demo spec.md <<'EOF'
# spec
EOF
  lean_spec validate demo spec.md
  [ "$status" -eq 0 ]
}

@test "validate enforces required_sections from rules.toml" {
  write_rules <<'EOF'
[required_sections]
"spec.md" = ["Scope", "Acceptance Criteria"]
EOF
  lean_spec_write_artifact demo spec.md <<'EOF'
# spec
## Scope
hello
EOF
  lean_spec validate demo spec.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"Acceptance Criteria"* ]]
}

@test "validate passes when all required_sections present" {
  write_rules <<'EOF'
[required_sections]
"spec.md" = ["Scope", "Acceptance Criteria"]
EOF
  lean_spec_write_artifact demo spec.md <<'EOF'
# spec
## Scope
hello
## Acceptance Criteria
1. thing
EOF
  lean_spec validate demo spec.md
  [ "$status" -eq 0 ]
}

@test "validate enforces max_tokens cap" {
  write_rules <<'EOF'
[max_tokens]
"spec.md" = 3
EOF
  lean_spec_write_artifact demo spec.md <<'EOF'
one two three four five
EOF
  lean_spec validate demo spec.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"max_tokens"* ]]
}

@test "validate passes when under max_tokens cap" {
  write_rules <<'EOF'
[max_tokens]
"spec.md" = 100
EOF
  lean_spec_write_artifact demo spec.md <<'EOF'
short spec
EOF
  lean_spec validate demo spec.md
  [ "$status" -eq 0 ]
}

@test "validate review.md requires a verdict line" {
  lean_spec_write_artifact demo review.md <<'EOF'
# review
no verdict here
EOF
  lean_spec validate demo review.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"verdict"* ]]
}

@test "validate review.md accepts verdict: APPROVE" {
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: APPROVE
EOF
  lean_spec validate demo review.md
  [ "$status" -eq 0 ]
}

@test "validate review.md accepts verdict: NEEDS_FIXES" {
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: NEEDS_FIXES
EOF
  lean_spec validate demo review.md
  [ "$status" -eq 0 ]
}

@test "validate review.md accepts verdict: BLOCKED" {
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: BLOCKED
EOF
  lean_spec validate demo review.md
  [ "$status" -eq 0 ]
}

@test "validate review.md rejects an invalid verdict value" {
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: MAYBE
EOF
  lean_spec validate demo review.md
  [ "$status" -eq 2 ]
}

@test "validate notes.md requires TDD section by default (tdd defaults true)" {
  lean_spec_write_artifact demo notes.md <<'EOF'
## What was built
stuff
EOF
  lean_spec validate demo notes.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"TDD"* ]]
}

@test "validate notes.md passes with TDD section present" {
  lean_spec_write_artifact demo notes.md <<'EOF'
## What was built
stuff
## TDD
red/green evidence
EOF
  lean_spec validate demo notes.md
  [ "$status" -eq 0 ]
}

@test "validate notes.md does not require TDD section when defaults.tdd = false" {
  write_rules <<'EOF'
[defaults]
tdd = false
EOF
  lean_spec_write_artifact demo notes.md <<'EOF'
## What was built
stuff
EOF
  lean_spec validate demo notes.md
  [ "$status" -eq 0 ]
}

@test "validate --project checks docs/PRD.md against baseline sections" {
  mkdir -p docs
  cat > docs/PRD.md <<'EOF'
## Problem & Users
x
## Features
x
## Constraints
x
## Quality Bar
x
## Non-Goals
x
EOF
  lean_spec validate --project PRD.md
  [ "$status" -eq 0 ]
}

@test "validate --project reports missing PRD.md sections" {
  mkdir -p docs
  cat > docs/PRD.md <<'EOF'
## Problem & Users
x
EOF
  lean_spec validate --project PRD.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"Features"* ]]
}

@test "validate --project checks docs/CONSTITUTION.md against baseline sections" {
  mkdir -p docs
  cat > docs/CONSTITUTION.md <<'EOF'
## Stack
x
## Principles
x
## Delegation
x
## Quality Bars
x
## Process
x
## Non-Goals
x
EOF
  lean_spec validate --project CONSTITUTION.md
  [ "$status" -eq 0 ]
}

@test "validate rejects wrong argument count" {
  lean_spec validate demo
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "validate fails loudly on invalid TOML" {
  mkdir -p .lean-spec
  printf 'not [ valid toml\n' > .lean-spec/rules.toml
  lean_spec_write_artifact demo spec.md <<'EOF'
hi
EOF
  lean_spec validate demo spec.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"rules.toml"* ]]
}
