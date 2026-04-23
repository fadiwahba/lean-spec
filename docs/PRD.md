# lean-spec v3 — Product Requirements Document

**Status:** Draft for review
**Owner:** Fady
**Date:** 2026-04-22
**Supersedes:** lean-spec v2 (CLI + pnpm approach, parked on branch `lean-spec-v2`)

---

## 1. One-paragraph summary

lean-spec v3 is a **thin, disciplined, plugin-shaped spec-driven workflow** for solo and small-team developers. It gives agentic coding tools (Claude Code first, then Gemini CLI, OpenCode, Codex) a deterministic lifecycle — `spec → implement → review → close` — enforced by a minimal `workflow.json` state file and a small set of hooks. Its primary design goal is **token efficiency**: by separating planning/review (where a strong model earns its cost) from implementation (where a cheap model executes a well-specified plan), users can run the whole loop at a fraction of the cost of doing everything in one expensive context. No Node.js runtime, no CLI install in Phase 1 — just markdown, bash, and hooks, shipped as a native plugin.

---

## 2. Why — the unoccupied quadrant

| | Thin tooling | Heavy tooling |
|---|---|---|
| **Soft guidance** | Raw CLAUDE.md, custom prompts | Superpowers (skill-based, advisory) |
| **Hard enforcement** | **lean-spec v3** ← us | OpenSpec, SpecKit (CLI + DAGs + constitutions) |

**OpenSpec** is 22k LOC of TypeScript with a DAG engine, delta-merge syntax, and a 25-adapter registry. **SpecKit** is 17.5k LOC of Python with `uv` tooling, a "constitution" concept, and an 8-command pipeline. Both demand buy-in to their world.

**Superpowers** is the closest philosophical cousin — skill-based, plugin-shaped, no CLI — but it's guidance-first. Skills *suggest* behavior; nothing *enforces* a lifecycle.

**lean-spec v3** is the missing cell: small surface area (markdown + hooks + one JSON state file) with **hard enforcement** of lifecycle transitions. You can't `/submit-review` before `/submit-implementation` because the hook fabric blocks it. You don't pay for a CLI you won't extend. You don't learn a DSL.

---

## 3. Value propositions (ordered)

### 3.1 Token optimization (primary)

Every design decision is judged against this question: _does it reduce tokens burned per completed feature?_

- **Two-model cost arbitrage.** A high-reasoning model (Opus/GPT-5-class) writes the spec and reviews the diff. A cheap model (Haiku/Sonnet 4-class) implements the spec in a fresh subagent context. Expensive cognition is spent where it matters; execution tokens are cheap tokens.
- **Context isolation via subagents.** Implementation happens in a disposable subagent that sees only the spec, not the whole conversation. Review happens in a second disposable subagent that sees only the spec + diff. The orchestrator's context stays tiny and re-usable across features.
- **No re-priming.** Hooks re-inject lifecycle rules on SessionStart/compact/resume. You never pay tokens re-explaining the workflow to the agent after a break or compaction.
- **spec.md as the contract.** One artifact feeds both implementer and reviewer. No drift, no translation tax.

### 3.2 Hard lifecycle enforcement

Phase transitions are gated by commands and verified by hooks. The agent cannot skip `/submit-review` to get to `/close-spec`. The human decides when to advance; the hook fabric guarantees the transition is legal.

### 3.3 Plugin-native from day one

Ships as a Claude Code plugin (`.claude-plugin/plugin.json`) with local-dev (`--plugin-dir`) and marketplace install paths already wired. No Node.js, no pnpm, no build step. Uninstall is a single command.

### 3.4 Cross-provider portability

Same markdown artifacts, same lifecycle, same file layout across Claude Code → Gemini CLI → OpenCode → Codex. Users on mixed teams don't re-learn the workflow per tool.

### 3.5 Greenfield and brownfield support

Optional upstream phases (`/brainstorm`, `/decompose-prd`) produce the spec that the core lifecycle consumes. Existing projects skip straight to `/start-spec`.

---

## 4. Core concepts

### 4.1 Lifecycle phases

```
(optional) brainstorm  →  (optional) decompose-prd  →
  start-spec  →  [implementing]  →  submit-implementation  →
  [reviewing]  →  submit-review  →  [fixing?]  →  submit-fixes  →
  close-spec  →  [closed]
```

