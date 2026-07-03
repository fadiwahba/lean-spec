#!/usr/bin/env bash
# Bootstraps bats-core into .tools/ so tests/CI can run `bin/bats`.
# Fail-loud: no network, no git, no write access -> exit non-zero with an
# actionable message. Idempotent: safe to re-run once .tools/bin/bats exists.
set -euo pipefail

# Pin to a known tag for deterministic CI; override with BATS_CORE_VERSION
# (e.g. BATS_CORE_VERSION=v1.11.0 ./scripts/bootstrap-bats.sh).
BATS_CORE_VERSION="${BATS_CORE_VERSION:-v1.13.0}"

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tools_dir="${root_dir}/.tools"
bats_src="${tools_dir}/bats-core"
bin_dir="${tools_dir}/bin"

if [ -x "${bin_dir}/bats" ]; then
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "bootstrap-bats: git not found on PATH — install git to bootstrap the test harness" >&2
  exit 1
fi

mkdir -p "${tools_dir}" "${bin_dir}"

if [ ! -d "${bats_src}" ]; then
  if ! git clone --branch "$BATS_CORE_VERSION" --depth 1 https://github.com/bats-core/bats-core "${bats_src}" >&2; then
    echo "bootstrap-bats: failed to clone bats-core@${BATS_CORE_VERSION} — check network access to github.com or BATS_CORE_VERSION" >&2
    exit 1
  fi
fi

if [ ! -x "${bats_src}/bin/bats" ]; then
  echo "bootstrap-bats: clone at ${bats_src} is missing bin/bats — remove the directory and retry" >&2
  exit 1
fi

ln -sf "${bats_src}/bin/bats" "${bin_dir}/bats"

if ! "${bin_dir}/bats" --version >/dev/null 2>&1; then
  echo "bootstrap-bats: ${bin_dir}/bats --version failed after install" >&2
  exit 1
fi

echo "bootstrap-bats: ready ($(${bin_dir}/bats --version))"
