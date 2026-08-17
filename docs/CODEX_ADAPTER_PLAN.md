# Codex host adapter — plan

> Status: DRAFT — needs Fady's sign-off.
> Goal: make lean-spec work with **OpenAI Codex CLI as the host/orchestrator**, the same way it works with Claude Code today. Core principles stay unchanged: skills describe, hooks enforce, `bin/lean-spec` mutates.
> Branch: `feat/codex-host-adapter`.

---

## 1. What Codex gives us (verified Aug 2026)

Codex CLI now has near-parity with every mechanism lean-spec depends on:

| lean-spec needs | Claude Code | Codex CLI | Fit |
|---|---|---|---|
| Skills (SKILL.md) | `skills/*/SKILL.md`, `/lean-spec:x` | `.agents/skills/*/SKILL.md`, invoked as `$name` | High — same file format (Agent Skills standard) |
| Human-only skills | `disable-model-invocation: true` | sidecar `agents/openai.yaml` → `policy.allow_implicit_invocation: false` | High |
| Block state-file writes | `PreToolUse` hook, `permissionDecision: deny` | `PreToolUse` hook, **same JSON deny shape** | High — but Codex edits files via `apply_patch`, not Write/Edit (see §4) |
| Validate artifact when agent finishes | `SubagentStop` hook, `decision: block` | `SubagentStop` hook, same block shape | High |
| Auto-mode driver loop | `Stop` hook, `decision: block` + reason | `Stop` hook, same — reason becomes the continuation prompt | High |
| Per-phase model + effort agents | `agents/*.md` frontmatter (`model`, `effort`) | `.codex/agents/*.toml` (`model`, `model_reasoning_effort`) | High — different file format |
| Authoritative project instructions | CLAUDE.md / constitution injection | `AGENTS.md` chain (git root → cwd, closest wins) | High |
| Command allow rules | permission settings | execpolicy rules (`.codex/rules/*.rules`, Starlark `prefix_rule`) | Medium — commands only, no path-level deny |
| Plugin packaging | `.claude-plugin/plugin.json` + marketplace | `.codex-plugin/plugin.json` + marketplace (`codex plugin add`) | Medium — skills confirmed in plugins; hooks-in-plugin unconfirmed |
| Headless / CI | `claude -p` | `codex exec --sandbox workspace-write -c approval_policy=never` | High |

Hook config lives in `<repo>/.codex/hooks.json` (or config.toml), gated by `[features] hooks = true`. Hook payloads carry `tool_name` / `tool_input` on stdin, same as Claude Code.

## 2. Core decision — one canon, thin adapter, no ports

PRD non-goal ("no per-command cross-provider ports — ever") stays honored:

- **`bin/lean-spec` is already host-neutral** (python stdlib + git). It stays the single source of truth. Zero logic is duplicated.
- **`skills/*/SKILL.md` stays the single canonical skill text.** The Codex copies are **generated, never hand-maintained** — a small installer transforms them (rename, sidecar, invocation syntax). If we ever hand-edit a generated file, we've rebuilt the v3 tax; CI will diff generated output against canon.
- **The three hooks stay the same three scripts.** They already read JSON from stdin and emit the same deny/block shapes Codex expects. They gain Codex-payload awareness (§4), not siblings.
- New directory: `adapters/codex/` — installer + templates only. No lifecycle logic.

This needs one governance change: CONSTITUTION "Hard non-goals" currently bans cross-provider ports outright. Amend it (Fady sign-off required) to: *generated adapters that reuse the canonical CLI, hooks, and skill text are allowed; hand-maintained per-command copies remain forbidden.* PRD gets a new F15 under M5.

## 3. CLI changes (small, host-neutral)