Loops:
- `submit-review` can return **NEEDS_FIXES**, routing back to `/submit-fixes`, which re-enters review
- `/resume-spec` re-enters any in-flight phase after a session break

### 4.2 Roles — inputs & expected outputs

**lean-spec v3 has exactly 2 roles.** (Two-stage review happens *inside* `/submit-review` as two skill invocations; it is not a separate role.) Both roles run as **dispatched subagents** — see "Role enactment" below for why.

| Role | Model tier (pinned at dispatch) | Input (source of truth) | Expected output |
|---|---|---|---|
| **Architect** | Strong (Opus/GPT-5) | User intent/brief (+ existing `spec.md` on update) | `spec.md` (scope, constraints, acceptance criteria) |
| **Coder** | Cheap (Haiku/Sonnet 4) | `spec.md` only | Code diff + `notes.md` (what was built, how to verify) |

Review is not a role — it is a two-skill sequence within `/submit-review`:
1. **spec-compliance** — does the diff satisfy `spec.md`?
2. **code-quality** — does the diff meet project conventions and avoid obvious bugs?

Output: `review.md` with verdict `APPROVE | NEEDS_FIXES | BLOCKED`.

**Role enactment (single-session, three dispatches).** lean-spec v3 runs in **one Claude Code terminal**. The main session is a thin **orchestrator** that routes commands, reads `workflow.json`, and advises the user on next steps. Every role — including Architect — runs as a dispatched subagent with its own prompt template and enforced model tier:

| Role | Dispatched from | Subagent definition | Model pin | Required output | Runs during phase |
|---|---|---|---|---|---|
| **Architect** | `/start-spec`, `/update-spec` | `agents/architect.md` (`lean-spec:architect`) | `opus` | `spec.md` (handoffs frontmatter + scope + AC + out-of-scope + coder guardrails) | `specifying` |
| **Coder** | `/submit-implementation`, `/submit-fixes` | `agents/coder.md` (`lean-spec:coder`) | `haiku` | code diff + `notes.md`. Optional Playwright smoke-test if the MCP is available (compile + render + no console errors; max 1 self-fix retry else `BLOCKED`). | `implementing` |
| **Reviewer** | `/submit-review` | `agents/reviewer.md` (`lean-spec:reviewer`) | `opus` | `review.md` with verdict. Default skills: `spec-compliance` + `code-quality` (+ `visual-fidelity` if Playwright MCP available). Optional skills via `$ARGUMENTS`: `security`, `performance`, `full`. | `reviewing` |

**Optional tool integrations (graceful degradation).** All MCP-based enhancements are optional. The agents detect availability by attempting the call once; if the tool is not registered in the session, they log "tool unavailable, proceeding without it" and continue with the reduced capability set — never hard-fail. This keeps the plugin's "thin" promise intact: fresh install works with nothing but markdown + bash + jq; installing Playwright / context7 / sequential-thinking MCP servers unlocks progressively richer behaviour.

**The plugin ships the subagent definitions.** Each `agents/*.md` file is a valid Claude Code subagent definition with frontmatter (`name`, `description`, `tools`, `model`) and a static system prompt as its body. The plugin's commands dispatch via `Task` with the plugin-qualified `subagent_type` (e.g. `"lean-spec:architect"`); Claude Code loads the subagent's system prompt from the definition file automatically, and the command supplies only per-invocation context (slug, paths, mode, brief) as the `Task` prompt. Users do not create or configure these subagents — fresh install works.

**Why Architect is a subagent, not the orchestrator:** if the orchestrator session played Architect, the user's choice of main-session model (which may default to a cheap tier like Haiku/Sonnet to save tokens on fluff conversation between commands) would silently determine spec quality. The plugin's primary value prop (§3.1, two-model cost arbitrage) and its distinguishing promise (§2, hard enforcement) both break in that scenario. Dispatching Architect with `model: opus` pinned in its definition frontmatter makes the tier enforceable at runtime — not a convention the user is expected to follow.

**Interactive refinement still works.** The orchestrator mediates the conversation. User invokes `/start-spec <slug> <brief>` → architect subagent writes draft → control returns to orchestrator → orchestrator shows the draft and asks the user for feedback → user runs `/update-spec <slug>` with revisions → architect subagent dispatched again with prior draft + feedback. Multi-turn spec refinement happens across dispatches, not within one subagent invocation.

