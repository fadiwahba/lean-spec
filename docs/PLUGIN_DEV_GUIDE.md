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

### Optional MCP tools — graceful-degradation pattern

Coder and Reviewer agents can use optional MCP tools (Playwright, context7, sequential-thinking, etc.) when those servers are loaded in the user's session. They must never hard-fail when a tool is missing.

**Detection pattern (used in agent system prompts):**

```
Detect availability by attempting the call once.
If the tool is not registered, log "tool unavailable, proceeding without it" and skip.
Never hard-fail on a missing optional tool.
```

**`tools: ["*"]`** is used on Coder and Reviewer to let them call any registered MCP tool without enumerating each by name (MCP tool names vary by user setup — `mcp__playwright__*` vs `mcp__plugin_*_playwright__*` etc.).

**Documenting an optional tool to a user**: explain what installing it unlocks (e.g. "install Playwright MCP → coder runs a smoke-test before review; reviewer adds visual-fidelity to its default skills"), but never list it as a prerequisite.

### Review extras convention

`/lean-spec:submit-review <slug>` accepts trailing positional args that name extra review skills:

| Arg | Skill loaded | Owner |
|---|---|---|
| `security` | `skills/reviewing-security/SKILL.md` | Reviewer |
| `performance` | `skills/reviewing-performance/SKILL.md` | Reviewer |
| `full` | all available `reviewing-*` extras | Reviewer (shortcut) |

To add a new extra:
1. Create `skills/reviewing-<name>/SKILL.md` following the same structure as security/performance
2. Add a row to the table in `agents/reviewer.md` (Step 4 — Extras section) mapping the arg name to the skill
3. Update this guide's table

The reviewer treats unknown extras as "not recognised — skipped" with a note in `review.md` summary; never fails dispatch.

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
| Coder edits `package.json` `dev` script to change port | Coder bypassed the dev-server PID-file pattern (agents/coder.md §Playwright smoke-test) and tried to "fix" port config permanently | Reviewer's scope-violation sweep flags this as Critical. Coder's "Hard-forbidden edits" list names `package.json` scripts explicitly — see agents/coder.md §Implementation rules |
| `review.md` from a prior fix cycle is gone | Correct: reviewer archives prior reviews as `review-cycle-N.md` before writing a new one (see §9) — check `features/<slug>/review-cycle-*.md` | — |
| Sonnet architect writes prose AC4 and visual drift passes review | Missing V1–V8 numbered-table enforcement | Upgrade to latest `skills/writing-specs/SKILL.md` (has the enforcement rule). Validated by experiment B2 — fix took visible-ring-color drift to zero |
| Zombie `next-server` / `vite` processes across sessions | Coder or reviewer started a dev server without using the portable PGID cleanup pattern | Use the `ps -o pgid=` → `kill -TERM -$PGID` pattern in agents/{coder,reviewer}.md §Playwright. Never `setsid` (Linux-only, broken on macOS) |

---

## 8. Post-experiment hardening (v3.0.1+ patches)

After running four end-to-end experiments (see README → "Real cost data") we added a handful of rules and workflows to the plugin. These are load-bearing — removing them causes the regressions experiments A/B/C surfaced to come back.

### 8.1 Coder's "Hard-forbidden edits" list

`agents/coder.md` §Implementation rules enumerates files the coder must never modify unless the spec explicitly names them:

- `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock` — **including `scripts` fields**
- `next.config.*`, `tsconfig.json`, `eslint.config.*`, `postcss.config.*`, `tailwind.config.*`
- Root `app/layout.tsx` metadata, `<head>`, global providers
- Existing tests

**Why:** experiments B and B2 surfaced silent drift where coders edited `package.json dev` to pin a port, turning session-only hacks into permanent project changes. This list gives the reviewer a concrete rule to enforce.

### 8.2 Reviewer's scope-violation sweep

`agents/reviewer.md` Step 2 mandates a `git diff --name-only` pass cross-checked against the forbidden list. Any unexpected file → **Critical** finding.

### 8.3 `review.md` archival across fix cycles

Before each new review, the reviewer runs:

```bash
N=$(ls features/<slug>/review-cycle-*.md 2>/dev/null | wc -l)
[ -f features/<slug>/review.md ] && mv features/<slug>/review.md features/<slug>/review-cycle-$((N+1)).md
```

`review.md` is always the **latest** verdict. Prior cycles live as `review-cycle-1.md`, `review-cycle-2.md`, etc. — audit trail only; downstream commands still read `review.md`.

### 8.4 `notes.md` append-per-cycle

In `fixes` mode the coder appends `## Cycle N fixes` to the existing `notes.md` rather than rewriting it. The "What was built" from the initial implementation stays intact; each cycle adds its own findings→fix→file:line table.

### 8.5 Dev-server lifecycle (portable)

Coder and reviewer must never leave zombie dev servers. Canonical pattern (macOS + Linux):

