#!/usr/bin/env bash
# scripts/lib/demo-lifecycle.sh — shared fixture-writing helpers for the F9
# end-to-end demo: scripts/demo.sh (human-run) and tests/e2e_lifecycle.bats
# (CI-run) both source this file so the two stay in sync (DRY).
#
# Layer rule (docs/CONSTITUTION.md): this file only ever writes artifact
# *content* — the "model" side of the lifecycle (docs/PRD.md,
# docs/CONSTITUTION.md, spec.md, notes.md, review.md), simulated from the
# static fixture at tests/fixtures/demo-project/ instead of a live model
# dispatch. It never touches workflow.json and never calls bin/lean-spec —
# driving the CLI + hooks is the caller's job, so state mutation always goes
# through the real state CLI, exactly as a real skill dispatch would.
#
# Meant to be `source`d, not executed directly.

DEMO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_REPO_ROOT="$(cd "${DEMO_LIB_DIR}/../.." && pwd)"
DEMO_FIXTURE_DIR="${DEMO_REPO_ROOT}/tests/fixtures/demo-project"
DEMO_SLUG="hello-cli"

# Scaffold .lean-spec/rules.toml + docs/{PRD,CONSTITUTION}.md into
# <target_root>, as /lean-spec:init + a completed /lean-spec:plan interview
# would leave a project. The "interview" itself is simulated: the fixture
# docs are already-answered output, copied in rather than asked for.
demo_scaffold_project() {
  local target_root="$1"
  mkdir -p "${target_root}/.lean-spec" "${target_root}/docs" "${target_root}/features"
  cp "${DEMO_REPO_ROOT}/examples/rules.toml" "${target_root}/.lean-spec/rules.toml"
  cp "${DEMO_FIXTURE_DIR}/docs/PRD.md" "${target_root}/docs/PRD.md"
  cp "${DEMO_FIXTURE_DIR}/docs/CONSTITUTION.md" "${target_root}/docs/CONSTITUTION.md"
}

# Simulate the architect agent: write features/<slug>/spec.md.
demo_write_spec() {
  local target_root="$1" slug="$2"
  mkdir -p "${target_root}/features/${slug}"
  cp "${DEMO_FIXTURE_DIR}/features/${DEMO_SLUG}/spec.md" "${target_root}/features/${slug}/spec.md"
}

# Simulate the coder agent: write features/<slug>/notes.md (with the
# required ## TDD evidence section).
demo_write_notes() {
  local target_root="$1" slug="$2"
  mkdir -p "${target_root}/features/${slug}"
  cp "${DEMO_FIXTURE_DIR}/features/${DEMO_SLUG}/notes.md" "${target_root}/features/${slug}/notes.md"
}

# Simulate the reviewer agent: write features/<slug>/review.md with the
# given verdict (default APPROVE). Reuses the fixture's Spec
# Compliance/Code Quality prose; only the verdict line is substituted, so
# a NEEDS_FIXES/BLOCKED demo run doesn't need its own fixture copy.
demo_write_review() {
  local target_root="$1" slug="$2" verdict="${3:-APPROVE}"
  mkdir -p "${target_root}/features/${slug}"
  sed "s/^verdict: .*/verdict: ${verdict}/" \
    "${DEMO_FIXTURE_DIR}/features/${DEMO_SLUG}/review.md" \
    > "${target_root}/features/${slug}/review.md"
}

# Feed a hook synthetic stdin JSON exactly as Claude Code's harness would.
# Prints the hook's stdout; caller inspects $? and output.
demo_run_hook() {
  local hook="$1" payload="$2"
  printf '%s' "$payload" | bash "${DEMO_REPO_ROOT}/hooks/${hook}"
}