**Two-terminal usage is NOT the model for a single provider.** The `two-terminal` language in §8 refers only to running lean-spec artifacts across *different* hosts (Claude Code + Gemini CLI). Within one host, one terminal is the supported setup.

### 4.3 `workflow.json` — minimal deterministic state

One file per feature at `features/<slug>/workflow.json`:

```json
{
  "slug": "add-user-export",
  "phase": "reviewing",
  "created_at": "2026-04-22T10:15:00Z",
  "updated_at": "2026-04-22T14:02:00Z",
  "history": [
    { "phase": "specifying",   "entered_at": "2026-04-22T10:15:00Z" },
    { "phase": "implementing", "entered_at": "2026-04-22T11:40:00Z" },
    { "phase": "reviewing",    "entered_at": "2026-04-22T14:02:00Z" }
  ],
  "artifacts": {
    "spec":   "spec.md",
    "notes":  "notes.md",
    "review": "review.md"
  }
}
```

- **Single source of truth for phase.** Hooks read this to enforce command gates.
- **No DAG, no lock files, no migrations.** A phase is a string. An illegal transition is an illegal string.
- **Human-editable.** If state gets wedged, `vim workflow.json` fixes it.

### 4.4 `handoffs:` frontmatter (borrowed from SpecKit)

Each artifact carries explicit next-step pointers in YAML frontmatter:

```yaml
---
slug: add-user-export
phase: specifying
handoffs:
  next_command: /lean-spec:submit-implementation
  blocks_on: []
  consumed_by: [coder, reviewer]
---
```

This makes each file self-describing — an agent opening `spec.md` cold knows what to do with it without reading a separate orchestration doc.

### 4.5 Optional per-artifact rules config (borrowed from OpenSpec)

A project may add `.lean-spec/rules.yaml` to constrain artifact shape:

```yaml
spec:
  required_sections: [scope, acceptance, out-of-scope]
  max_tokens: 4000
review:
  required_verdict: true
  require_line_references: true
```

Optional. Missing file = no extra enforcement. Used by `pre-spec-complete` hook to validate before advancing phase.

### 4.6 Operating modes (sequenced delivery)

| Mode | Who drives phase transitions | Delivery milestone |
|---|---|---|
| **Manual** | Human runs every `/command` | M1 (MVP) |
| **Semi-auto** | Agent proposes transition; human confirms in one keystroke | M2 |
| **Auto** | Agent drives the full loop; human can intervene at any time | M4 |

Close-out (`/close-spec`) is always an **explicit step**, never skipped, including in auto mode. Auto mode will pause and surface the close-out for human confirmation — the loop is not "done" until a human says it is.

---

## 5. Hook fabric (Context7-verified)

All events and fields below are verified against the current Claude Code hooks reference.

| Hook event | Matcher / filter | Why lean-spec uses it | Output mechanism |
|---|---|---|---|
| **SessionStart** | `matcher: "startup\|clear\|compact\|resume"` | Re-inject lifecycle rules + current `workflow.json` phase into context. Survives compaction and session restarts without re-priming. | `hookSpecificOutput.additionalContext` |
| **PreCompact** | n/a | Snapshot current spec/notes summary into context before compaction drops it. | `hookSpecificOutput.additionalContext` |
| **UserPromptSubmit** | n/a | If user runs a `/lean-spec:*` command, validate the phase transition is legal before the slash command executes. | `hookSpecificOutput.additionalContext` (for guidance) or exit 2 (to block with reason visible to model) |
| **PreToolUse** | `matcher: "Write\|Edit"` (scoped to `features/*/workflow.json`) | Prevent the agent from hand-editing `workflow.json` out of phase order. Force transitions through slash commands. | `hookSpecificOutput.permissionDecision: "deny"` + `permissionDecisionReason` |
| **Stop** | n/a | If the agent tries to end a turn mid-phase without producing the expected artifact (e.g. `notes.md` missing after implementation), block and force completion. | `decision: "block"` + `reason` |
| **SubagentStop** | `matcher: "architect\|coder\|reviewer"` (via `agent_type`) | Verify subagent produced its expected output before allowing control to return to orchestrator. Catch "silent success" failures. Architect must produce `spec.md`; coder must produce `notes.md`; reviewer must produce `review.md`. | `decision: "block"` + `reason` |

**Hooks NOT used in v3:**
- `PostToolUse` — nothing to do after a tool call that a simpler mechanism doesn't already handle
- `Notification` — no notification surface in v3
- `SessionEnd` — no persistent state cleanup needed; `workflow.json` IS the state

