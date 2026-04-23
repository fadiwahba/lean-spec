# Installing lean-spec on Gemini CLI

Gemini CLI support is degraded relative to Claude Code — no subagent dispatch means every role runs in the main session. See `GEMINI.md` at the repo root for what you do and don't get.

## Install

```bash
gemini extensions install https://github.com/fadysoliman/lean-spec
```

Gemini CLI clones the repo and treats `gemini-extension.json` as the manifest. Commands in `commands/lean-spec/*.toml` auto-register as `/lean-spec:<name>`.

Alternatively, clone manually and symlink:

```bash
git clone https://github.com/fadysoliman/lean-spec ~/src/lean-spec
mkdir -p ~/.gemini/extensions
ln -s ~/src/lean-spec ~/.gemini/extensions/lean-spec
```

## Verify

Inside Gemini CLI:

```
/help
```

You should see all 11 `/lean-spec:*` commands. If they don't appear, check:
- Extension is installed: `gemini extensions list` or `ls ~/.gemini/extensions/`
- `gemini-extension.json` at extension root has valid JSON with a `name` field
- Extension directory has a `commands/` subdirectory with TOML files

## (Recommended) Add the lifecycle hooks

Gemini CLI hooks live in the user's `~/.gemini/settings.json`, NOT inside the extension. Without them, phase gates aren't enforced at the `UserPromptSubmit` layer — you can still run the lifecycle commands, but they won't catch all misuse early.

To wire the hooks, merge the snippet from `.gemini/hooks-template.json` (in this repo) into your `~/.gemini/settings.json` under the top-level `hooks` key. Gemini's hook event names differ from Claude's:

| Claude event | Gemini event | Purpose |
|---|---|---|
| `UserPromptSubmit` | `OnUserMessage` or equivalent | Phase-gate enforcement |
| `PreToolUse` + matcher `Write\|Edit` | `BeforeTool` + matcher `write_file\|replace` | Block hand-edits of `workflow.json` |
| `SessionStart` | (no equivalent — Gemini reloads on each session) | Feature summary injection |
| `Stop` | (no equivalent) | Artifact existence guard |
| `SubagentStop` | (no equivalent — Gemini has no subagents) | Artifact guard per role |

The template at `.gemini/hooks-template.json` wires the two that DO map: `BeforeTool` for write-guard, and a `BeforeTool`-style phase gate adapted from `hooks/user-prompt-submit.sh`.

### Exact merge

Open `~/.gemini/settings.json` (create if missing with `{}`) and merge:

```json
{
  "hooks": {
    "BeforeTool": [
      {
        "matcher": "write_file|replace",
        "hooks": [
          {
            "name": "lean-spec-workflow-guard",
            "type": "command",
            "command": "bash ${GEMINI_EXTENSION_DIR}/hooks/pre-tool-use-workflow.sh"
          }
        ]
      }
    ]
  }
}
```

If you already have `hooks.BeforeTool`, append the new entry to the array rather than overwriting.

## Degraded behaviors to know about

- **No per-role model pinning.** Everything runs on your configured Gemini model. The cost-arbitrage argument (§3.1 of the Claude Code PRD) is unavailable here.
- **No artifact-produced-check on role exit.** Claude Code's `SubagentStop` hook blocks when e.g. `notes.md` is missing after the coder runs. On Gemini you rely on the command prompts instructing the main session to produce the artifact — weaker guarantee.
- **Review extras (`security`, `performance`) run as plain prompt additions, not dispatched skills.** The quality of the extra review depends on whether your main model has read the skill file (`skills/reviewing-security/SKILL.md`) at all.
- **Visual-fidelity reviews** still work if Gemini has Playwright MCP installed (same detection pattern).

## Uninstall

```bash
gemini extensions uninstall lean-spec
```

Or delete the directory:

```bash
rm -rf ~/.gemini/extensions/lean-spec
```

Remove the `hooks.BeforeTool[]` entry from `~/.gemini/settings.json` if you added it.
