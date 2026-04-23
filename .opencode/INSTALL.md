# Installing lean-spec on OpenCode

OpenCode has subagent support (`mode: subagent` in the agent frontmatter), so the two-model cost-arbitrage story **works here** — unlike Gemini CLI, where tier enforcement is unavailable. The architect runs on Opus, the coder on Haiku, the reviewer on Opus, per the agent definitions in `.opencode/agents/*.md`.

## Install

OpenCode loads agents and commands from two locations:

- **Global**: `~/.config/opencode/agents/` and `~/.config/opencode/commands/`
- **Per-project**: `<project-root>/.opencode/agents/` and `<project-root>/.opencode/commands/`

The recommended install is **global via symlink** so every project gets lean-spec without per-project setup:

```bash
# 1. Clone the repo
git clone https://github.com/fadysoliman/lean-spec ~/src/lean-spec

# 2. Symlink agents
mkdir -p ~/.config/opencode/agents
for a in architect coder reviewer brainstormer; do
  ln -s ~/src/lean-spec/.opencode/agents/$a.md ~/.config/opencode/agents/$a.md
done

# 3. Symlink commands
mkdir -p ~/.config/opencode/commands/lean-spec
for c in start-spec update-spec submit-implementation submit-review submit-fixes close-spec spec-status next resume-spec brainstorm decompose-prd; do
  ln -s ~/src/lean-spec/.opencode/commands/lean-spec/$c.md ~/.config/opencode/commands/lean-spec/$c.md
done
```

**Or per-project**: copy the `.opencode/` directory of this repo into your own project's root.

## Verify

Inside OpenCode's TUI:

```
/help
```

You should see all 11 `/lean-spec:*` commands. Run `/agents` (or equivalent) to confirm the 4 lean-spec agents (`architect`, `coder`, `reviewer`, `brainstormer`) are loaded.

## What's different from Claude Code

Functionally equivalent for the lifecycle:

| Feature | Claude Code | OpenCode |
|---|---|---|
| Per-role model pinning | ✅ via subagent frontmatter | ✅ via agent `mode: subagent` + `model:` |
| Phase-gate enforcement | ✅ `user-prompt-submit` hook | ⚠️ best-effort via command body (no native equivalent) |
| Subagent dispatch | ✅ Task tool with `subagent_type` | ✅ Task tool with `agent:` in command frontmatter + `subtask: true` |
| Review extras | ✅ via `$ARGUMENTS` | ✅ parsed inline in command body |
| Visual fidelity via Playwright | ✅ optional MCP | ✅ optional MCP (same detection pattern) |
| `SubagentStop` artifact guard | ✅ hook | ⚠️ relies on agent prompt compliance |

The "⚠️" rows mean: the behaviour works but is encoded at the prompt layer instead of at a hard hook layer. A malicious or malfunctioning agent could technically ignore it.

## (Optional) Hook parity via OpenCode plugins

OpenCode supports TypeScript plugins that can hook into events. A full plugin that mirrors the Claude Code hooks (`user-prompt-submit` phase gate, `pre-tool-use` workflow-write-guard) is future work. For now, the command bodies contain the phase-gate bash inline.

## Uninstall

```bash
rm -f ~/.config/opencode/agents/{architect,coder,reviewer,brainstormer}.md
rm -rf ~/.config/opencode/commands/lean-spec
```

The feature artifacts in your project (`features/<slug>/*`) are untouched — they're project-level and not owned by the plugin install.

## Model IDs

The agent frontmatter pins specific versions:

- `anthropic/claude-opus-4-7` — architect, reviewer, brainstormer
- `anthropic/claude-haiku-4-5-20251001` — coder

Override by editing `.opencode/agents/<name>.md` — the model ID is standard OpenCode format (`provider/model-id`).
