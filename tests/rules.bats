#!/usr/bin/env bats
#
# rules.bats — verify lib/rules.sh enforces .lean-spec/rules.yaml correctly.
#
# Requires: bats, python3 (PyYAML), jq, awk, grep, wc.

setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TMP="$(mktemp -d)"
  cd "$TMP"
  mkdir -p .lean-spec features/feat
  export LEAN_SPEC_RULES_PATH=".lean-spec/rules.yaml"

  # shellcheck disable=SC1091
  source "$PLUGIN_ROOT/lib/rules.sh"
}

teardown() {
  rm -rf "$TMP"
}

# ---------- helpers ----------

write_rules() {
  cat > "$LEAN_SPEC_RULES_PATH"
}

write_spec() {
  cat > "features/feat/spec.md"
}

write_notes() {
  cat > "features/feat/notes.md"
}

write_review() {
  cat > "features/feat/review.md"
}

# ---------- rules_exist / rules_load ----------

@test "rules_exist is false when rules.yaml absent" {
  run rules_exist
  [ "$status" -ne 0 ]
}

@test "rules_exist is true when rules.yaml present" {
  write_rules <<'EOF'
required_verdict: APPROVE
EOF
  run rules_exist
  [ "$status" -eq 0 ]
}

@test "rules_load emits {} when rules.yaml absent" {
  run rules_load
  [ "$output" = "{}" ]
}

@test "rules_load parses YAML to JSON" {
  write_rules <<'EOF'
required_verdict: APPROVE
max_tokens:
  spec.md: 2000
EOF
  run rules_load
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.required_verdict == "APPROVE"' >/dev/null
  echo "$output" | jq -e '.max_tokens["spec.md"] == 2000' >/dev/null
}

# ---------- required_sections ----------

@test "required_sections PASS when all sections present" {
  write_rules <<'EOF'
required_sections:
  spec.md: ["Scope", "Acceptance Criteria"]
EOF
  write_spec <<'EOF'
# Feature

## Scope
Stuff.

## Acceptance Criteria
- [ ] AC1
EOF
  RULES=$(rules_load)
  run validate_required_sections "$RULES" "spec.md" "features/feat/spec.md"
  [ "$status" -eq 0 ]
}

@test "required_sections FAIL when a section is missing" {
  write_rules <<'EOF'
required_sections:
  spec.md: ["Scope", "Acceptance Criteria", "Out of Scope"]
EOF
  write_spec <<'EOF'
# Feature

## Scope
Stuff.

## Acceptance Criteria
- [ ] AC1
EOF
  RULES=$(rules_load)
  run validate_required_sections "$RULES" "spec.md" "features/feat/spec.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Out of Scope"* ]]
}

@test "required_sections PASS when no rule configured for that artifact type" {
  write_rules <<'EOF'
required_sections:
  notes.md: ["What was built"]
EOF
  write_spec <<'EOF'
# anything
EOF
  RULES=$(rules_load)
  run validate_required_sections "$RULES" "spec.md" "features/feat/spec.md"
  [ "$status" -eq 0 ]
}

@test "required_sections matches headings case-insensitively" {
  write_rules <<'EOF'
required_sections:
  spec.md: ["acceptance criteria"]
EOF
  write_spec <<'EOF'
## Acceptance Criteria
- [ ] AC1
EOF
  RULES=$(rules_load)
  run validate_required_sections "$RULES" "spec.md" "features/feat/spec.md"
  [ "$status" -eq 0 ]
}

# ---------- max_tokens ----------

@test "max_tokens PASS for a short file" {
  write_rules <<'EOF'
max_tokens:
  spec.md: 2000
EOF
  write_spec <<'EOF'
Tiny file.
EOF
  RULES=$(rules_load)
  run validate_max_tokens "$RULES" "spec.md" "features/feat/spec.md"
  [ "$status" -eq 0 ]
}

@test "max_tokens FAIL when file exceeds budget" {
  write_rules <<'EOF'
max_tokens:
  spec.md: 10    # absurdly tiny so any non-empty file trips it
EOF
  # 200 chars → ~50 tokens, exceeds 10
  python3 -c "print('x' * 200)" > features/feat/spec.md
  RULES=$(rules_load)
  run validate_max_tokens "$RULES" "spec.md" "features/feat/spec.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"max_tokens.spec.md=10"* ]]
}