### Hook exit-code conventions

- Exit `0` — allow, silent
- Exit `1` — error to user (hook bug, not workflow violation)
- Exit `2` — block, message visible to **model** (this is the "teach the agent" path)

---

## 6. Slash commands

All commands live under `commands/*.md` (flat — no subdirectory) and namespace as `/lean-spec:<name>` because Claude Code uses the plugin `name` field as the namespace prefix. A subdirectory would add a second namespace segment, producing the unintended `/lean-spec:lean-spec:*` form. (Colons are the verified Claude Code namespace separator; they also work in Gemini CLI.)

### 6.1 Core lifecycle

| Command | Role invoked | What it does |
|---|---|---|
| `/lean-spec:start-spec <slug> [brief]` | Architect (subagent) | Create `features/<slug>/` + `workflow.json` (phase → `specifying`), then dispatch architect subagent with brief/PRD ref to author `spec.md` |
| `/lean-spec:update-spec <slug>` | Architect (subagent) | Collect user feedback, dispatch architect subagent with existing `spec.md` + feedback to produce revised `spec.md` (phase stays `specifying`) |
| `/lean-spec:submit-implementation <slug>` | Coder (subagent) | Advance to `implementing`, dispatch coder subagent with `spec.md`, produce diff + `notes.md` |
| `/lean-spec:submit-review <slug> [extras...]` | Reviewer (subagent) | Advance to `reviewing`, dispatch reviewer subagent. Default: spec-compliance + code-quality + (auto) visual-fidelity. Optional extras: `security`, `performance`, `full`. Produces `review.md` with verdict. |
| `/lean-spec:submit-fixes <slug>` | Coder (subagent) | When review is `NEEDS_FIXES`, roll phase back to `implementing` and re-dispatch coder with `spec.md + review.md`. Ends in `implementing` — user then runs `/submit-review` to re-enter reviewing (same codepath as initial review) |
| `/lean-spec:close-spec <slug>` | Orchestrator (no dispatch) | Verify `APPROVE` verdict in `review.md`, advance phase → `closed`. This is the only lifecycle command the orchestrator executes directly — no role needed |

### 6.2 Navigation

| Command | What it does |
|---|---|
| `/lean-spec:spec-status [<slug>]` | Print current phase + last activity for one or all features |
| `/lean-spec:resume-spec <slug>` | Re-enter in-flight phase after a session break; re-prime context from `workflow.json` + artifacts |

### 6.3 Greenfield (M2+)

| Command | What it does |
|---|---|
| `/lean-spec:brainstorm` | Free-form ideation session; outputs a raw `idea.md` |
| `/lean-spec:decompose-prd <prd-file>` | Break a PRD into multiple specs; outputs N `features/<slug>/spec.md` skeletons |

---

## 7. File layout (plugin-shaped from day one)

```
lean-spec/
├── .claude-plugin/
│   └── plugin.json                    # Claude Code manifest (name, version, desc)
├── skills/
│   ├── using-lean-spec/SKILL.md                   # Meta-skill (1%-rule style)
│   ├── writing-specs/SKILL.md                     # Architect skill — spec structure, AC rules, coder guardrails
│   ├── reviewing-spec-compliance/SKILL.md         # Reviewer — default skill #1
│   ├── reviewing-code-quality/SKILL.md            # Reviewer — default skill #2
│   ├── reviewing-security/SKILL.md                # Reviewer — optional (via $ARGUMENTS: security)
│   └── reviewing-performance/SKILL.md             # Reviewer — optional (via $ARGUMENTS: performance)
├── commands/                              # Flat — no subdirectory (avoids double namespace)
│   ├── start-spec.md
│   ├── submit-implementation.md
│   ├── submit-review.md
│   ├── submit-fixes.md
│   ├── close-spec.md
│   ├── resume-spec.md
│   ├── spec-status.md
│   ├── update-spec.md
│   ├── brainstorm.md                      # M2+
│   └── decompose-prd.md                   # M2+
├── agents/                               # Valid Claude Code subagent definitions (frontmatter + system prompt), auto-discovered
│   ├── architect.md                      # name=architect, model=opus
│   ├── coder.md                          # name=coder, model=haiku
│   └── reviewer.md                       # name=reviewer, model=opus
├── hooks/
│   ├── hooks.json                     # Event → script mapping
│   ├── session-start.sh               # Re-inject lifecycle + phase
│   ├── pre-compact.sh                 # Snapshot spec summary
│   ├── user-prompt-submit.sh          # Validate slash-command phase gates
│   ├── pre-tool-use-workflow.sh       # Block hand-edits of workflow.json
│   ├── stop-guard.sh                  # Enforce artifact completion
│   └── subagent-stop-guard.sh         # Verify subagent output
├── .gemini/                           # Gemini CLI mirror (Phase 2)
├── .opencode/                         # OpenCode manual-install (Phase 3)
├── .codex/                            # Codex manual-install (Phase 3)
├── gemini-extension.json              # Gemini CLI manifest (Phase 2)
├── templates/
│   └── PRD.md                        # Project-level PRD skeleton — canonical shape consumed by /brainstorm + /decompose-prd (M2), usable standalone today (see §12.9)
├── docs/
│   ├── PRD.md                         # This file
│   └── PLUGIN_DEV_GUIDE.md            # Install/uninstall/escape hatches
└── README.md
```