```bash
# detect existing
if curl -sf http://localhost:3001 >/dev/null; then
  SERVER_URL="http://localhost:3001"  # someone else's — don't touch
else
  pnpm dev > /tmp/lean-spec-<slug>-dev.log 2>&1 &
  echo $! > /tmp/lean-spec-<slug>-dev.pid
fi

# before exit (only if you started it)
if [ -f /tmp/lean-spec-<slug>-dev.pid ]; then
  PID=$(cat /tmp/lean-spec-<slug>-dev.pid)
  PGID=$(ps -o pgid= -p "$PID" 2>/dev/null | tr -d ' ')
  [ -n "$PGID" ] && kill -TERM "-$PGID"
  rm -f /tmp/lean-spec-<slug>-dev.pid
fi
```

`setsid` is Linux-only and **does not work on macOS** — don't use it.

### 8.6 Writing-specs visual-AC rule

For any UI feature with a binding visual contract (`docs/ux-design.png` in a PRD), AC4 **must** be a one-liner deferring to a numbered Visual Checklist table (V1, V2, ...) in Technical Notes. Prose AC4 is rejected by the skill's own self-check.

Validated by experiment B2: swapping prose→table dropped review cycles from 3→1 and fixed the white-ring visual drift.

### 8.7 Optional per-project rules (`.lean-spec/rules.yaml`)

Projects can opt into stricter enforcement by dropping a `.lean-spec/rules.yaml` at the repo root. The schema is intentionally small (four fields):

```yaml
required_sections:      # markdown heading substrings that must be present
  spec.md:   [Scope, Acceptance Criteria, Out of Scope, Coder Guardrails]
  notes.md:  [What was built, How to verify]
  review.md: [Verdict, Spec Compliance, Code Quality]

max_tokens:             # approximated as char-count / 4
  spec.md:  2000
  notes.md: 6000

required_verdict: APPROVE                # blocks /close-spec on anything else

require_line_references:                 # heuristic: at least one `path:NNN`
  review.md: true
```

Enforcement runs in `hooks/user-prompt-submit.sh` via `lib/rules.sh`. When the user types a phase-advancing command (`/submit-implementation`, `/submit-review`, `/close-spec`), the hook:

1. Checks whether `.lean-spec/rules.yaml` exists in CWD. If not, skip — rules are opt-in.
2. Loads and parses via Python (`yaml.safe_load` → JSON).
3. Validates the artifact about to be consumed (`spec.md` for `submit-implementation`, `notes.md` for `submit-review`, `review.md` for `close-spec`).
4. If any rule fails, exits `2` with a `decision: block` JSON and human-readable reason. `/submit-fixes` is exempt (no new artifact exists at that moment).

Ship a copy for your project from `examples/rules.yaml`. All fields are optional — any rule you don't set is not enforced.

**Design notes:**
- **Section matching is case-insensitive substring** — "Acceptance" matches "## Acceptance Criteria". Keeps the rules forgiving as you iterate on artifact structure.
- **`max_tokens` is chars / 4** — good enough for bounding runaway artifacts; don't expect exact tokenizer parity.
- **`require_line_references` is "at least one"** — a review with one backtick `path:NNN` passes even if other findings lack them. Heuristic, not audit-grade. The real audit tool is the reviewer's scope-sweep (§8.2).

---

## 9. Testing

The plugin ships a bats-core test suite covering:

- `tests/workflow.bats` — `lib/workflow.sh` phase-transition logic (read/validate/set)
- `tests/hooks.bats` — hook script outputs and phase-gate enforcement
- `tests/plugin-structure.bats` — frontmatter validation, model-pin enforcement, review-archive presence, forbidden-edits list presence
- `tests/experiment-report.bats` — `scripts/experiment-report.sh` aggregation + error handling

### Install bats-core locally (no sudo)

```bash
git clone --depth=1 https://github.com/bats-core/bats-core.git /tmp/bats-core
/tmp/bats-core/install.sh .tools
```

`.tools/` is in `.gitignore`.

### Run

```bash
.tools/bin/bats tests/                          # full suite
.tools/bin/bats tests/plugin-structure.bats     # one file
.tools/bin/bats tests/ -f "phase"               # filter by test name substring
```

### What's not covered (by design)

Subagent dispatch is not unit-tested — that requires spawning `claude --print` subprocesses, which cost real money and time. Subagent behavior is validated by the end-to-end Pomodoro experiments (see README → "Real cost data" and the locked branches in `/Users/fady/sandbox/todo-demo`).

### Adding a test

```bash
# Drop a new tests/foo.bats file. setup/teardown pattern:
setup() {
  PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TMP=$(mktemp -d)
}
teardown() { rm -rf "$TMP"; }
@test "my new check" { run ...; [ "$status" -eq 0 ]; }
```

The existing suite already fails on subtle drift (e.g. changing a canonical model pin, removing the scope-violation sweep). Keep new tests that narrow — don't test LLM output, test the shell and schema scaffolding around it.

---

## 10. References

- [Claude Code plugin reference](https://docs.claude.com/en/docs/claude-code/plugins) — official plugin docs
- [Claude Code hooks reference](https://docs.claude.com/en/docs/claude-code/hooks) — full hook event list
- [Gemini CLI custom commands](https://geminicli.com/docs/cli/custom-commands) — TOML command format
- [bats-core](https://github.com/bats-core/bats-core) — test framework used by the suite
- [Superpowers plugin.json example](https://github.com/obra/superpowers/blob/main/.claude-plugin/plugin.json) — minimal reference manifest
