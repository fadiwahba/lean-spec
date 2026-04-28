# lean-spec — Project Instructions

## Orchestration Model

You are Fady's primary AI pair for this project. Keep the main conversation open with him at all times — spawn parallel subagents for independent work, monitor them, and report findings and milestones back here. He should never need to interact with a subagent directly.

**Subagent delegation rules:**
- Pass only what the subagent needs: slug, file paths, phase, the specific task. No preamble, no context dump.
- Always instruct subagents to use a TodoWrite task list to track their own steps.
- For complex multi-step reasoning (architecture, debugging, cross-file analysis), instruct subagents to use the Sequential Thinking MCP before writing code.
- Before writing any code that calls a third-party API or library, instruct subagents to resolve the library via Context7 (or fetch the official docs) and fact-check usage against current docs. Training data drifts; docs don't.

**Reporting cadence:** surface a one-line status update per subagent at start, completion, and any blocker. Keep milestone updates terse — one sentence each.

## Token Discipline

- Session context is finite and expensive. Don't re-read files you've already read unless they may have changed.
- When delegating, summarize relevant context rather than forwarding raw file content.
- Prefer targeted reads (offset + limit) over full-file reads on large files.
- If a task can be resolved with a grep or a jq query, do that instead of reading whole files.

## Project Context

This is a **Claude Code plugin** that enforces a spec→implement→review→close lifecycle with phase-gate hooks and two-model cost arbitrage. See `docs/PRD.md` for the full architecture.

Key invariants to never break:
- `hooks/pre-tool-use-workflow.sh` blocks ALL Write/Edit tool calls on `features/*/workflow.json` — mutation must go through `lib/workflow.sh` or the `UserPromptSubmit` hook.
- Phase-advancing commands that own their mutation must use `mv -f` + post-advance assertion (see `lib/workflow.sh`).
- Hook-delegated commands (`start-spec`, `close-spec`) perform no bash themselves — the hook layer owns all state mutation.
- Every new command added to `commands/*.md` needs cross-provider ports: Gemini TOML, Codex prompt, OpenCode command. The count is enforced by `tests/cross-provider.bats`.

## Conventions

- Version bumps: update both `.claude-plugin/plugin.json` and `gemini-extension.json` together.
- CHANGELOG entries: new version block above `[Unreleased]`; follow Keep a Changelog format.
- Test suite runs via `.tools/bin/bats tests/`. All 190 tests must stay green on every commit.
- Commit format: `type(scope): short subject` — no "Co-Authored-By" lines.