**Per-feature artifacts** (in the consuming project, not this plugin repo):

```
<user-project>/
└── features/
    └── <slug>/
        ├── workflow.json              # Phase + history
        ├── spec.md                    # Architect output
        ├── notes.md                   # Coder output
        └── review.md                  # Reviewer output
```

---

## 8. Cross-provider strategy

**Phase 1 (Claude Code only):** Full hook fabric, full enforcement, three shipped subagent definitions (`agents/architect.md`, `coder.md`, `reviewer.md`) with pinned model tiers.

**Phase 2+ (Gemini CLI, OpenCode, Codex):** Same markdown artifacts, same `workflow.json`, same slash-command names where the host allows. Enforcement fidelity degrades gracefully per host — hosts without hooks get advisory skills instead of hard gates. No MCP bridge in v1; **two-terminal usage** (one terminal per tool) is the supported cross-provider pattern.

The cross-provider promise is "the **artifacts** work anywhere" — not "every enforcement guarantee holds everywhere."

### 8.1 Agent shipping per host

Role dispatch and model-tier pinning are Claude-Code-native concepts. Other hosts have different primitives; each port must ship its own equivalents so users never have to hand-configure agents.

| Host | Role dispatch primitive | Model pinning primitive | What we ship |
|---|---|---|---|
| **Claude Code (M1)** | `Task` tool with `subagent_type` + plugin-provided `agents/*.md` | `model:` frontmatter field on the subagent definition | `agents/architect.md`, `coder.md`, `reviewer.md` |
| **Gemini CLI (M3)** | Extensions support "personas" / custom contexts, but no native subagent dispatch — we'll emulate via dedicated command-scoped contexts | Model selection is a CLI flag (`--model`) or Gemini profile, not per-dispatch | `.gemini/agents/*.toml` (or equivalent) shipped as part of the extension, plus wrapper commands that invoke the right model. If Gemini lacks dispatch entirely, the commands fall back to advisory mode: orchestrator prints "run this as architect" and reminds the user to switch models |
| **OpenCode (M3+)** | TBD — verify what OpenCode exposes for role-scoped contexts | TBD | Manual-install `.opencode/INSTALL.md` will document whichever mechanism OpenCode provides; we ship the equivalent config files, not instructions for the user to write them |
| **Codex (M3+)** | Codex is a single-context tool — no subagent dispatch at all | No per-role model selection | Degrade to advisory mode only: skills + slash commands work, but tier enforcement is impossible. The PLUGIN_DEV_GUIDE will state this limitation explicitly |

**Invariant across hosts:** if a host cannot enforce the model tier, the port must *say so visibly* in its install docs. The user should never think they're getting tier enforcement when they aren't.

M3 features (F13–F15) explicitly include "ship host-native agent definitions" as scope, not "document how users should configure agents."

---

## 9. Distribution

**Phase 1 — Claude Code marketplace:**
- Publish via a thin marketplace repo (`lean-spec-marketplace`) pointing at this plugin
- User install: `/plugin marketplace add fadysoliman/lean-spec-marketplace` → `/plugin install lean-spec@lean-spec-marketplace`
- Update: `/plugin update lean-spec`
- Uninstall: `/plugin uninstall lean-spec`
- Escape hatches documented in `PLUGIN_DEV_GUIDE.md` (claude --no-plugins, `rm -rf ~/.claude/plugins/lean-spec`)

