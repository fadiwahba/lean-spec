#!/usr/bin/env bash
# scripts/demo.sh — F9 runnable end-to-end demo (PRD §11, M3).
#
# Drives a real throwaway temp project through the full lean-spec lifecycle
# — interview(simulated) -> spec -> implement -> review -> closed — against
# the REAL bin/lean-spec CLI and REAL hooks, printing each phase transition
# and the final status so a human can watch it happen.
#
# No live model: the model-driven artifacts (docs/PRD.md,
# docs/CONSTITUTION.md, spec.md, notes.md, review.md) are simulated fixture
# content from tests/fixtures/demo-project/, via the same helpers
# (scripts/lib/demo-lifecycle.sh) that tests/e2e_lifecycle.bats uses — the
# two stay in sync by construction (DRY). This script is a human-watchable
# walkthrough, not the correctness proof; tests/e2e_lifecycle.bats is.
#
# Usage: ./scripts/demo.sh
set -euo pipefail

demo_fail() {
  echo "demo: $1" >&2
  exit 1
}

# --- Preflight (fail-loud; CONSTITUTION principle 8) ------------------------

command -v python3 >/dev/null 2>&1 \
  || demo_fail "python3 not found on PATH — install python3 >= 3.11 and retry"

python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' \
  || demo_fail "python3 >= 3.11 required (found $(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])')) — install a newer python3 and retry"

command -v git >/dev/null 2>&1 \
  || demo_fail "git not found on PATH — install git and retry"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEAN_SPEC="${REPO_ROOT}/bin/lean-spec"
LIB="${REPO_ROOT}/scripts/lib/demo-lifecycle.sh"

[ -x "${LEAN_SPEC}" ] || demo_fail "bin/lean-spec not found or not executable at ${LEAN_SPEC}"
[ -f "${LIB}" ] || demo_fail "missing ${LIB} — this demo cannot run without the shared fixture helpers"

# shellcheck source=lib/demo-lifecycle.sh
source "${LIB}"

# --- Throwaway temp project --------------------------------------------------

TMP_PROJECT="$(mktemp -d "${TMPDIR:-/tmp}/lean-spec-demoXXXXXX")" \
  || demo_fail "could not create a temp directory (checked \${TMPDIR:-/tmp})"

cleanup() {
  rm -rf "${TMP_PROJECT}"
}
trap cleanup EXIT

cd "${TMP_PROJECT}"
git init -q
git config user.email "demo@example.com"
git config user.name "lean-spec demo"

SLUG="${DEMO_SLUG}"

step() {
  printf '\n=== %s ===\n' "$1"
}

echo "lean-spec F9 demo — driving '${SLUG}' through the full lifecycle"
echo "temp project: ${TMP_PROJECT} (removed on exit)"

# --- init + plan (simulated interview) ---------------------------------------

step "init: scaffold .lean-spec/rules.toml + docs/ (as /lean-spec:init would)"
demo_scaffold_project "${TMP_PROJECT}"
echo "wrote .lean-spec/rules.toml, docs/PRD.md, docs/CONSTITUTION.md"

step "plan (simulated): validate the interview output — no live model"
"${LEAN_SPEC}" validate --project PRD.md
"${LEAN_SPEC}" validate --project CONSTITUTION.md

# --- spec ---------------------------------------------------------------------

step "spec: ensure '${SLUG}' (phase -> specifying)"
"${LEAN_SPEC}" ensure "${SLUG}"
"${LEAN_SPEC}" status "${SLUG}"

step "spec: architect writes spec.md (simulated)"
demo_write_spec "${TMP_PROJECT}" "${SLUG}"
"${LEAN_SPEC}" validate "${SLUG}" spec.md
demo_run_hook subagent-stop-gate.sh '{}' && echo "SubagentStop gate: allowed"

step "advance specifying -> implementing"
"${LEAN_SPEC}" advance "${SLUG}" specifying implementing
"${LEAN_SPEC}" status "${SLUG}"

# --- implement ------------------------------------------------------------

step "implement: coder writes notes.md with TDD evidence (simulated)"
demo_write_notes "${TMP_PROJECT}" "${SLUG}"
"${LEAN_SPEC}" validate "${SLUG}" notes.md
demo_run_hook subagent-stop-gate.sh '{}' && echo "SubagentStop gate: allowed"

step "advance implementing -> reviewing"
"${LEAN_SPEC}" advance "${SLUG}" implementing reviewing
"${LEAN_SPEC}" status "${SLUG}"

# --- review -----------------------------------------------------------------

step "review: reviewer writes review.md, verdict APPROVE (simulated)"
demo_write_review "${TMP_PROJECT}" "${SLUG}" APPROVE
"${LEAN_SPEC}" validate "${SLUG}" review.md
demo_run_hook subagent-stop-gate.sh '{}' && echo "SubagentStop gate: allowed"

step "next: resolve the next step from state"
"${LEAN_SPEC}" next "${SLUG}"

# --- close --------------------------------------------------------------------

step "close: advance reviewing -> closed (CLI enforces verdict: APPROVE)"
"${LEAN_SPEC}" advance "${SLUG}" reviewing closed
"${LEAN_SPEC}" status "${SLUG}"

step "final status"
"${LEAN_SPEC}" status "${SLUG}" --json

echo
echo "demo complete: '${SLUG}' reached 'closed' via the real CLI + hooks, zero live model calls."

# --- bonus: prove the gates bite (a rejected close + a denied hand-edit) -----

step "bonus: a second slice shows the gates really enforce the lifecycle"
BONUS_SLUG="second-slice"
"${LEAN_SPEC}" ensure "${BONUS_SLUG}"
demo_write_spec "${TMP_PROJECT}" "${BONUS_SLUG}"
"${LEAN_SPEC}" advance "${BONUS_SLUG}" specifying implementing

echo "-- attempting a hand-edit of workflow.json mid-flow (should be denied) --"
demo_run_hook pre-tool-use-guard.sh \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"features/${BONUS_SLUG}/workflow.json\"}}"

demo_write_notes "${TMP_PROJECT}" "${BONUS_SLUG}"
"${LEAN_SPEC}" advance "${BONUS_SLUG}" implementing reviewing
demo_write_review "${TMP_PROJECT}" "${BONUS_SLUG}" NEEDS_FIXES

echo "-- attempting to close with a NEEDS_FIXES verdict (should be rejected) --"
if "${LEAN_SPEC}" advance "${BONUS_SLUG}" reviewing closed; then
  demo_fail "expected the close gate to reject a NEEDS_FIXES verdict, but it succeeded"
fi
echo "rejected as expected — next step:"
"${LEAN_SPEC}" next "${BONUS_SLUG}"

echo
echo "demo complete."
