# Changelog

All notable changes to lean-spec are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-07-04

First public release. Requires **Claude Code ≥ 2.1.198**, **Python 3 ≥ 3.11**
(stdlib only), **bash**, and **git**.

### Added

- **State CLI** (`bin/lean-spec`, python3 stdlib only) — the single writer of
  `features/<slug>/workflow.json`: `ensure`, `advance`, `assert`, `validate`,
  `next`, `status`. Atomic transitions (tmp + `os.replace`) with a post-advance
  assertion, fail-loud preflights, and additive `rules.toml` (TOML) validation.
- **Enforcement hooks** — a `PreToolUse` guard that blocks direct
  `workflow.json` edits, a `SubagentStop` artifact gate, and a `Stop`
  auto-driver for `/lean-spec:auto` and `/lean-spec:auto-all`.
- **Lifecycle skills** — `init`, `plan`, `spec`, `respec`, `implement`,
  `review` (incl. `--visual`), `fix`, `close`, `auto`, `auto-all`, `next`,
  `status`.
- **Agents** — `architect` (Opus · xhigh), `coder` (Sonnet · high, TDD), and
  `reviewer` (Opus · high), each constrained to its one artifact.
- **TDD by default** — RED/GREEN evidence captured in `notes.md`; `review` is
  blocked without it.
- **End-to-end demo** — `scripts/demo.sh` and `tests/e2e_lifecycle.bats` drive
  a fixture project through the full lifecycle against the real CLI + hooks
  with no live-model calls.
- **CI** — BATS suite on Ubuntu and macOS, with a `bash -n` lint under the
  system `/bin/bash` (bash 3.2 on macOS) to enforce the portability bar.
- **Marketplace manifest** (`.claude-plugin/marketplace.json`) for
  `/plugin marketplace add` installation.

### Security

- Slug inputs are validated to prevent path traversal / absolute-path writes.
- The `PreToolUse` guard reads its payload from stdin so large writes cannot
  make it fail open.

[Unreleased]: https://github.com/fadiwahba/lean-spec/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/fadiwahba/lean-spec/releases/tag/v1.0.0
