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

@test "validate review.md accepts verdict: APPROVE with trailing text on the line" {
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: APPROVE (all ACs met)
EOF
  lean_spec validate demo review.md
  [ "$status" -eq 0 ]
}

@test "validate review.md rejects the typo verdict: APPROVED (not a valid token)" {
  lean_spec_write_artifact demo review.md <<'EOF'
verdict: APPROVED
EOF
  lean_spec validate demo review.md
  [ "$status" -eq 2 ]
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

@test "validate --project checks .lean-spec/PRD.md against baseline sections" {
  mkdir -p docs
  cat > .lean-spec/PRD.md <<'EOF'
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
  cat > .lean-spec/PRD.md <<'EOF'
## Problem & Users
x
EOF
  lean_spec validate --project PRD.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"Features"* ]]
}

@test "validate --project checks .lean-spec/CONSTITUTION.md against baseline sections" {
  mkdir -p docs
  cat > .lean-spec/CONSTITUTION.md <<'EOF'
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

@test "validate --project rejects an unfilled placeholder PRD.md" {
  mkdir -p docs
  cat > .lean-spec/PRD.md <<'EOF'
## Problem & Users
<!-- Who has this problem, why now. -->
## Features
<!-- The feature list. -->
## Constraints
<!-- Non-negotiables. -->
## Quality Bar
<!-- What "done" means. -->
## Non-Goals
<!-- Explicitly out of scope. -->
EOF
  lean_spec validate --project PRD.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"placeholder"* ]]
}

@test "validate --project rejects a partially-filled PRD.md" {
  mkdir -p docs
  cat > .lean-spec/PRD.md <<'EOF'
## Problem & Users
Real users hit a real problem.
## Features
<!-- The feature list. -->
## Constraints
<!-- Non-negotiables. -->
## Quality Bar
<!-- What "done" means. -->
## Non-Goals
<!-- Explicitly out of scope. -->
EOF
  lean_spec validate --project PRD.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"Features"* ]]
}

@test "validate --project rejects an unfilled CONSTITUTION.md" {
  mkdir -p docs
  cat > .lean-spec/CONSTITUTION.md <<'EOF'
## Stack
<!-- Languages, frameworks. -->
## Principles
<!-- Non-negotiable rules. -->
## Delegation
<!-- Who owns which phase. -->
## Quality Bars
<!-- Test coverage expectations. -->
## Process
<!-- Commit conventions. -->
## Non-Goals
<!-- Things this project will not build. -->
EOF
  lean_spec validate --project CONSTITUTION.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"placeholder"* ]]
}

@test "validate --project treats a whitespace-only section as unfilled" {
  mkdir -p docs
  cat > .lean-spec/PRD.md <<'EOF'
## Problem & Users

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
  [ "$status" -eq 2 ]
  [[ "$output" == *"Problem & Users"* ]]
}

@test "validate --project passes a section that keeps the template comment and adds prose" {
  mkdir -p docs
  cat > .lean-spec/PRD.md <<'EOF'
## Problem & Users
<!-- Who has this problem, why now. -->
Real users hit a real problem.
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

@test "the copied templates fail --project until filled" {
  mkdir -p docs
  cp "${LEAN_SPEC_REPO_ROOT}/templates/PRD.md" .lean-spec/PRD.md
  cp "${LEAN_SPEC_REPO_ROOT}/templates/CONSTITUTION.md" .lean-spec/CONSTITUTION.md

  lean_spec validate --project PRD.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"placeholder"* ]]

  lean_spec validate --project CONSTITUTION.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"placeholder"* ]]
}

@test "validate rejects wrong argument count" {
  lean_spec validate demo
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "validate fails loudly (not a Python traceback) on a non-int max_tokens cap" {
  write_rules <<'EOF'
[max_tokens]
"spec.md" = "abc"
EOF
  lean_spec_write_artifact demo spec.md <<'EOF'
# spec
EOF
  lean_spec validate demo spec.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"max_tokens"* ]]
  [[ "$output" != *"Traceback"* ]]
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

@test "validate --project honors an extra required_sections entry from rules.toml" {
  mkdir -p docs .lean-spec
  cat > .lean-spec/rules.toml <<'TOML'
[required_sections]
"PRD.md" = ["Rollout"]
TOML
  cat > .lean-spec/PRD.md <<'MD'
## Problem & Users
real
## Features
real
## Constraints
real
## Quality Bar
real
## Non-Goals
real
MD
  lean_spec validate --project PRD.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"Rollout"* ]]
}
