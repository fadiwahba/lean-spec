# Changelog

All notable changes to lean-spec are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions are [semver](https://semver.org/).

## [Unreleased]

### Added

- **M2 progress (in flight)** — `.lean-spec/rules.yaml` enforcement (F11), semi-auto next-command driver (F9), `/brainstorm` + `/decompose-prd` greenfield commands (F10).

## [0.1.1] — 2026-04-24

Post-experiment hardening. Four end-to-end experiments on a Pomodoro timer (Opus+Sonnet, Sonnet+Sonnet, Opus+Haiku, Sonnet+Sonnet retry) surfaced a set of drift vectors that are now closed. See README → "Real cost data" for the outcome metrics that justify each change.

### Added

- **`skills/writing-specs/SKILL.md`**: Visual ACs must be a numbered V1/V2/V3... table, not prose. (`#78`)
  - Experiment B showed Sonnet-authored prose AC4 left visual tokens unspecified → reviewer couldn't enforce → final render drifted from binding visual contract, but passed review. Experiment B2 with this rule applied: cycles dropped 3 → 1, zero drift.
- **`agents/coder.md`**: "Hard-forbidden edits (automatic reviewer failure)" list. (`#83`)
  - `package.json`, lockfiles (incl. `scripts` fields), framework/tool configs, root `layout.tsx` metadata, existing tests. Addresses silent scope creep surfaced across all 4 experiments.
- **`agents/coder.md`**: `fixes` mode must APPEND `## Cycle N fixes` to notes.md rather than rewriting. (`#80`)
  - Preserves per-cycle audit trail. Count existing `## Cycle \d+ fixes` headings → `N+1`.
- **`agents/reviewer.md`**: Mandatory scope-violation sweep via `git diff --name-only`. (`#83`)
- **`agents/reviewer.md`**: Archive prior `review.md` to `review-cycle-N.md` before writing new one. (`#81`)
  - `review.md` stays "latest verdict"; archives are audit-only.
- **`agents/reviewer.md`**: Playwright screenshots always saved to `.playwright-mcp/<name>.png` (explicit path). (`#82`)
- **`agents/coder.md` + `agents/reviewer.md`**: Portable dev-server lifecycle — detect existing server, start via `&`, record PID, kill process group via `ps -o pgid` on exit. Never `setsid` (Linux-only, broken on macOS). (`#79`)
- **`templates/PRD.md`**: Canonical project-PRD skeleton with Implementation Contract, Design Language, named-element features, interactions table. Validated by todo-demo and pomodoro-demo. (`§12.9`)
- **`scripts/experiment-report.sh`**: Parse `claude --output-format json` dispatches into a cost/duration/turns table + phase history. (`#84`)
- **`tests/plugin-structure.bats`**: 21 frontmatter + schema validation tests.
- **`tests/experiment-report.bats`**: 12 tests covering the cost-analysis script.
- **`CHANGELOG.md`**: this file.

### Changed

- **`README.md`**: rewritten with proper hero, quickstart, cost data from experiments, testing section, documentation index.
- **`docs/PLUGIN_DEV_GUIDE.md`**: added sections 8 (post-experiment hardening) and 9 (testing). Updated §7 common pitfalls with 4 new entries from experiment findings.
- **`docs/PRD.md`**: §12.9 resolved decision documenting the canonical PRD shape + rationale. F10 scope expanded to reference `templates/PRD.md`.

### Fixed

- **`.gitignore`**: Playwright MCP runtime artifacts (`.playwright-mcp/`), stray root-level screenshots (`/pomodoro-*.png`), `.claude/scheduled_tasks.lock`, local test tooling (`.tools/`).

## [0.1.0] — 2026-04-22

Initial v3 release. Rewrite from v2.

### Added

- **3 subagents** with frontmatter model pins: `architect` (opus), `coder` (haiku — the canonical cost-saver default), `reviewer` (opus).
- **8 commands** (lifecycle): `start-spec`, `update-spec`, `submit-implementation`, `submit-review`, `submit-fixes`, `close-spec`, `resume-spec`, `spec-status`.
- **6 hook scripts**: `session-start`, `pre-compact`, `user-prompt-submit`, `pre-tool-use-workflow`, `stop-guard`, `subagent-stop-guard`.
- **6 skills**: `using-lean-spec`, `writing-specs`, `reviewing-spec-compliance`, `reviewing-code-quality`, `reviewing-security` (optional), `reviewing-performance` (optional).
- **`.claude-plugin/plugin.json`** manifest with auto-discovery of skills/commands/agents.
- **`lib/workflow.sh`** phase-transition helpers with mandatory `mv -f` + post-advance assertion (learned from a prior silent-write bug under macOS's `rm -i` alias).
- **`tests/workflow.bats`** + **`tests/hooks.bats`**: 45 tests covering phase transitions and hook outputs.
- **Review extras pattern**: `/lean-spec:submit-review <slug> security performance` (or `full`). Extras are opt-in via `$ARGUMENTS`, never default.
- **Optional MCP integration pattern**: detect-by-attempt, never hard-fail. Playwright, context7, sequential-thinking all degrade gracefully.
- **`docs/PRD.md`**: full architectural PRD with cost-arbitrage rationale (§3.1), three-role dispatch model (§4, §12.5), cross-provider roadmap (§8, M3), and 9 resolved decisions.

### Breaking changes from v2

- v2 had two claude-code terminals (one per role); v3 uses a single session with dispatched subagents. **All v2 commands renamed** — `/approve-spec` → `/lean-spec:submit-implementation` etc. See `commands/*.md`.
- v2 artifacts (`.lean-spec/` directory at repo root) are not read by v3. A project with a v2 install should archive the directory and start fresh with `/lean-spec:start-spec`.
- `agents/*.md` are now valid Claude Code subagent definitions, not the `*-prompt.md` templates v2 used.

---

## Version policy

- **Patch (`0.x.Y`)**: post-release hardening, non-breaking doc/test additions, reviewer/coder rule tweaks that don't change command signatures.
- **Minor (`0.X.0`)**: new commands, new skills, new hooks, new agents.
- **Major (`X.0.0`)**: will be cut once the plugin is stable and we commit to backward compatibility.