**Phase 2+ — Gemini CLI extension:** `gemini extensions install <repo-url>`

**Phase 3+ — OpenCode / Codex:** Manual install via `curl | bash` following the Superpowers pattern. Ships `.opencode/INSTALL.md` and `.codex/INSTALL.md`.

**No npm, no pip, no uv, no Node.js runtime** anywhere in Phase 1. That is a product decision, not an oversight.

---

## 10. Non-goals (explicit)

- **Not a CLI.** No `lean-spec` binary. No `package.json` at the repo root for runtime use.
- **Not a DAG.** Dependencies between features are human-managed via links in `spec.md`.
- **Not a constitution engine.** Per-artifact rules are optional YAML, not a mandatory governance layer.
- **Not a multi-tenant/team tool.** Optimized for solo and pair workflows.
- **Not a migration from v2.** v2 is parked; v3 starts clean. Users of v1 (current `.claude/` layout) migrate by installing the plugin and deleting the old `.claude/lean-spec/` folder.

---

## 11. Feature breakdown (implementation-ready)

Each feature below is scoped to be built **independently** after PRD approval. A feature is "done" when its acceptance criteria pass in a demo project.

### Milestone M1 — MVP: Claude Code + manual mode

Goal: a solo developer can complete a full spec → implement → review → close loop using `/lean-spec:*` commands in Claude Code, with hooks enforcing phase order.

| # | Feature | Scope | Acceptance |
|---|---|---|---|
| F1 | **Plugin skeleton** | `.claude-plugin/plugin.json`, empty skills/commands/agents/hooks dirs, README | `claude --plugin-dir .` loads with no errors; `/help` shows plugin namespace |
| F2 | **workflow.json contract + helper lib** | Bash helpers for `read-phase`, `set-phase`, `append-history`, `validate-transition`. Pure jq + bash. | Unit tests (bats) for all transitions including illegal ones |
| F3 | **Core slash commands (manual)** | `/start-spec`, `/submit-implementation`, `/submit-review`, `/submit-fixes`, `/close-spec`, `/spec-status`, `/resume-spec`, `/update-spec` | Each command runs end-to-end in a demo project; artifacts produced match templates |
| F4 | **Architect + coder + reviewer subagent definitions** | `agents/architect.md` (model=opus), `agents/coder.md` (model=haiku), `agents/reviewer.md` (model=opus). Each is a valid Claude Code subagent definition (frontmatter + system prompt); plugin auto-discovers them. Architect invokes `writing-specs` skill; reviewer invokes both review skills in sequence. | Subagent dispatched from `/start-spec` produces `spec.md` on the pinned architect model; `/submit-implementation` produces `notes.md` on the pinned coder model; `/submit-review` produces `review.md` with structured verdict on the pinned reviewer model. `SubagentStop` hook blocks stops when the expected artifact is missing |
| F5 | **Hook fabric** | All 6 hooks from §5, plus `hooks/hooks.json`. Includes bats tests for each hook's allow/block paths. | Illegal phase transition blocked by UserPromptSubmit; hand-edit of `workflow.json` blocked by PreToolUse; SessionStart re-primes phase after compaction |
| F6 | **using-lean-spec meta-skill** | 1%-rule-style SKILL.md that auto-invokes on every session and tells the agent how to navigate the lifecycle | Fresh agent with no prior context correctly identifies current phase from `workflow.json` and proposes correct next command |
| F7 | **Plugin dev guide (done)** | `docs/PLUGIN_DEV_GUIDE.md` | ✅ Complete |
| F8 | **Demo project + E2E walkthrough** | `examples/demo/` with a toy feature that exercises spec → implement → review → close end-to-end | Recorded walkthrough reproduces in under 10 minutes from fresh install |

**M1 exit criterion:** Fady can dogfood the plugin to build M2.

### Milestone M2 — Semi-auto mode + greenfield commands

