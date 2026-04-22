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

**lean-spec v3 has exactly 2 roles.** (Two-stage review happens *inside* `/submit-review` as two skill invocations; it is not a separate role.)

| Role | Model tier | Input (source of truth) | Expected output |
|---|---|---|---|
| **Architect** | Strong (Opus/GPT-5) | User intent + codebase | `spec.md` (scope, constraints, acceptance criteria) |
| **Coder** | Cheap (Haiku/Sonnet 4) | `spec.md` only | Code diff + `notes.md` (what was built, how to verify) |

Review is not a role — it is a two-skill sequence within `/submit-review`:
1. **spec-compliance** — does the diff satisfy `spec.md`?
2. **code-quality** — does the diff meet project conventions and avoid obvious bugs?

Output: `review.md` with verdict `APPROVE | NEEDS_FIXES | BLOCKED`.

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
| **SubagentStop** | `matcher: "coder\|reviewer"` (via `agent_type`) | Verify subagent produced its expected output before allowing control to return to orchestrator. Catch "silent success" failures. | `decision: "block"` + `reason` |

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

All commands live under `commands/lean-spec/*.md` and namespace as `/lean-spec:<name>`. (Colons are the verified Claude Code namespace separator; they also work in Gemini CLI.)

### 6.1 Core lifecycle

| Command | Role invoked | What it does |
|---|---|---|
| `/lean-spec:start-spec <slug>` | Architect | Create `features/<slug>/`, generate `spec.md`, set phase → `specifying` |
| `/lean-spec:update-spec <slug>` | Architect | Revise `spec.md` in place (stays in `specifying`) |
| `/lean-spec:submit-implementation <slug>` | Coder (subagent) | Advance to `implementing`, dispatch coder subagent with `spec.md`, produce diff + `notes.md` |
| `/lean-spec:submit-review <slug>` | Reviewer (subagent, two skills) | Advance to `reviewing`, dispatch reviewer subagent, produce `review.md` with verdict |
| `/lean-spec:submit-fixes <slug>` | Coder (subagent) | When review is `NEEDS_FIXES`, re-dispatch coder with `spec.md + review.md`, re-enter `reviewing` |
| `/lean-spec:close-spec <slug>` | Architect | Verify `APPROVE` verdict, archive artifacts, set phase → `closed` |

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
│   ├── using-lean-spec/SKILL.md       # Meta-skill (1%-rule style)
│   ├── writing-specs/SKILL.md
│   ├── reviewing-spec-compliance/SKILL.md
│   └── reviewing-code-quality/SKILL.md
├── commands/
│   └── lean-spec/
│       ├── start-spec.md
│       ├── submit-implementation.md
│       ├── submit-review.md
│       ├── submit-fixes.md
│       ├── close-spec.md
│       ├── resume-spec.md
│       ├── spec-status.md
│       ├── update-spec.md
│       ├── brainstorm.md
│       └── decompose-prd.md
├── agents/
│   ├── coder-prompt.md                # Subagent dispatch template for coder
│   └── reviewer-prompt.md             # Subagent dispatch template for reviewer
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

**Phase 1 (Claude Code only):** Full hook fabric, full enforcement.

**Phase 2+ (Gemini CLI, OpenCode, Codex):** Same markdown artifacts, same `workflow.json`, same slash-command names where the host allows. Enforcement fidelity degrades gracefully per host — hosts without hooks get advisory skills instead of hard gates. No MCP bridge in v1; **two-terminal usage** (one terminal per tool) is the supported cross-provider pattern.

The cross-provider promise is "the **artifacts** work anywhere" — not "every enforcement guarantee holds everywhere."

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
| F4 | **Coder + reviewer agent prompts** | `agents/coder-prompt.md`, `agents/reviewer-prompt.md`. Reviewer prompt invokes both review skills in sequence. | Subagent dispatched from `/submit-implementation` produces `notes.md`; `/submit-review` produces `review.md` with structured verdict |
| F5 | **Hook fabric** | All 6 hooks from §5, plus `hooks/hooks.json`. Includes bats tests for each hook's allow/block paths. | Illegal phase transition blocked by UserPromptSubmit; hand-edit of `workflow.json` blocked by PreToolUse; SessionStart re-primes phase after compaction |
| F6 | **using-lean-spec meta-skill** | 1%-rule-style SKILL.md that auto-invokes on every session and tells the agent how to navigate the lifecycle | Fresh agent with no prior context correctly identifies current phase from `workflow.json` and proposes correct next command |
| F7 | **Plugin dev guide (done)** | `docs/PLUGIN_DEV_GUIDE.md` | ✅ Complete |
| F8 | **Demo project + E2E walkthrough** | `examples/demo/` with a toy feature that exercises spec → implement → review → close end-to-end | Recorded walkthrough reproduces in under 10 minutes from fresh install |

**M1 exit criterion:** Fady can dogfood the plugin to build M2.

### Milestone M2 — Semi-auto mode + greenfield commands

| # | Feature | Scope |
|---|---|---|
| F9  | **Semi-auto driver** | Agent proposes next command; hook intercepts and shows single-keystroke confirm UX |
| F10 | **/brainstorm + /decompose-prd** | Upstream greenfield commands producing `idea.md` and N feature skeletons |
| F11 | **Optional rules.yaml enforcement** | `.lean-spec/rules.yaml` parsed by hooks; violations block phase advance with a visible reason |
| F12 | **Marketplace publish** | Create `lean-spec-marketplace` repo; write public install docs |

### Milestone M3 — Cross-provider (Gemini, OpenCode, Codex)

| # | Feature | Scope |
|---|---|---|
| F13 | **Gemini CLI extension** | `gemini-extension.json`, TOML command mirrors under `.gemini/commands/lean-spec/`, best-effort hook parity |
| F14 | **OpenCode install path** | `.opencode/INSTALL.md` + curl-installable layout |
| F15 | **Codex install path** | `.codex/INSTALL.md` + curl-installable layout |
| F16 | **Cross-provider artifact compatibility test** | Same `workflow.json` progressed across two hosts works correctly |

### Milestone M4 — Auto mode

| # | Feature | Scope |
|---|---|---|
| F17 | **Auto driver** | Agent drives all transitions except close-out |
| F18 | **Human-intervention checkpoints** | User can interrupt at any phase boundary; auto mode degrades gracefully to manual |
| F19 | **Telemetry hooks (optional)** | Per-feature token accounting so users can verify the cost-arbitrage claim empirically |

---

## 12. Resolved decisions

1. **Rules config scope (F11):** start bare. Simple YAML with `required_sections`, `max_tokens`, `required_verdict`, `require_line_references`. Expand schema only on real demand from users.
2. **Two-stage review:** one subagent with two skills (`reviewing-spec-compliance` + `reviewing-code-quality` invoked in sequence inside a single `/submit-review` dispatch). Cheaper, and good enough. Revisit only if reviewer contamination is observed in practice.
3. **`resume-spec` vs automatic resume:** explicit `/lean-spec:resume-spec` required in M1 for predictability. Auto-resume on `SessionStart` is a candidate for M4 once the manual path is proven.
4. **Telemetry (F19):** opt-in, local-only. No network calls, no aggregation. A `~/.lean-spec/telemetry.jsonl` per-feature token log the user explicitly enables. Purpose is to let skeptical users verify the token-arbitrage claim empirically on their own machine.

---

## 13. Approval

This PRD requires explicit sign-off before implementation on F1 begins. Review, annotate, and approve/reject in this file before merging the `lean-spec-v3` branch.

- [x] Approved by Fady — date: 22/04/2026
