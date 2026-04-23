# lean-spec v3

A thin Claude Code plugin that enforces a **spec-driven development lifecycle** — *spec → implement → review → close* — with hard phase-gate hooks and two-model cost arbitrage.

The main session is the orchestrator (thin router). The heavy lifting runs in dispatched subagents with model tiers pinned per role: **Opus for architect and reviewer, Haiku for coder** (the canonical default — every tier is configurable, but this is the cost-optimal baseline).

## Why

Treating every turn as "ask the biggest model everything" is the default on most AI coding tools and it's the wrong economic shape. Specs are cheap to get right with a strong model; implementation is mechanical and can run on a cheap model *if* the spec is precise; review is high-stakes and should never be the cheap tier. This plugin enforces that split with runtime hooks so cost arbitrage is structural, not a guideline someone can drift away from.

## Quick install (Claude Code)

From any project you want lean-spec to run in:

```bash
claude --plugin-dir /path/to/lean-spec
```

That's the whole install — no marketplace, no copying files, no `npm install`. Exit Claude Code and the plugin is gone.

## Five-minute quickstart

In a project that has a `docs/PRD.md` (or any one-paragraph feature brief):

```text
/lean-spec:start-spec my-feature @docs/PRD.md

    → Opus architect writes features/my-feature/spec.md

/lean-spec:submit-implementation my-feature

    → Haiku coder implements, writes notes.md

/lean-spec:submit-review my-feature

    → Opus reviewer writes review.md with verdict: APPROVE | NEEDS_FIXES | BLOCKED

/lean-spec:submit-fixes my-feature        (only if NEEDS_FIXES)

    → Coder addresses each finding, appends "## Cycle N fixes" to notes.md

/lean-spec:close-spec my-feature           (on APPROVE)

    → phase = closed, feature shipped
```

At any point: `/lean-spec:spec-status my-feature` shows current phase + next command. `/lean-spec:next` resolves "what should I run now?" for the most-recently-updated feature. If you get lost: `/lean-spec:resume-spec my-feature`.

**Starting greenfield?** Run `/lean-spec:brainstorm <one-line topic>` to draft a project-level `docs/PRD.md` (opus-tier), then `/lean-spec:decompose-prd` to emit one feature skeleton per section for the architect to fill.

## What's under the hood

- **4 subagents** with pinned model tiers (`agents/{architect, coder, reviewer, brainstormer}.md`)
- **13 slash commands** (`commands/*.md`):
  - **Lifecycle**: `/start-spec`, `/submit-implementation`, `/submit-review`, `/submit-fixes`, `/close-spec`
  - **Navigation**: `/spec-status`, `/next`, `/resume-spec`, `/update-spec`
  - **Greenfield**: `/brainstorm`, `/decompose-prd`
  - **Drive/observe**: `/auto` (full lifecycle with optional checkpoints), `/telemetry` (opt-in phase-duration report)
- **6 hook scripts** that enforce the lifecycle (block hand-editing of `workflow.json`, validate phase gates, guard subagent outputs, surface next commands)
- **6 skills** guiding each role (`skills/{writing-specs, reviewing-*, using-lean-spec}/SKILL.md`)
- **Optional per-project rules** at `.lean-spec/rules.yaml` — `required_sections`, `max_tokens`, `required_verdict`, `require_line_references`. Enforced at phase advance. See `examples/rules.yaml`.
- **Optional MCP integrations** that degrade gracefully when not installed:
  - Playwright → coder smoke-test + reviewer visual-fidelity check
  - Context7 → current library docs
  - Sequential-thinking → structured reasoning for complex features
- **Review extras via `$ARGUMENTS`**: `/lean-spec:submit-review my-feature security performance` (or `full`) adds OWASP-lite and render-performance checks on demand

## Real cost data

Numbers from 4 end-to-end experiments on a Pomodoro timer against a binding visual contract (`docs/ux-design.png`). All on Pro-tier pricing. See `/Users/fady/sandbox/todo-demo` experiment branches for raw JSON.

| Architect | Coder | Fix cycles | Total cost | Time |
|---|---|---|---|---|
| Opus | Sonnet | 1 | $6.33 | 17 min |
| Sonnet | Sonnet (unpatched) | 2 | $7.64 | 26 min |
| Opus | Haiku | 1 | $6.97 | 23 min |
| **Sonnet** | **Sonnet (patched)** | **0** | **$3.07** | **12 min** |

The patched all-Sonnet run is cheapest and fastest. Key insight: **the writing-specs skill enforces spec structure; model tier becomes secondary.** With a V1–V8 numbered visual-checklist table in AC4, the Sonnet reviewer can verify tokens one-by-one. Without it (prose AC4), the reviewer has no teeth and visual drift goes unpunished.

## Testing

```bash
# one-time: install bats-core locally (no sudo)
git clone --depth=1 https://github.com/bats-core/bats-core.git /tmp/bats-core
/tmp/bats-core/install.sh .tools

# run the suite
.tools/bin/bats tests/
```

Current coverage: **188 tests across 13 files** — workflow transitions, hook outputs, plugin structure, experiment-report, rules.yaml enforcement, next-command resolver, PRD parser, decompose-prd integration, Gemini command drift, OpenCode frontmatter, Codex prompts, cross-provider compatibility, and telemetry.

## Documentation

- **Full PRD / architecture** — [`docs/PRD.md`](docs/PRD.md)
- **Plugin developer guide** (install, uninstall, escape hatches, pitfalls) — [`docs/PLUGIN_DEV_GUIDE.md`](docs/PLUGIN_DEV_GUIDE.md)
- **PRD skeleton template** for greenfield projects — [`templates/PRD.md`](templates/PRD.md)
- **Changelog** — [`CHANGELOG.md`](CHANGELOG.md)

## Cross-host support

| Host | Status | Tier enforcement | Install guide |
|---|---|---|---|
| **Claude Code** | first class | ✅ | `docs/PLUGIN_DEV_GUIDE.md` |
| **OpenCode** | shipped | ✅ (per-agent model pinning via `mode:subagent`) | `.opencode/INSTALL.md` |
| **Gemini CLI** | shipped (degraded) | ❌ (no subagent dispatch) | `.gemini/INSTALL.md` |
| **Codex CLI** | shipped (lightest) | ❌ (no slash commands, no subagents) | `.codex/INSTALL.md` |

The lifecycle bash and artifact shape are identical across all four. The degraded modes clearly label what's unavailable.

## License

MIT — see the manifest at `.claude-plugin/plugin.json`.