| # | Feature | Scope |
|---|---|---|
| F9  | **Semi-auto driver** ✅ (pragmatic shape) | `SessionStart` hook now surfaces phase-appropriate next commands per feature; new `/lean-spec:next` command resolves "what's next" for the most-recently-updated active feature. Auto-dispatch (single-keystroke confirm UX) remains future work — blocked on Claude Code exposing a confirm-and-run hook primitive. Resolver logic factored to `lib/next-command.sh` for reuse when that lands |
| F10 | **/brainstorm + /decompose-prd** ✅ | `/brainstorm` dispatches a cyan-pinned brainstormer subagent (opus) that drafts `docs/PRD.md` from `templates/PRD.md` + user topic. Single-shot (iterate by re-running or editing). `/decompose-prd` is deterministic bash — parses the PRD's Features section and emits `features/<slug>/{workflow.json, spec.md skeleton}` per sub-heading. Idempotent. See `lib/prd-parser.sh` + §12.9 |
| F11 | **Optional rules.yaml enforcement** ✅ | `.lean-spec/rules.yaml` parsed by `lib/rules.sh` inside `hooks/user-prompt-submit.sh`. Four rules: `required_sections`, `max_tokens`, `required_verdict`, `require_line_references`. Violations block phase advance with a reason. Opt-in — no rules.yaml means no enforcement. See `examples/rules.yaml` + `docs/PLUGIN_DEV_GUIDE.md` §8.7 |
| F12 | **Marketplace publish** | Create `lean-spec-marketplace` repo; write public install docs |

### Milestone M3 — Cross-provider (Gemini, OpenCode, Codex)

