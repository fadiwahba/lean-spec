# lean-spec — Gemini CLI extension

This project loads as a Gemini CLI extension. It mirrors the Claude Code plugin defined by `.claude-plugin/plugin.json` with one important caveat documented below.

## What you get

A spec-driven lifecycle: **specify → implement → review → close**, with per-feature artifacts at `features/<slug>/{workflow.json, spec.md, notes.md, review.md}`.

Commands (prefix with `/lean-spec:`):

| Command | Role | Argument |
|---|---|---|
| `start-spec` | Create a feature and draft `spec.md` | `<slug> [brief or @path/to/PRD.md]` |
| `update-spec` | Revise an existing `spec.md` | `<slug> [what to change]` |
| `submit-implementation` | Advance to `implementing` and produce `notes.md` | `<slug>` |
| `submit-review` | Advance to `reviewing` and produce `review.md` | `<slug> [extras...]` |
| `submit-fixes` | Roll back to `implementing` to address reviewer findings | `<slug>` |
| `close-spec` | Finalize on `APPROVE` verdict | `<slug>` |
| `spec-status` | Print phase + next command | `[<slug>]` |
| `next` | Resolve next command for the active feature | `[<slug>]` |
| `resume-spec` | Re-prime context for an in-progress feature | `<slug>` |
| `brainstorm` | Draft a project-level `docs/PRD.md` | `<topic> [@refs...]` |
| `decompose-prd` | Emit per-feature skeletons from `docs/PRD.md` | `[<prd-path>]` |

## IMPORTANT — degraded mode vs Claude Code

The Claude Code plugin enforces **two-model cost arbitrage** by dispatching each role (architect / coder / reviewer) as a subagent with a pinned model tier (Opus / Haiku / Opus respectively). This is the whole cost argument of lean-spec.

**Gemini CLI has no subagent dispatch primitive** (as of Gemini CLI v0.3x). That means every command here runs in the main session with whatever model Gemini is configured to use. You lose:

- Per-role model pinning (everything runs on the same tier)
- The `SubagentStop` hook's artifact guard (no subagent to stop)
- The review-extras mechanism (`security`, `performance` run as plain prompt additions, not dispatched skills)

The **lifecycle bash** — phase gates, `workflow.json` management, artifact naming — is identical. Reviews are still structured, artifacts still use the same paths, phase transitions are still enforced by `hooks/user-prompt-submit.sh`.

If you want tier enforcement back, use the Claude Code plugin with the same repo (`claude --plugin-dir <this-repo>`).

## Hooks in Gemini

Gemini CLI hooks live in the user's `~/.gemini/settings.json`, not inside the extension. See `.gemini/INSTALL.md` for the recommended hook merge — it's copy-paste into `settings.json`.

## References

- Full architectural PRD: `docs/PRD.md`
- Plugin developer guide (Claude Code focus): `docs/PLUGIN_DEV_GUIDE.md`
- Changelog: `CHANGELOG.md`
