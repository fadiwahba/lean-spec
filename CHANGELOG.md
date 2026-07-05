# Changelog

All notable changes to lean-spec are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-07-05

### Added

- `/lean-spec:auto-all` gets an opt-in `--no-confirm` flag (plus an
  optional `--max-features=N` cap): when no non-closed feature remains
  (mid-run, or a cold start on a project with zero specced features),
  it chains into
  `/lean-spec:spec --no-confirm` instead of stopping, so a small/simple
  PRD can be spec+built hands-off from a single command. Specs are
  still written strictly one at a time, grounded in real closed-slice
  ACs (R8 unchanged) — this automates the confirmation cadence between
  slices, not upfront batch decomposition. The architect signals "no
  PRD scope remains" via a `NO_REMAINING_SCOPE` sentinel, parsed
  fail-safe (any unparseable response stops the chain rather than
  retrying).

## [1.1.0] - 2026-07-05

### Added

- `bin/lean-spec validate --project` now rejects a section whose body is
  still just the template's HTML-comment placeholder (previously it only
  checked that the `## ` heading existed, so a freshly-`init`ed skeleton
  passed clean).
- `/lean-spec:spec` fail-loud-preflights `docs/PRD.md` and
  `docs/CONSTITUTION.md` via `validate --project` before proposing or
  writing any spec — closes the brownfield gap where a user could
  `init` then jump straight to `spec` (or use lean-spec in an existing
  repo that never ran `plan`), feeding the architect an empty or
  placeholder PRD/Constitution.
- `/lean-spec:plan`'s interview now grounds itself in the existing repo
  (manifests, test/CI config, README, `git log`) before asking, proposing
  `Stack`/`Principles`/`Delegation` pre-filled for confirmation instead of
  interviewing a brownfield codebase as if it were greenfield.

## [1.0.1] - 2026-07-04

### Fixed

- `Stop` auto-driver: the block reason told the model to "run" a skill
  that has `disable-model-invocation: true`, a dead end it has no tool
  path for. It now points at the actual `skills/<name>/SKILL.md` to
  reread and follow by hand. Also drops `ensure_ascii` so a non-ASCII
  plugin install path can't reintroduce backslash escapes into the JSON
  reason.
- `/lean-spec:plan`: the interview now asks about TDD explicitly and
  syncs `.lean-spec/rules.toml`'s `tdd` flag in the same step, instead of
  letting the Constitution's Quality Bar contradict the CLI-enforced
  default until a coder cycle discovers it mid-implementation.
- `/lean-spec:close`: corrected step 3's wording, which conflated the
  no-op `--gates-on` flag with `auto-all`'s actual chaining (`chain_all`)
  and implied plain `/lean-spec:auto` keeps going after a close (it
  always stops there).

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

[Unreleased]: https://github.com/fadiwahba/lean-spec/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/fadiwahba/lean-spec/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/fadiwahba/lean-spec/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/fadiwahba/lean-spec/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/fadiwahba/lean-spec/releases/tag/v1.0.0
