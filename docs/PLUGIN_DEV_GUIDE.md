# lean-spec Plugin Developer Guide

Covers local development, installing for real use, uninstalling cleanly, and the escape hatch if something goes wrong.

This guide is host-specific per section. Start with the Claude Code section unless you already know you're targeting another tool.

---

## 1. Directory layout

lean-spec v3 follows the standard Claude Code plugin layout and mirrors it for other hosts where possible. The repo root is itself a plugin (no nested plugin directory).

```
lean-spec/
├── .claude-plugin/
│   └── plugin.json           # Claude Code manifest
├── skills/                   # Agent skills (Claude Code, Cursor, Gemini)
│   └── <skill-name>/
│       └── SKILL.md
├── commands/                 # Slash commands (Claude Code)
│   └── lean-spec/
│       └── <command>.md
├── agents/                   # Subagent dispatch templates
│   └── <role>-prompt.md
├── hooks/
│   └── hooks.json            # Claude Code hook configuration
│   └── *.sh                  # Hook implementations (bash + jq)
├── .gemini/                  # Gemini CLI extension files (mirrors .claude)
├── .opencode/                # OpenCode manual-install instructions
├── .codex/                   # Codex manual-install instructions
├── gemini-extension.json     # Gemini CLI manifest (root level)
├── docs/                     # PRDs, developer guide (this file)
└── README.md
```

The repo is shaped like a plugin from day one so eventual marketplace publishing is a zero-refactor job.

---

## 2. Claude Code — local development loop

Use this while iterating on skills, commands, or hooks. No install, no uninstall, no marketplace.

```bash
# From any project where you want to test lean-spec
claude --plugin-dir /Users/fady/sandbox/lean-spec
```

That single flag loads the entire plugin from the filesystem. Edit a skill, quit `claude`, relaunch — the change is live. When you exit, the plugin is gone.

### What happens under the hood

- `claude` reads `.claude-plugin/plugin.json` for the manifest
- Auto-discovers `skills/`, `commands/`, and `hooks/hooks.json` from the plugin root
- `hooks/hooks.json` is loaded automatically — do **not** add a `hooks` field in `plugin.json` or it will error with "Duplicate hooks file detected"
- The `agents/` directory holds **valid Claude Code subagent definitions** (one per role: `architect.md`, `coder.md`, `reviewer.md`). Each file has YAML frontmatter (`name`, `description`, `tools`, `model`) and a Markdown body that serves as the subagent's static system prompt. Claude Code auto-discovers them and registers each as `lean-spec:<name>` — do **not** add an `agents` field in `plugin.json` (that's for agent *files* in non-standard locations and will error with "Invalid input" for a directory of agent definitions)
- **Three-role dispatch model.** The orchestrator session is thin: it routes commands, reads `workflow.json`, and mediates the user's conversation. It does not write `spec.md`, `notes.md`, or `review.md` directly — each artifact is produced by its corresponding subagent (architect, coder, reviewer) with a model tier pinned in its definition frontmatter. This is by design: see PRD §4.2 and Resolved Decisions §12.5, §12.6

### Subagent definitions — the schema we use

Every file in `agents/` must be a valid Claude Code subagent definition. Minimum frontmatter:

```yaml
---
name: architect                                    # required; becomes lean-spec:architect
description: <when Claude should invoke>           # required; drives auto-invocation heuristics
tools: ["Read", "Write", "Bash", "Glob", "Grep", "Skill"]   # optional; YAML ARRAY (NOT comma-separated)
model: opus                                        # required for tier enforcement — opus | sonnet | haiku | inherit
color: purple                                      # required; one of red | blue | green | yellow | purple | orange | pink | cyan
---

<static system prompt — no {{template variables}}; per-invocation context is passed via the Task tool's prompt field at dispatch time>
```

**Format gotchas:**
- `tools:` for **agents** must be a YAML array (`["Read", "Grep"]`). Comma-separated string (`Read, Grep`) parses but silently drops some tool names (notably `Glob` and `Grep`) — the `/agents` UI flags them as `Unrecognized`. **Do not** use the comma-separated format that `commands/*.md` uses for `allowed-tools:` — those are different fields with different parsers.
- `color:` runtime palette is `red | blue | green | yellow | purple | orange | pink | cyan`. The plugin-validator skill (in the official `plugin-dev` plugin) lists a stricter palette including `magenta` instead of `purple`/`orange`/`pink` — that list is wrong / outdated relative to the runtime. Trust what `/agents` accepts: `purple` and `pink` work; `magenta` and `indigo` do not.

**Do not put `{{SLUG}}`-style placeholders in these files** — they are the subagent's system prompt, loaded once at registration, not filled in per call. Dynamic context belongs in the `Task.prompt` the dispatching command builds.

**Plugin ships definitions — users do not.** A user who loads this plugin must not need to run `/agents`, create files in `.claude/agents/`, or configure models manually. If install requires user action beyond `--plugin-dir` / `/plugin install`, we've broken the plugin's primary promise.
- Commands appear in `/help` under `(plugin:lean-spec)`

### Verifying the plugin loaded

Inside Claude Code:

```
/help
```

You should see `/lean-spec:start-spec`, `/lean-spec:submit-implementation`, etc. in the command list. If they don't appear, the manifest or directory structure is wrong — check `.claude-plugin/plugin.json` exists and has a valid `name` field.

Skills show up when relevant to the task; you can also force-invoke:

```
Use the Skill tool to invoke using-lean-spec
```

### Iterating quickly

Keep two terminals:

- Terminal A — your editor (VS Code, whatever), editing the plugin source in `~/sandbox/lean-spec/`
- Terminal B — `cd` into a demo project, run `claude --plugin-dir ~/sandbox/lean-spec`

Workflow:
1. Make an edit in A
2. In B, quit Claude Code (`/exit`) and re-launch with the same flag
3. Test in B

Most skill edits are picked up without the restart — but hook changes and command frontmatter changes require a fresh session.

---

## 3. Claude Code — marketplace install (for real users)

Once lean-spec is ready for external testers, publish it through a thin marketplace repo. Users then get a native install experience.

### One-time setup (maintainer)

Create a separate repo, e.g. `fadysoliman/lean-spec-marketplace`, containing one file:

```json
// marketplace.json
{
  "plugins": [
    {
      "name": "lean-spec",
      "source": "github:fadysoliman/lean-spec",
      "version": "latest"
    }
  ]
}
```

That's the entire marketplace. It's a manifest pointing at the real plugin repo.

### Install (user)

Inside Claude Code:

```
/plugin marketplace add fadysoliman/lean-spec-marketplace
/plugin install lean-spec@lean-spec-marketplace
```

### Update (user)

```
/plugin update lean-spec
```

### Uninstall (user)

```
/plugin uninstall lean-spec
/plugin marketplace remove lean-spec-marketplace   # optional
```

Both are first-class Claude Code commands. No filesystem cleanup required.

---

## 4. Escape hatch — "the plugin broke my session"

If a hook misfires, a skill loops, or plugin loading hangs, you have three progressively more aggressive options.

### Level 1 — skip plugins for one session

```bash
claude --no-plugins
```

Starts without loading any plugins. Good for diagnosing whether lean-spec is the culprit.

### Level 2 — remove installed plugin manually

```bash
rm -rf ~/.claude/plugins/lean-spec
```

Claude Code installs marketplace plugins under `~/.claude/plugins/<name>/`. Deleting the directory is equivalent to `/plugin uninstall`, and works even if `claude` itself won't launch.

### Level 3 — reset plugin state entirely

```bash
rm -rf ~/.claude/plugins
```

Wipes all installed plugins. Marketplaces registered in Claude Code settings remain registered, so reinstalling is just `/plugin install <name>@<marketplace>` again.

### Disabling just the hooks

If the plugin loads but its hooks misbehave, edit `~/.claude/settings.json` and comment out the lean-spec hook entries. This preserves skills and commands but stops the hooks from firing. (Or use the `/hooks` slash command to toggle them interactively.)

---

## 5. Gemini CLI — extension install (Phase 2)

Placeholder until Phase 2 lands. The install path will be:

```bash
gemini extensions install https://github.com/fadysoliman/lean-spec
```

Uninstall:

```bash
gemini extensions uninstall lean-spec
```

Gemini CLI reads `gemini-extension.json` at the repo root, plus TOML command files under `commands/`.

---

## 6. OpenCode / Codex — manual install (Phase 3)

Both tools use manual install via fetched instructions. The install docs will live at:

- `.opencode/INSTALL.md`
- `.codex/INSTALL.md`

Users point their tool at the raw URL, following the same pattern Superpowers uses.

---

## 7. Common pitfalls

| Symptom | Likely cause | Fix |
|---|---|---|
| Plugin doesn't appear in `/help` | Missing `.claude-plugin/plugin.json` or invalid `name` | Manifest must exist with a `name` field in kebab-case |
| `agents: Invalid input` on load | `agents` field in `plugin.json` pointed to a directory, OR `agents/*.md` files lacked valid subagent frontmatter | Remove `agents` field from `plugin.json` (directory is auto-discovered). Ensure each `agents/*.md` has `name:` + `description:` frontmatter — those are the required fields |
| Subagent runs on the wrong model | Subagent definition lacks `model:` frontmatter — Claude Code falls back to the main-session model | Add `model: opus` / `model: sonnet` / `model: haiku` to the subagent's frontmatter. Without it, tier enforcement is silently broken |
| `Duplicate hooks file detected` | `hooks` field in `plugin.json` references `hooks/hooks.json`, which is already auto-loaded | Remove `hooks` from `plugin.json` entirely |
| Hook doesn't fire | Hook matcher doesn't match event or `hooks.json` malformed | Validate `hooks/hooks.json`, check `SessionStart` uses `matcher: "startup\|clear\|compact"` |
| Command runs but skill content not loaded | Skill is supposed to be invoked via `Skill` tool, not read | Slash command should instruct agent to use `Skill` tool, not `Read` |
| `--plugin-dir` path doesn't work | Relative path passed or directory lacks `.claude-plugin/` | Use absolute paths; verify plugin root has the manifest directory |
| Commands show wrong namespace | File is in `commands/` root instead of `commands/lean-spec/` | Slash command namespacing follows directory path; `commands/<subdir>/foo.md` → `/<subdir>:foo` |
| Hook hangs startup | Hook script has infinite loop or blocks on stdin | Use `async: false` sparingly; most hooks should not block session startup |

---

## 8. References

- [Claude Code plugin reference](https://docs.claude.com/en/docs/claude-code/plugins) — official plugin docs
- [Claude Code hooks reference](https://docs.claude.com/en/docs/claude-code/hooks) — full hook event list
- [Gemini CLI custom commands](https://geminicli.com/docs/cli/custom-commands) — TOML command format
- [Superpowers plugin.json example](https://github.com/obra/superpowers/blob/main/.claude-plugin/plugin.json) — minimal reference manifest