1. `next --json` today returns `"skill": "/lean-spec:implement"` — a Claude-ism. Change to a neutral `"step": "implement"` plus a host-rendered `"skill"` string. Host comes from `LEAN_SPEC_HOST` env (set by each host's hook config) or a `--host` flag; default stays `claude` so nothing breaks.
2. Hook reason texts (stop-auto-driver) that say "read `<plugin>/skills/<name>/SKILL.md`" already work on Codex (skills are files there too) — only the path root differs. The driver resolves the skills root per host.
3. `rules.toml` gains an additive, optional `[hosts.codex]` model map (e.g. `spec = { model = "gpt-5.x-high-tier", effort = "high" }`) because `opus`/`sonnet` names mean nothing to Codex. Absent → fail loud at dispatch with a one-line message (principle 8), never a silent guess.

## 4. Hook changes (the real work)

Same three scripts, taught to recognize Codex payloads:

- **pre-tool-use-guard.sh** — Codex edits files through `apply_patch` (and shell), not `Write`/`Edit`. The guard must extract target paths from an `apply_patch` `tool_input` (patch header lines) and deny when a path matches `features/*/workflow.json` or `.lean-spec/auto.json`. The deny JSON is already the right shape. Matcher in hooks.json: `apply_patch|write_file` (exact tool names to verify against a live payload — first implementation task).
- **subagent-stop-gate.sh** — works as-is (resolves state from disk, not the payload). Verify `stop_hook_active` has a Codex equivalent; if absent, keep the one-retry semantics via a marker file.
- **stop-auto-driver.sh** — works as-is; the block reason becomes Codex's continuation prompt, which is exactly what we want. Reason text updated to name `$lean-spec-<name>` / the Codex skills path.

Enforcement parity note: on Codex, shell is the primary tool, so the heredoc/`rm` gap from the CONSTITUTION's "Known gap" is **wider** — execpolicy can allow-list commands but cannot path-deny. Same stance as today: the hook removes the accidental door; the constitution (via AGENTS.md, §6) forbids the deliberate one. No new pretend-security.

## 5. Skills and agents on Codex

- Generated skills land in the project's `.agents/skills/lean-spec-<name>/SKILL.md` (flat `$` namespace → prefix every name). Transform per skill: `disable-model-invocation: true` → drop from frontmatter, emit sidecar `agents/openai.yaml` with `allow_implicit_invocation: false`; rewrite `/lean-spec:x` → `$lean-spec-x`; rewrite "Task tool" → "delegate to the `<name>` subagent".
- Agents: generate `.codex/agents/{architect,coder,reviewer}.toml` from the canonical `agents/*.md` — frontmatter → `name`/`description`/`model`/`model_reasoning_effort` (mapped via `[hosts.codex]`), body → `developer_instructions`. Constitution injection keeps working: the dispatching skill pastes `docs/CONSTITUTION.md` into the delegation prompt, same as today.
- `AGENTS.md`: Codex's always-loaded authoritative file. The installer appends a marked lean-spec block (idempotent, like the `.gitignore` merge in `init`): lifecycle overview, the layer rule, "never hand-edit `workflow.json`/`auto.json`", and where the CLI lives.

## 6. Install story

Primary: **repo-level installer** (works today, no unconfirmed features):

```
adapters/codex/install.sh   # or: bin/lean-spec init --host codex
```

writes into the target project — `.codex/hooks.json` (three hooks), `.codex/agents/*.toml`, `.agents/skills/lean-spec-*/`, `.codex/rules/lean-spec.rules` (allow `bin/lean-spec`, `git commit`, test runners), appends the AGENTS.md block, and checks `[features] hooks = true` (fail loud with the exact config line if off). Idempotent, fail-loud preflight (python3 ≥ 3.11, git repo, codex on PATH + version floor).

Secondary: **Codex plugin** — `.codex-plugin/plugin.json` in this same repo (skills confirmed shippable; whether hooks can ship in a plugin is unconfirmed). The plugin's `$lean-spec-init` skill then runs the installer above for the parts plugins can't carry. Marketplace publish once the repo route is proven.

## 7. Milestones

| # | Scope | Gate |
|---|---|---|
| C0 | Governance: CONSTITUTION amendment + PRD F15. CLI host-neutrality (`step` field, `LEAN_SPEC_HOST`, `[hosts.codex]` map). | BATS green; Claude behavior byte-identical by default |
| C1 | Hooks understand Codex payloads (`apply_patch` path extraction; captured real payloads as fixtures). | BATS with Codex-shaped fixtures; deny/block verified |
| C2 | Generator + installer: skills transform, sidecars, agent TOMLs, AGENTS.md block, rules file. | BATS scaffold tests; generated-vs-canon diff check in CI |
| C3 | e2e: demo project driven spec → closed under `codex exec` non-interactive; README + docs; `.codex-plugin/` manifest + marketplace publish. | recorded e2e run; gates shown rejecting a hand-edit |

Dogfood rule: C0–C3 each ship through the lean-spec lifecycle itself.

## 8. Open questions / risks (resolve in C1 spike)

1. Exact Codex tool names + `apply_patch` `tool_input` schema for the guard matcher — capture live payloads first.
2. Can `permissions.<name>.filesystem` deny a glob like `features/*/workflow.json`? If yes, it's defense-in-depth on top of the hook.
3. Do hooks ship inside a plugin? Determines how thin the plugin route can be.
4. `stop_hook_active` equivalent on Codex SubagentStop (retry-once semantics).
5. Codex model names for the `[hosts.codex]` defaults, and cross-family review policy: reviewing GPT-written code with a GPT model breaks the "different family reviews the coder" default — document it, or recommend a mixed setup (Codex hosts, Claude reviews via headless adapter, per PRD §9).
