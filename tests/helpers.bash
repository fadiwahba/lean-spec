#!/usr/bin/env bash
# Shared BATS fixtures: an isolated tmp git repo per test, plus paths to the
# plugin's CLI and hooks. Sourced by every tests/*.bats file.

# Repo root (this file lives at <root>/tests/helpers.bash).
LEAN_SPEC_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEAN_SPEC_BIN="${LEAN_SPEC_REPO_ROOT}/bin/lean-spec"
LEAN_SPEC_HOOKS="${LEAN_SPEC_REPO_ROOT}/hooks"

# Create a fresh tmp git repo and cd into it. Sets LEAN_SPEC_TESTDIR for
# teardown. Uses the mktemp X-suffix pattern for macOS/Linux portability.
lean_spec_setup_repo() {
  LEAN_SPEC_TESTDIR="$(mktemp -d "${TMPDIR:-/tmp}/lean-spec-testXXXXXX")"
  cd "${LEAN_SPEC_TESTDIR}" || return 1
  git init -q
  git config user.email "test@example.com"
  git config user.name "test"
}

lean_spec_teardown_repo() {
  if [ -n "${LEAN_SPEC_TESTDIR:-}" ] && [ -d "${LEAN_SPEC_TESTDIR}" ]; then
    cd "${LEAN_SPEC_REPO_ROOT}" || true
    rm -rf "${LEAN_SPEC_TESTDIR}"
  fi
}

# Run bin/lean-spec with args, capturing $status/$output (bats-support style
# is not vendored, so we roll a tiny `run` wrapper using bats' built-in run).
lean_spec() {
  run "${LEAN_SPEC_BIN}" "$@"
}

# Write features/<slug>/<artifact> with the given heredoc-piped content.
# Usage: lean_spec_write_artifact demo spec.md <<'EOF' ... EOF
lean_spec_write_artifact() {
  local slug="$1" artifact="$2"
  mkdir -p "features/${slug}"
  cat > "features/${slug}/${artifact}"
}
