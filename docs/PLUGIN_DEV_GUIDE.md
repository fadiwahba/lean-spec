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
- The `agents/` directory holds dispatch prompt templates (one per role: `architect-prompt.md`, `coder-prompt.md`, `reviewer-prompt.md`); they are read directly by commands, not registered as Claude Code agents — do **not** add an `agents` field in `plugin.json`
- **Three-role dispatch model.** The orchestrator session is thin: it routes commands, reads `workflow.json`, and mediates the user's conversation. It does not write `spec.md`, `notes.md`, or `review.md` directly — each artifact is produced by its corresponding subagent (architect, coder, reviewer) with a pinned model tier. This is by design: see PRD §4.2 and Resolved Decision §12.5
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
| `agents: Invalid input` on load | `agents` field in `plugin.json` points to a directory of template files, not CC agent definitions | Remove `agents` from `plugin.json` — commands read templates directly |
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
