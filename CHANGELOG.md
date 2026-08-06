# Changelog

All notable changes to lean-spec are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`bin/lean-spec auto arm|disarm|status`** — a CLI writer for
  `.lean-spec/auto.json`, mirroring what `ensure`/`advance` are to
  `workflow.json`. `arm` owns the schema, defaults, validation (unknown
  slug, bad flags, `--max-cycles`/`--max-features` bounds,
  `--no-confirm` requires `--chain-all`) and the atomic write, and
  records `armed_by`/`armed_at` provenance. `status [--json]` reports
  whether a run is armed.

### Fixed

- **`.lean-spec/auto.json` could be written by the model, self-granting
  the authorization every mutating phase skill withholds via
  `disable-model-invocation: true`** ([#21]). The file was protected only
  by prose in a hook *message* — the same channel the model was expected
  to obey — and was observed being self-armed, self-disarmed, and written
  on the very poke that forbade it. `hooks/pre-tool-use-guard.sh` now
  denies `Write`/`Edit`/`MultiEdit`/`NotebookEdit` on it (path-normalized
  and case-insensitive, like the `workflow.json` rule) with a deny message
  naming the CLI remedy, and both `auto` skills now invoke
  `bin/lean-spec auto arm` instead of describing a file write — removing
  the discretion rather than policing it.

### Changed

- CONSTITUTION principle 2 now covers `.lean-spec/auto.json` alongside
  `features/*/workflow.json`, plus a new **"Known gap"** section stating
  plainly what this guard does and does not do: it closes the path a
  drifting model actually takes, but arming is not unforgeable (Bash is
  ungated, and nothing in-process can distinguish a human-invoked
  `/lean-spec:auto` from an unprompted `auto arm`). Deletes are
  deliberately not denied — disarming fails safe.
- The `spec_next` driver poke now points at `bin/lean-spec auto
  arm|disarm` instead of issuing an unenforceable "do not touch this file".

[#21]: https://github.com/fadiwahba/lean-spec/issues/21

## [1.4.0] - 2026-07-07

### Added

- `/lean-spec:help` — a read-only, model-invocable onboarding skill that
  prints the lifecycle and every skill grouped by setup / per-feature /
  hands-free / read-only, with when to use each. New users type
  `/lean-spec:help` for a single "what is this and how do I use it"
  overview, without leaving Claude Code.

### Changed

- README gained a full **Command reference** table (what each skill does
  and when to use it), and the `docs/superpowers/` brainstorm/plan scratch
  directory was removed. PRD/CONSTITUTION refreshed to current reality
  (R18 hardening decisions, `--tdd/--no-tdd` persistence, the NEEDS_FIXES
  fix-loop gate).

## [1.3.0] - 2026-07-07

Hardening release from a from-scratch deep review (four parallel
adversarial reviewers) plus two rounds of Opus/xhigh whole-branch review.
32 new tests; full suite 219 green.

### Fixed

- **Enforcement fail-open**: all three hooks caught only
  `JSONDecodeError`, so valid-but-non-object JSON (a bare array/scalar
  payload or state file) crashed them uncaught — the PreToolUse guard and
  SubagentStop gate silently skipped enforcement, the Stop driver died.
  Every parsed payload / `auto.json` / `workflow.json` is now
  `isinstance`-guarded.
- **Guard bypass**: the `pre-tool-use-guard` `workflow.json` regex matched
  the literal path with no normalization, so `Workflow.json` on a
  case-preserving filesystem (APFS) and `../`-traversal paths dodged it.
  Now `os.path.normpath` + `re.IGNORECASE`.
- **Raw tracebacks on corrupt input**: a wrong-typed `rules.toml`
  container (`required_sections = "foo"`), a non-list `workflow.json`
  history, a non-boolean `defaults.tdd`, or an invalid
  `defaults.required_verdict` now fail loudly with a one-line message
  (CONSTITUTION principle 8) instead of a Python traceback.
- **`/lean-spec:implement --no-tdd` was a dead end**: the documented
  spike opt-out produced a `notes.md` the CLI gate then rejected (it read
  only the global `rules.toml` default). The decision now persists
  per-feature in `workflow.json` (`advance --tdd/--no-tdd`) and `validate`
  honors it.
- **Ungated fix loop**: `reviewing → implementing` had no gate at all;
  it now requires `review.md` verdict `NEEDS_FIXES` (APPROVE routes to
  close, BLOCKED stops the line).
- **Permissions downgrade**: `atomic_write_json` silently reset
  `workflow.json` to owner-only (`600`) on every advance; it now
  preserves an existing file's mode and honors umask for new files.

### Changed

- `bin/lean-spec advance` accepts `--tdd` / `--no-tdd` to record a
  per-feature TDD override in `workflow.json`.
- `cmd_advance`'s read-modify-write is serialized with an `fcntl` advisory
  lock, so concurrent advances on one slug can't clobber each other's
  history.
- Docs de-drifted: README documents `auto-all --no-confirm`/`--max-features`
  and marks 1.0 shipped; PRD status is APPROVED/shipped; CONSTITUTION adds
  `spec`/`review` to the commit-type list and states the test-coverage bar
  truthfully; the reviewer `--visual` docs match the agent's actual
  (Bash-only) tool grant.

## [1.2.1] - 2026-07-06

### Changed

- Cosmetic: `agents/coder.md` color cyan → yellow, `agents/reviewer.md`
  color red → purple.

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

### Fixed

- The `--no-confirm` cold-start clause (a project with zero specced
  features) skipped `/lean-spec:spec`'s mandatory preflight (R15), the
  one entry point where the PRD is most likely still an unfilled
  `/lean-spec:init` skeleton. It now runs the preflight first, same as
  `/lean-spec:spec` would.

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

[Unreleased]: https://github.com/fadiwahba/lean-spec/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/fadiwahba/lean-spec/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/fadiwahba/lean-spec/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/fadiwahba/lean-spec/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/fadiwahba/lean-spec/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/fadiwahba/lean-spec/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/fadiwahba/lean-spec/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/fadiwahba/lean-spec/releases/tag/v1.0.0