| # | Feature | Scope |
|---|---|---|
| F13 | **Gemini CLI extension** ✅ | `gemini-extension.json` manifest + `commands/lean-spec/*.toml` (11 mirrors, coexist with Claude's `.md`) + `GEMINI.md` context file + `.gemini/INSTALL.md` + `.gemini/hooks-template.json`. Degraded mode — no subagent dispatch in Gemini, so tier enforcement is unavailable (documented). `scripts/verify-gemini-commands.sh` drift check in CI |
| F14 | **OpenCode install path** ✅ | `.opencode/agents/*.md` (4 agents with `mode:subagent` + `model:provider/id` pinning) + `.opencode/commands/lean-spec/*.md` (11) + `.opencode/INSTALL.md`. **Tier enforcement works here** — OpenCode supports per-agent model pinning. Phase-gate hook parity is best-effort inline (no native `UserPromptSubmit` hook to chain into) |
| F15 | **Codex install path** ✅ | `.codex/AGENTS.md` (project context) + `.codex/prompts/*.md` (11 self-contained paste-in templates) + `.codex/INSTALL.md`. Most degraded of the three — no slash commands, no subagent dispatch. User pastes prompts into `codex` manually. Lifecycle bash (phase gate + workflow.json mutation) preserved; tier enforcement unavailable |
| F16 | **Cross-provider artifact compatibility test** ✅ | `tests/cross-provider.bats` — 9 tests. Verifies same `workflow.json` progressed across simulated Claude/Gemini/OpenCode handoffs preserves chronological history; each host ships EXACTLY 11 entry points standalone; each host documents its degraded-mode caveat |

### Milestone M4 — Auto mode

| # | Feature | Scope |
|---|---|---|
| F17 | **Auto driver** ✅ | `/lean-spec:auto <slug>` drives the full lifecycle using `lib/next-command.sh` as the resolver. Iterates up to 5 phases (configurable via `--max-cycles`) via the `SlashCommand` tool. Hard-stops on `BLOCKED` verdict |
| F18 | **Human-intervention checkpoints** ✅ | Integrated into `/lean-spec:auto` — default behavior pauses at each phase boundary for user confirmation. `--unattended` flag bypasses for CI-style runs. User can interrupt mid-lifecycle; `workflow.json` always stays in a valid state |
| F19 | **Telemetry hooks (optional, local)** ✅ | `lib/telemetry.sh` + `commands/telemetry.md`. Opt-in via `LEAN_SPEC_TELEMETRY=1` env var or `~/.lean-spec/telemetry=on` marker file. Local-only, no network. Writes phase transitions to `~/.lean-spec/telemetry.jsonl`. Sync is idempotent via the `Stop` hook. Token counts are NOT tracked (would require wrapping the `claude` CLI, out of scope) |

---

## 12. Resolved decisions

1. **Rules config scope (F11):** start bare. Simple YAML with `required_sections`, `max_tokens`, `required_verdict`, `require_line_references`. Expand schema only on real demand from users.
2. **Two-stage review:** one subagent with two skills (`reviewing-spec-compliance` + `reviewing-code-quality` invoked in sequence inside a single `/submit-review` dispatch). Cheaper, and good enough. Revisit only if reviewer contamination is observed in practice.
3. **`resume-spec` vs automatic resume:** explicit `/lean-spec:resume-spec` required in M1 for predictability. Auto-resume on `SessionStart` is a candidate for M4 once the manual path is proven.
4. **Telemetry (F19):** opt-in, local-only. No network calls, no aggregation. A `~/.lean-spec/telemetry.jsonl` per-feature token log the user explicitly enables. Purpose is to let skeptical users verify the token-arbitrage claim empirically on their own machine.
5. **All three roles run as dispatched subagents with pinned model tiers (M1).** Architect, Coder, and Reviewer are all invoked via `Task`/Agent dispatch from the orchestrator. The orchestrator session is deliberately thin — it routes commands, reads `workflow.json`, mediates the human conversation, and never writes artifacts itself. **Why:** if the orchestrator played Architect, the user's choice of main-session model (which may default to a cheap tier for fluff conversation between commands) would silently determine spec quality. Dispatching Architect with an explicit strong-model pin enforces the two-model cost arbitrage (§3.1) at runtime rather than relying on user hygiene. **Interactive refinement** is preserved across dispatches: the orchestrator shows the draft and collects feedback, then re-dispatches via `/update-spec`. Multi-turn spec iteration happens *between* subagent invocations, not inside one.

6. **The plugin ships subagent definitions; users do not configure them.** `agents/architect.md`, `agents/coder.md`, and `agents/reviewer.md` are valid Claude Code subagent definitions (frontmatter with `name`, `description`, `tools`, `model`; body is the static system prompt). Claude Code auto-discovers them at plugin load and registers them as `lean-spec:architect`, `lean-spec:coder`, `lean-spec:reviewer`. **Why:** if users had to define their own agents, tier enforcement would be a user-configurable default (easily broken), and the install would stop being "one flag"; the plugin's whole pitch is "markdown + bash, no prerequisite setup." This also means per-invocation context (slug, paths, mode, brief) is passed as the `Task` tool's `prompt` field at dispatch time — the subagent definition body itself is static and contains only the role's system prompt, not template variables. **Cross-provider implication (M3+):** every host port must ship its own host-native agent definitions — never rely on user configuration. See §8.1.

7. **Optional MCP tools degrade gracefully; nothing is required.** Coder (Playwright smoke-test), Reviewer (Playwright visual-fidelity), plus any reasoning aids like context7 or sequential-thinking, are all optional runtime enhancements. Agents detect availability by attempting a single call; if the tool is not registered, they log "tool unavailable, proceeding without it" and continue with the reduced capability set. **Why:** the plugin's "thin" promise (§2) means a fresh install must work with nothing but markdown + bash + jq. Installing MCP servers unlocks progressively richer behaviour (runtime smoke-tests, visual review, live docs lookup) without any of it becoming a prerequisite. This is also the cross-provider fallback strategy — hosts without MCP equivalents simply get the default capability set.

8. **Review extras are opt-in via `$ARGUMENTS`, not default.** `security` and `performance` review skills run only when explicitly named in the dispatch args (e.g. `/lean-spec:submit-review <slug> security performance`). `full` is a shortcut that runs every available `reviewing-<name>` skill in the plugin. **Why:** trivial changes shouldn't pay the cost of a full-spectrum audit on every review; non-trivial changes explicitly opt in. Adding new review dimensions later is zero-churn — drop a `skills/reviewing-<name>/SKILL.md`, update the reviewer's extras table, done.

9. **Canonical project-level PRD shape lives in `templates/PRD.md`.** Validated in the wild by the todo-demo and pomodoro-demo PRDs: Implementation Contract (binding visual), Design Language (exact tokens + typography), Layout, Features (named elements, tables over prose), State Model, Derived Values, Interactions Summary, Out of Scope. **Why:** the shape is the interface between "product thinking" and "spec thinking." Named elements + exact tokens make the visual contract reviewable by the Reviewer subagent (with or without Playwright); tables make feature ACs directly extractable into per-feature spec.md files. `/brainstorm` (M2) drafts from this template; `/decompose-prd` (M2) reads it to enumerate feature skeletons. Today users can copy `templates/PRD.md` manually — the M2 commands just automate that copy and pre-fill.

---

## 13. Approval

This PRD requires explicit sign-off before implementation on F1 begins. Review, annotate, and approve/reject in this file before merging the `lean-spec-v3` branch.

- [x] Approved by Fady — date: 22/04/2026
