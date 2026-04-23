# Installing lean-spec on Codex CLI

Codex is the most limited host for lean-spec of the three non-Claude ports. It has no slash-command registry and no subagent dispatch, so you lose:

- Native `/lean-spec:*` commands (must paste prompts)
- Per-role model pinning (everything runs on your configured Codex model)
- Phase-gate hook enforcement (prompts do the check; nothing stops you bypassing)

What you DO get:

- The full lifecycle (specify → implement → review → close)
- Phase-gate bash in every prompt template
- Coder's hard-forbidden-edits list + reviewer's scope-sweep
- Review archival (`review-cycle-N.md`)
- Notes append-per-cycle in `fixes` mode

## Install

```bash
# 1. Clone the repo
git clone https://github.com/fadysoliman/lean-spec ~/src/lean-spec

# 2. Copy or symlink AGENTS.md + prompts into your project
cp ~/src/lean-spec/.codex/AGENTS.md ./AGENTS.md
ln -s ~/src/lean-spec/.codex/prompts ./.codex-prompts
```

Codex reads `AGENTS.md` from your project root — it'll have the lifecycle context on every session in that project.

## Usage

Pick the phase you want to run, then paste the corresponding prompt into `codex`:

```bash
# Example: start a new feature
codex "$(cat .codex-prompts/start-spec.md)

Slug: my-new-feature
Brief: a CSV export button on the reports page"

# Example: advance to reviewing
codex "$(cat .codex-prompts/submit-review.md)

Slug: my-new-feature"
```

Or drop into the TUI and paste manually:

```bash
codex
# paste the prompt content + slug + brief
```

Each prompt starts with a phase-gate check — if the feature isn't in the required phase, it refuses.

## Configuring the model

In `~/.codex/config.toml`:

```toml
model = "gpt-5.4"
model_reasoning_effort = "medium"
```

Because there's no per-role pinning, all 11 phases run on this model. For heavier features, consider raising `model_reasoning_effort` to `"high"` before spec/review phases.

## Hooks (if your Codex supports them)

Codex has `hooks` configuration in config.toml (community examples show `SessionStart`, `PreToolUse`, `UserPromptSubmit`, `Stop`). If your Codex version supports them, you can port the Claude hooks (`hooks/*.sh`) to the Codex format and get phase-gate enforcement back. That's outside the scope of this install path; see `docs/PLUGIN_DEV_GUIDE.md` §7 common pitfalls for the Claude hook behaviours you'd want to replicate.

## Uninstall

```bash
rm AGENTS.md .codex-prompts
```

Feature artifacts in `features/<slug>/` are untouched — they're not owned by the plugin install.

## Why Codex support is light

Compared to Claude Code / Gemini CLI / OpenCode, Codex CLI has:

- No public slash-command registry that extensions can register into
- No subagent dispatch with per-agent model pinning
- No single canonical extension format

The lean-spec repo's Codex surface is therefore **prompts + project context file**, not a plugin. This matches the PRD §8.1 constraint: "Codex has no subagent dispatch — install docs must state tier enforcement is unavailable."

If Codex CLI adds a subagent primitive later, the ports in `.opencode/agents/*.md` become a fast upgrade path.
