# Changelog

All notable changes to lean-spec are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions are [semver](https://semver.org/).

## [Unreleased]

## [0.4.0] — 2026-04-29

Cost-arbitrage model overrides, `/lean-spec:init`, batch speccing, visual-check decoupling, and chunky-feature decomposition guidance.

### Added

- **`models:` override block in `examples/rules.yaml`** (opt-in, commented-out) — users can set `architect`, `reviewer`, and `coder` model per-project; overrides the agent frontmatter defaults at dispatch time.
- **`/lean-spec:init`** (P13) — bootstraps `.lean-spec/rules.yaml` (from the default template) and `docs/` in one command; idempotent. Three-port: Claude `.md`, Gemini TOML, OpenCode `.md`, Codex `.md`.
- **`/lean-spec:spec-all`** (P14) — batch dispatches the architect for every feature currently in the `specifying` phase; surfaces progress without blocking the main session.
- **`/lean-spec:visual-check`** (P15) — standalone Playwright visual-fidelity command, decoupled from `submit-review`; accepts optional `--spec-sections` flag.
- **`--visual` flag on `/lean-spec:submit-review`** — visual fidelity is now opt-in (text-only by default); `--visual` re-enables Playwright in the reviewer subagent.
- **Coupling check in `/lean-spec:decompose-prd`** (P16) — before generating slugs, warns when >4 features share a state store and recommends merging into 1–3 cohesive features.
- **CSS token bootstrap AC notice in `/lean-spec:decompose-prd`** (P17) — after slug generation, scans for Tailwind `@theme inline` design token definitions and emits a mandatory AC reminder for the first feature's `spec.md`.

### Changed

- **`agents/reviewer.md`** — default model changed `opus` → `sonnet` (5× cheaper for structured AC-comparison tasks; validated in cross-provider experiment).
- **`commands/update-spec.md`, `submit-implementation.md`, `submit-fixes.md`, `submit-review.md`, `auto.md`** — each reads `models.<role>` from `.lean-spec/rules.yaml` before dispatching its subagent and passes the value as the `model` parameter to the Task tool.
- **`.claude-plugin/plugin.json`** + **`gemini-extension.json`**: version bump 0.3.6 → 0.4.0.

## [0.3.6] — 2026-04-28

Surfaced by the lean-spec-kanban greenfield experiment.

### Fixed

- **`agents/coder.md`** — Hard-forbidden edits: added explicit rule banning `features/*/` directory creation for testing/fixture purposes. Coder must write fixture data to `/tmp/lean-spec-<slug>-fixtures/` and delete it before stopping. Creating `features/test-*` or any non-spec slug under `features/` is a Critical scope violation.
- **`agents/coder.md`** — Playwright smoke-test step 8 (renumbered from 8→9): added explicit fixture cleanup step before server shutdown.

### Root cause

During the kanban-board implementation, the coder created `features/test-feature-{1,2,3,closed,unknown}/` directories in the project to smoke-test the board. These leaked into the project's `features/` directory (visible on the board itself), into the orchestrator's `result` text summary, and required manual cleanup after the feature closed.

### Changed

- **`.claude-plugin/plugin.json`** + **`gemini-extension.json`**: version bump 0.3.5 → 0.3.6.

## [0.3.5] — 2026-04-27

Same root-cause fix as v0.3.4, applied to `start-spec`.

### Fixed

- **`hooks/user-prompt-submit.sh`** — added `start-spec` handler: when `/lean-spec:start-spec <slug> [brief]` is detected, the hook validates the slug format, blocks duplicate slugs (0 model tokens burned), creates `features/<slug>/` and `workflow.json` (phase: `specifying`) using pure bash+jq, then injects `additionalContext` telling the model to dispatch the architect subagent. The model never touches the filesystem.
- **`commands/start-spec.md`** — removed the pre-flight bash block and Step 1 bash block entirely. `allowed-tools` changed from `Bash, Read, Task` to `Task, Read`. The command is now pure architect dispatch.

### Root cause

Same as v0.3.4 (`close-spec`): the model hallucinates a `lean-spec` CLI binary when it sees a bash block alongside a `/lean-spec:*` command name that matches its training-data knowledge of a lean-spec tool. Moving all filesystem operations to the hook layer eliminates the hallucination surface permanently.

### Changed

- **`.claude-plugin/plugin.json`** + **`gemini-extension.json`**: version bump 0.3.4 → 0.3.5.

## [0.3.4] — 2026-04-27

Root-cause fix for close-spec hallucination, surfaced through three failed v0.3.x attempts.

### Fixed

- **`hooks/user-prompt-submit.sh`** — added close-spec handler: when `/lean-spec:close-spec <slug>` is detected, the hook validates the APPROVE verdict and advances `workflow.json` to `closed` using pure bash+jq **before the model sees the command**. The model is only responsible for confirming the outcome to the user. This permanently eliminates the hallucination vector — the model never needs to run a bash block or touch workflow.json.
- **`commands/close-spec.md`** — reduced to pure confirmation UX (no bash block, `allowed-tools: Read` only). The hook does all state mutation; the command just tells the user what happened.

### Root cause analysis (v0.3.2 and v0.3.3 post-mortem)

The model has training-data knowledge of a `lean-spec` CLI binary. When dispatched as a standalone `claude -p` subprocess with `/lean-spec:close-spec`, it consistently attempts `lean-spec close` or `npx lean-spec close` and ignores the bash block in the command markdown — regardless of how the instructions are phrased. This is a model-training artifact, not a prompt-engineering problem. Moving the mutation to the hook layer (where it runs as a plain bash script with no model involvement) is the correct fix.

### Changed

- **`.claude-plugin/plugin.json`** + **`gemini-extension.json`**: version bump 0.3.3 → 0.3.4.

## [0.3.3] — 2026-04-27

Bug fix surfaced by M4 attended-mode experiment (empty-state feature).

### Fixed

- **`commands/close-spec.md`** — reverted `allowed-tools` from `Read, Write` back to `Bash, Read`. The v0.3.2 Write-tool approach was blocked by `hooks/pre-tool-use-workflow.sh`, which denies ALL Write/Edit calls on `features/*/workflow.json`. Replaced Write-tool instructions with an explicit `jq + mktemp + mv` bash block (same pattern as `submit-implementation.md`), with a post-advance assertion and no text that a model could interpret as a CLI invocation.

### Changed

- **`.claude-plugin/plugin.json`** + **`gemini-extension.json`**: version bump 0.3.2 → 0.3.3.

- F12 Marketplace publish (deferred by user direction — zero-refactor step whenever distribution becomes useful).

## [0.3.2] — 2026-04-27

Reliability fixes surfaced by M2 greenfield v2 experiment (todo-demo, 3 features, $14.24).

### Fixed

- **`commands/close-spec.md`** — replaced bash block entirely with Read + Write tool instructions. Removed `Bash` from `allowed-tools`. The v0.3.1 "no CLI binary" preamble was ignored by Sonnet 4.6 in all 3 close-spec dispatches; eliminating the bash execution surface removes the hallucination vector entirely.
- **`agents/reviewer.md`** — hard-prescribed `## Visual Fidelity` as the required heading (both in step guidance and the review.md template). Reviewer was consistently emitting `## Visual Review`; `rules.yaml` `required_sections` checked for `"Visual Fidelity"`; mismatch blocked every close-spec call requiring manual rename before each feature could close.

### Changed

- **`.claude-plugin/plugin.json`** + **`gemini-extension.json`**: version bump 0.3.1 → 0.3.2.

## [0.3.1] — 2026-04-27

Headless/agentic driver fixes surfaced by the M2 greenfield experiment (todo-demo, 19 dispatches, $11.15).

### Fixed

- **`commands/update-spec.md`** — accepts optional `[inline-brief]` arg (same first-token slug pattern as `start-spec`). When the brief is non-empty the orchestrator skips the "ask user" interactive step entirely, enabling headless `claude -p` subprocess invocations without hanging. Empty brief still prompts interactively.
- **`commands/close-spec.md`** — explicit "no CLI binary" preamble in Steps section. Prevents the orchestrator from hallucinating `npm install lean-spec` / `npx lean-spec` when `package.json` contains a stale lean-spec file-dep from v2 migrations.
- **`hooks/user-prompt-submit.sh`** — all three block exit paths now `echo` the block reason to stderr before emitting the JSON block decision. Headless callers (`claude -p` subprocess, `/auto` driver) can now surface the block reason from stderr instead of seeing an empty `result` with `cost: 0`.
- **`lib/rules.sh`** — `rules_load` now auto-detects `uv` and uses `uv run --quiet --with pyyaml python3` when available, falling back to bare `python3`. Makes PyYAML portable across fresh cloud sandboxes and macOS system Python (which lacks PyYAML) without requiring manual `pip install`.

### Changed

- **`.claude-plugin/plugin.json`** + **`gemini-extension.json`**: version bump 0.3.0 → 0.3.1.

## [0.3.0] — 2026-04-24

M3 (cross-provider) and M4 (auto + telemetry) land together.

### Added

**M3 — Cross-provider (Gemini, OpenCode, Codex):**

- **F13 — Gemini CLI extension.** `gemini-extension.json` manifest + `GEMINI.md` context file + 11 TOML command ports at `commands/lean-spec/*.toml` + `.gemini/INSTALL.md` + `.gemini/hooks-template.json`. Degraded mode — Gemini CLI has no subagent dispatch, so tier enforcement is unavailable there (clearly documented). `scripts/verify-gemini-commands.sh` enforces 1:1 drift protection in CI.
- **F14 — OpenCode install path.** `.opencode/agents/*.md` (4 agents with `mode:subagent` + `model:provider/id` pinning — tier enforcement WORKS here) + `.opencode/commands/lean-spec/*.md` (11) + `.opencode/INSTALL.md` with global-symlink install flow.
- **F15 — Codex install path.** `.codex/AGENTS.md` (project context) + `.codex/prompts/*.md` (11 self-contained paste-in templates) + `.codex/INSTALL.md`. Most degraded of the three hosts — no slash commands, no subagents. Lifecycle bash (phase gate + workflow.json mutation + review archival) preserved; tier enforcement unavailable.
- **F16 — Cross-provider compatibility test.** `tests/cross-provider.bats` — 9 tests verifying same `workflow.json` progressed across simulated host handoffs preserves history; each host ships exactly 11 entry points standalone; each host documents its degraded-mode caveat.

**M4 — Auto mode + telemetry:**

- **F17 — `/lean-spec:auto <slug>`.** Drives the full lifecycle using `lib/next-command.sh` as the resolver. Iterates up to 5 phases (configurable via `--max-cycles`) using the `SlashCommand` tool to dispatch each phase command. Hard-stops on `BLOCKED` verdict.
- **F18 — Human-intervention checkpoints** (integrated in auto.md). Default pauses at each phase boundary for `[yes/no]` confirmation. `--unattended` skips for CI-style runs.
- **F19 — Opt-in local telemetry.** `lib/telemetry.sh` + `commands/telemetry.md`. Opt-in via `LEAN_SPEC_TELEMETRY=1` env var or `~/.lean-spec/telemetry=on` marker file. Local-only (no network, no identity). Writes JSONL phase transitions to `~/.lean-spec/telemetry.jsonl`. Sync is idempotent via the `Stop` hook. Token counts are NOT tracked (would require wrapping the `claude` CLI — out of scope).

### Changed

- **`hooks/stop-guard.sh`**: sources `lib/telemetry.sh` and calls `telemetry_sync_all` on every Stop (no-op when telemetry disabled).
- **`docs/PRD.md`**: F13–F19 roadmap entries marked ✅ with implementation summaries.
- **`.claude-plugin/plugin.json`** + **`gemini-extension.json`**: version bump 0.2.0 → 0.3.0.

### Test suite

Grew from 137 → 188 tests. New files:
- `tests/gemini-commands.bats` (12)
- `tests/opencode-commands.bats` (10)
- `tests/codex-install.bats` (9)
- `tests/cross-provider.bats` (9)
- `tests/telemetry.bats` (11)

## [0.2.0] — 2026-04-24

M2 lands — three of its four features shipped. F12 (marketplace publish) is deferred.

### Added

- **F11 — `.lean-spec/rules.yaml` enforcement.** Four rules: `required_sections`, `max_tokens`, `required_verdict`, `require_line_references`. Enforced in `hooks/user-prompt-submit.sh` via `lib/rules.sh`. Opt-in — no rules.yaml means no enforcement. Example at `examples/rules.yaml`. 26 new tests (21 in `tests/rules.bats` + 5 in `tests/hooks.bats`).
- **F9 — Semi-auto driver.** `SessionStart` hook now surfaces phase-appropriate next commands per in-progress feature. New `/lean-spec:next` command resolves "what should I run now?" for the most-recently-updated open feature and prints a copy-pasteable line. Auto-dispatch (single-keystroke confirm) is future work — blocked on a Claude Code primitive that doesn't exist yet. Resolver is factored to `lib/next-command.sh` for reuse. 16 new tests.
- **F10 — `/brainstorm` + `/decompose-prd` greenfield commands.** `/brainstorm` dispatches a new opus-pinned `brainstormer` subagent that drafts `docs/PRD.md` from `templates/PRD.md` + user's topic. `/decompose-prd` is deterministic bash — parses the PRD's Features section and emits `features/<slug>/{workflow.json, spec.md skeleton}` per sub-heading. Idempotent. 17 new tests.
- **`lib/prd-parser.sh`**: extracts feature slugs + scope paragraphs from a PRD.md. Slugifies `"4.1 Add Task Input"` → `"add-task-input"`.
- **`lib/next-command.sh`**: shared resolver for "what's next" given `(phase, verdict)`.

### Changed

- **`hooks/session-start.sh`**: feature summary now includes `— next: /lean-spec:<cmd> <slug>` per feature, plus a footer pointing at `/lean-spec:next`.
- **`docs/PRD.md`**: F9, F10, F11 roadmap entries marked ✅ with implementation notes.
- **`docs/PLUGIN_DEV_GUIDE.md`**: new §8.7 (semi-auto driver) and §8.8 (rules.yaml).

### Deferred

- **F12 — Marketplace publish.** Requires a separate `lean-spec-marketplace` repo; not blocking anything on this project. Process documented in `docs/PLUGIN_DEV_GUIDE.md` §3.


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
