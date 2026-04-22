# lean-spec v3 M1 Implementation

**Date:** 2026-04-23
**Session:** 06:59 AM
**Project:** /Users/fady/sandbox/lean-spec (branch: lean-spec-v3)

---

## Context

Full implementation of Milestone 1 (F1–F8) for lean-spec v3 — a Claude Code plugin enforcing a spec-driven lifecycle (spec → implement → review → close) via slash commands and hooks. Dogfooded against a real Next.js project (todo-demo) to catch manifest validation issues.

---

## Key Decisions

- **No `agents` field in plugin.json** — `agents/coder-prompt.md` and `agents/reviewer-prompt.md` are dispatch *templates* read directly by commands, not registered Claude Code agent definitions. Adding `"agents": "./agents/"` causes `agents: Invalid input` validation error.
- **No `hooks` field in plugin.json** — `hooks/hooks.json` is auto-discovered by Claude Code from the plugin root. Explicitly referencing it in the manifest causes `Duplicate hooks file detected` error.
- **Final plugin.json is minimal** — only `name`, metadata fields, `"skills": "./skills/"`, and `"commands": "./commands/"`. Everything else auto-discovered.
- **Inline jq in commands, not `source lib/workflow.sh`** — commands use `git rev-parse --show-toplevel` which returns the *user's* project root when loaded via `--plugin-dir`, not the plugin root. Inlining the 5-line jq phase-transition block in each command avoids this cross-repo path issue.
- **`hooks` field omitted in F1, re-added in F5, then removed again** — originally omitted because `hooks.json` didn't exist yet; added when it did; removed after dogfooding revealed auto-discovery conflict.
- **Bash 3.2 compatibility** — macOS ships bash 3.2; `declare -A` (associative arrays) unavailable. `user-prompt-submit.sh` uses a `case` statement instead.
- **`mktemp` scoped to target directory** — `mktemp "${WF}.tmp.XXXXXX"` not bare `mktemp`, so `mv` is atomic on same filesystem.
- **verdict lives in `review.md`, not `workflow.json`** — `using-lean-spec` skill originally had wrong instruction to check `workflow.json` for verdict field; corrected to read `review.md`.
- **`spec.md` frontmatter uses handoffs pattern** — `phase: specifying` + `handoffs.next_command`, NOT `status: draft|ready`.

---

## What Was Built / Changed

| Commit | Files | Description |
|---|---|---|
| `b109735` | `.claude-plugin/plugin.json`, `skills/*/gitkeep`, `commands/lean-spec/.gitkeep`, `agents/.gitkeep`, `hooks/.gitkeep`, `README.md` | F1: Plugin skeleton |
| `4fe1220` | `lib/workflow.sh`, `tests/workflow.bats` | F2: workflow.json helpers + 19 bats tests |
| `77e1418` | `commands/lean-spec/*.md` (8 files) | F3: Core slash commands |
| `9e52d7d` | `agents/coder-prompt.md`, `agents/reviewer-prompt.md` | F4: Agent dispatch templates |
| `eaed83d` | `hooks/hooks.json`, `hooks/*.sh` (6 scripts), `tests/hooks.bats` | F5: Hook fabric + 23 bats tests |
| `48aeb1f` | `skills/*/SKILL.md` (4 files) | F6: Skills (meta + 3 supporting) |
| `3671423` | `examples/demo/**` | F8: Demo project + walkthrough |
| `6e4d2b6` | `commands/lean-spec/{submit-*.md,close-spec.md,update-spec.md}` | fix: inline jq, remove git rev-parse for PLUGIN_ROOT |
| `39c84dd` | `.claude-plugin/plugin.json` | fix: remove `agents` field (validation error) |
| `3583bc2` | `.claude-plugin/plugin.json` | fix: remove `hooks` field (duplicate auto-discovery) |
| `b41faf0` | `docs/PLUGIN_DEV_GUIDE.md` | docs: capture manifest pitfalls from dogfooding |

---

## Gotchas & Lessons Learned

- **`agents` field rejects directory paths to template files** — Claude Code's agent validator expects specific agent definition frontmatter, not arbitrary markdown. A directory of prompt templates will always fail validation.
- **`hooks/hooks.json` is auto-loaded** — the `hooks` manifest field is for *additional* hook files at non-standard paths only. Standard location = auto-discovered = don't reference in manifest.
- **`git rev-parse --show-toplevel` finds the wrong root** — when a plugin is loaded via `--plugin-dir`, the agent's Bash tool runs in the user's project CWD. `git rev-parse` returns the user's project root, breaking `source "$PLUGIN_ROOT/lib/workflow.sh"`. `$CLAUDE_PLUGIN_ROOT` is available in `hooks.json` command strings but unreliable in agent Bash tool context.
- **bats not in PATH on macOS by default** — installed via `git clone` to `/tmp/bats-core`; tests run with `/tmp/bats-core/bin/bats`.
- **PreToolUse deny uses stdout JSON, not exit 2** — for PreToolUse, the deny mechanism is `permissionDecision: "deny"` in stdout JSON + exit 0. Exit 2 is for UserPromptSubmit blocking. Conflating the two causes hooks to silently fail.
- **`SessionStart` matcher field** — PRD specified `matcher: "startup|clear|compact|resume"` but Claude Code's SessionStart event doesn't filter on matchers the same way as PreToolUse. Hook fires on all session starts regardless.

---

## Outstanding / Next Steps

- [ ] Dogfood `/lean-spec:start-spec` in todo-demo — verify spec creation and workflow.json initialization
- [ ] Dogfood `/lean-spec:submit-implementation` — verify inline jq phase transition works in user project
- [ ] Full E2E walkthrough from examples/demo/WALKTHROUGH.md end-to-end
- [ ] M2 planning: semi-auto mode, `/brainstorm`, `/decompose-prd`, optional `rules.yaml` enforcement
- [ ] Verify `$CLAUDE_PLUGIN_ROOT` env var availability in agent Bash tool context (may enable reverting to lib/workflow.sh sourcing if it's set)
- [ ] Check if `SessionStart` hook's `matcher` field has any effect — simplify if not

---

## References

```
/Users/fady/sandbox/lean-spec/.claude-plugin/plugin.json   # manifest (name, skills, commands only)
/Users/fady/sandbox/lean-spec/hooks/hooks.json             # hook event registry (auto-discovered)
/Users/fady/sandbox/lean-spec/lib/workflow.sh              # phase helpers (used by bats tests only)
/Users/fady/sandbox/lean-spec/tests/workflow.bats          # 19 tests — all transitions
/Users/fady/sandbox/lean-spec/tests/hooks.bats             # 23 tests — allow/block paths
/Users/fady/sandbox/lean-spec/examples/demo/WALKTHROUGH.md # E2E test script
/Users/fady/sandbox/todo-demo/                             # dogfood target project (Next.js)

# Run plugin in user project:
claude --plugin-dir /Users/fady/sandbox/lean-spec

# Run all tests:
/tmp/bats-core/bin/bats /Users/fady/sandbox/lean-spec/tests/workflow.bats
/tmp/bats-core/bin/bats /Users/fady/sandbox/lean-spec/tests/hooks.bats
```