@test "max_tokens PASS when no rule configured" {
  write_rules <<'EOF'
required_verdict: APPROVE
EOF
  python3 -c "print('x' * 200)" > features/feat/spec.md
  RULES=$(rules_load)
  run validate_max_tokens "$RULES" "spec.md" "features/feat/spec.md"
  [ "$status" -eq 0 ]
}

# ---------- required_verdict ----------

@test "required_verdict PASS when review has the required verdict" {
  write_rules <<'EOF'
required_verdict: APPROVE
EOF
  write_review <<'EOF'
---
slug: feat
phase: reviewing
verdict: APPROVE
---

# Review
EOF
  RULES=$(rules_load)
  run validate_verdict "$RULES" "review.md" "features/feat/review.md"
  [ "$status" -eq 0 ]
}

@test "required_verdict FAIL when review has NEEDS_FIXES" {
  write_rules <<'EOF'
required_verdict: APPROVE
EOF
  write_review <<'EOF'
---
verdict: NEEDS_FIXES
---
EOF
  RULES=$(rules_load)
  run validate_verdict "$RULES" "review.md" "features/feat/review.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"NEEDS_FIXES"* ]]
}

@test "required_verdict only applies to review.md (no-op for spec.md)" {
  write_rules <<'EOF'
required_verdict: APPROVE
EOF
  write_spec <<'EOF'
# spec with no verdict field
EOF
  RULES=$(rules_load)
  run validate_verdict "$RULES" "spec.md" "features/feat/spec.md"
  [ "$status" -eq 0 ]
}

# ---------- require_line_references ----------

@test "require_line_references PASS when file has backticked file:line" {
  write_rules <<'EOF'
require_line_references:
  review.md: true
EOF
  write_review <<'EOF'
# Review

- Issue at \`src/foo.ts:42\`
EOF
  RULES=$(rules_load)
  run validate_line_references "$RULES" "review.md" "features/feat/review.md"
  [ "$status" -eq 0 ]
}

@test "require_line_references FAIL when no backticked file:line anywhere" {
  write_rules <<'EOF'
require_line_references:
  review.md: true
EOF
  write_review <<'EOF'
# Review

Some prose without any citations.
EOF
  RULES=$(rules_load)
  run validate_line_references "$RULES" "review.md" "features/feat/review.md"
  [ "$status" -eq 1 ]
}

@test "require_line_references PASS when rule is false" {
  write_rules <<'EOF'
require_line_references:
  review.md: false
EOF
  write_review <<'EOF'
# Review
no refs
EOF
  RULES=$(rules_load)
  run validate_line_references "$RULES" "review.md" "features/feat/review.md"
  [ "$status" -eq 0 ]
}

# ---------- rules_enforce (aggregator) ----------

@test "rules_enforce PASS when no rules.yaml exists" {
  # no rules file
  run rules_enforce "spec.md" "features/feat/spec.md"
  [ "$status" -eq 0 ]
}

@test "rules_enforce PASS with valid artifact" {
  write_rules <<'EOF'
required_sections:
  spec.md: ["Scope"]
max_tokens:
  spec.md: 2000
EOF
  write_spec <<'EOF'
## Scope
Tiny.
EOF
  run rules_enforce "spec.md" "features/feat/spec.md"
  [ "$status" -eq 0 ]
}

@test "rules_enforce FAIL surfaces multiple violations together" {
  write_rules <<'EOF'
required_sections:
  spec.md: ["Scope", "Acceptance Criteria"]
max_tokens:
  spec.md: 2
EOF
  # Missing Acceptance Criteria AND exceeds token budget
  python3 -c "print('## Scope\n\n' + 'x' * 100)" > features/feat/spec.md
  run rules_enforce "spec.md" "features/feat/spec.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Acceptance Criteria"* ]]
  [[ "$output" == *"max_tokens"* ]]
}

@test "rules_enforce ties verdict + section rules together for review.md" {
  write_rules <<'EOF'
required_verdict: APPROVE
required_sections:
  review.md: ["Spec Compliance"]
EOF
  write_review <<'EOF'
---
verdict: NEEDS_FIXES
---

# Review

No Spec Compliance section.
EOF
  run rules_enforce "review.md" "features/feat/review.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verdict"* ]]
  [[ "$output" == *"Spec Compliance"* ]]
}
