# lean-spec v2 PRD

## Goal

Design `lean-spec v2` as a slim, practical, agent-agnostic workflow kernel for day-to-day spec-driven AI coding work.

The system must preserve the core `lean-spec` value proposition:

- strict role ownership
- manual human-controlled lifecycle today
- low token overhead
- compatibility across multiple AI coding tools
- future path toward reduced human involvement

`lean-spec v2` must reduce drift by moving orchestration and validation out of noisy LLM session memory and into deterministic Node.js scripts.

## Background

`lean-spec v1` established a useful working model:

- `Architect` plans and reviews
- `Coder` implements
- the human manually advances phases

This solves a real cost problem:

- planning/review requires higher-end models
- implementation can often be handled by lower-cost models

This split is operationally valuable, but v1 still depends too much on the active agent session to remember and follow workflow rules. In longer or compacted sessions, the default/orchestrator session can drift into performing implementation or authoring the wrong artifacts.

## Problem Statement

`lean-spec v1` has four primary failure modes:

1. **Role drift**
   - the orchestrator writes `spec.md`
   - the orchestrator implements code directly
   - the wrong specialist edits the wrong artifact

2. **Context loss**
   - after summarization, compaction, or long sessions, the agent no longer reliably follows `lean-spec`

3. **Prompt bloat**
   - large hook reminders increase context noise and weaken the important rules

4. **Hook fragility**
   - hooks sometimes create loops, repeated reminders, or unstable behavior

## Product Vision

`lean-spec v2` should be a **tiny workflow engine plus specialist agent contracts**.

It should:

- keep AI agents responsible for intelligence only
- move orchestration, phase transitions, scaffolding, and ownership validation into deterministic scripts
- keep runtime prompts short and phase-specific
- provide a small machine-readable control file that survives context loss
- remain simple enough for daily solo usage

It must support three operating modes:

1. `manual` - human advances every phase explicitly
2. `semi-auto` - the system advances phases automatically, but pauses at two human gates
3. `auto` - the orchestrator manages and operates the full lifecycle with no human gates

For v2 implementation scope:

- `manual` is fully implemented
- `semi-auto` is implemented at the CLI/state level, with host-specific runner support optional
- `auto` is specified in the state model and PRD, but full host-agnostic execution is deferred

## Target Users

### Primary User

A developer who:

- uses multiple coding agents and models
- wants to split planning/review from implementation
- cares about cost and token limits
- wants strict ownership and workflow discipline
- prefers simple local tooling over heavyweight frameworks

### Secondary User

A developer or small team that wants to gradually reduce the human-in-the-loop while retaining safe approval gates.

## Non-Goals

`lean-spec v2` is not intended to be:

- a heavy multi-agent platform
- a large schema ecosystem
- a full OpenSpec-style spec/change management product
- a replacement for the host tool's native agent runtime
- a generalized workflow engine for every possible team process

## Design Principles

1. **Slim over comprehensive**
   - every feature must justify its runtime and maintenance cost

2. **Deterministic over advisory**
   - file ownership and phase rules should be enforced by scripts where possible

3. **Short prompts over long reminders**
   - runtime contracts should be concise and phase-specific

4. **Human-controlled today, autonomy-ready tomorrow**
   - the same state model should support manual, semi-auto, and auto workflows

5. **Tool-agnostic first**
   - core behavior should live in the CLI/state model, not in tool-specific prompt conventions

6. **Single source of truth**
   - `workflow.json` plus CLI output define the workflow state; no runner or agent may maintain competing lifecycle state

## Desired Outcomes

### Functional Outcomes

- the wrong role cannot easily edit the wrong artifact without failing validation
- current phase and allowed writes survive context compaction
- slash commands become thin wrappers around deterministic CLI behavior
- runtime prompts become small enough to reduce token overhead materially
- the workflow can run in manual, semi-auto, and auto modes from the same core architecture

### Operational Outcomes

- higher-cost models are used only for planning/review
- lower-cost models can safely execute implementation phases
- switching terminals or tools does not lose the workflow state
- users can resume work reliably after interruption
- semi-auto behavior is available without requiring a universal built-in runner

## Core v2 Concept

### 1. Workflow JSON

Each feature will have a small machine-readable control file:

```text
lean-spec/features/<slug>/workflow.json
```

This file is the single source of truth for:

- operating mode
- current phase
- active role
- approval requirements
- status
- allowed writes
- timestamps

It replaces the need for the session to remember the lifecycle.

### 2. Node.js CLI as Workflow Kernel

`lean-spec v2` will introduce a small Node.js CLI responsible for:

- scaffolding artifacts
- validating phase transitions
- updating `workflow.json`
- generating short role contracts
- validating artifact ownership and changed files
- exposing status/instructions in structured output
- enforcing operating-mode behavior

The CLI must not perform planning, coding, or review reasoning.

### 3. Thin Host-Tool Wrappers

Host-tool slash commands remain useful, but become lightweight wrappers around the CLI.

Examples:

- phase commands:
- `/lean-spec:start-spec foo`
- `/lean-spec:implement-spec foo`
- `/lean-spec:review-spec foo`
- runner command:
- `/lean-spec:run-next foo`

Each wrapper should:

1. call the CLI
2. receive current phase instructions
3. present a short role contract to the current agent
4. stop after phase output is complete

`/lean-spec:run-next` is the canonical runner command name for semi-auto execution.

It is preferred over names like `/lean-spec:auto-run` because:

- it is imperative and neutral
- it works in `semi-auto`, where a human may re-run it after approval gates
- it also works in future `auto` loops without implying full unattended execution in every context

### 4. Minimal Hooks

Hooks remain optional guardrails, but their job changes.

Hooks should only:

- deny invalid writes or commands
- inject a very short phase hint when needed
- never inject long workflow essays
- never become a second workflow engine

### 5. Explicit Human Gates

`manual` operation remains the default.

In `semi-auto`, the required human gates are:

1. approve plan
2. approve final close

In `auto`, these gates are removed and the orchestrator may operate the full lifecycle.

This keeps the current trust model while making future autonomy possible.

### 6. Stateless Runner

When a runner exists in `semi-auto` or `auto`, it must be stateless.

It may:

- read `workflow.json`
- call the CLI
- read CLI output
- invoke the next role or command

It must not:

- store separate lifecycle state
- infer a hidden workflow position
- become a second source of truth

## User Stories

### Planning

As a user, I want to start a feature in a planning terminal using a stronger model so that the plan is produced by the correct role and recorded in workflow state.

### Implementation

As a user, I want to switch to a cheaper implementation model and have the system enforce implementation-only permissions so that cost is reduced without sacrificing discipline.

### Review

As a user, I want formal review to route back to the planning/review role so that the implementation agent does not mark its own work as complete.

### Resume

As a user, I want to resume after compaction or interruption by reading deterministic workflow state instead of relying on session memory.

### Future Autonomy

As a user, I want the workflow engine to support semi-auto handoff between roles with plan/close approvals, and later support full auto execution with no human gates.

## Operating Modes

### 1. Manual Mode

Default mode.

Characteristics:

- human triggers every phase transition
- human chooses which terminal, agent, or model runs the next phase
- CLI validates state and ownership, but does not auto-advance

### 2. Semi-Auto Mode

Reduced human involvement with two required gates.

Characteristics:

- the workflow runner may advance phases automatically
- the system pauses for:
  1. plan approval
  2. close approval
- implementation, review, and fix loops may continue automatically between those gates
- v2 provides CLI-complete support for this mode
- host-specific runner support is optional in v2

### 3. Auto Mode

Full lifecycle automation.

Characteristics:

- the orchestrator or workflow runner may advance all phases
- no human gates are required
- validations and ownership rules still apply
- intended for future mature workflows with high trust in outputs
- full host-agnostic execution is not a committed v2 deliverable

## Proposed Lifecycle

Initial lifecycle:

1. `drafting_plan`
2. `waiting_plan_approval`
3. `implementing`
4. `reviewing`
5. `applying_fixes`
6. `ready_for_close`
7. `waiting_close_approval`
8. `closed`
9. `blocked`

This lifecycle should be represented in `workflow.json`, not inferred only from chat context.

Operating mode determines how transitions occur:

- `manual`: transitions happen only through explicit human-triggered commands
- `semi-auto`: transitions may auto-progress except at plan and close approvals
- `auto`: transitions may auto-progress end-to-end when validations pass

`reviewing` and `applying_fixes` are intentionally distinct phases because they have different role ownership, write permissions, and completion conditions.

## Proposed Control File

Example:

```json
{
  "workflow_version": 2,
  "slug": "todo-app-zustand",
  "mode": "semi-auto",
  "phase": "implementing",
  "role": "coder",
  "status": "active",
  "plan_approved": true,
  "close_approved": false,
  "requires_human_approval": false,
  "allowed_writes": [
    "notes_artifact",
    "project_code",
    "project_tests"
  ],
  "last_command": "implement-spec",
  "blocked_reason": null,
  "created_at": "2026-04-16 15:10 NZST",
  "updated_at": "2026-04-16 15:40 NZST"
}
```

## Scope

### In Scope for v2

- per-feature `workflow.json`
- Node.js CLI for phase orchestration and validation
- deterministic phase transitions
- operating modes: `manual`, `semi-auto`, `auto`
- structured instructions output
- thin wrappers for Claude, Gemini, OpenCode, and Codex-compatible patterns where possible
- deny-first validation for artifact ownership
- human approval commands for plan and close
- CLI-complete support for `semi-auto`
- project-config-resolved named write aliases

### Out of Scope for initial v2

- building a sophisticated autonomous planner/reviewer runtime beyond the mode-aware CLI/state model
- shipping a universal built-in runner across all supported host tools
- full host-agnostic `auto` execution
- background daemons
- remote workflow coordination
- large plugin ecosystem
- broad schema customization
- multi-repo or team-level orchestration

## Requirements

### R1. Single Source of Workflow State

The system must store current operating mode, lifecycle, and role state in a single machine-readable file per feature.

### R2. Deterministic Phase Transitions

The system must validate allowed transitions before changing phase.

Examples:

- cannot implement before plan approval
- cannot close before review/fixes are resolved
- cannot move to review if implementation phase has not been completed or deliberately marked partial/blocked

The system must also enforce mode-aware behavior:

- `manual` must not auto-advance
- `semi-auto` must pause at plan approval and close approval
- `auto` may advance without human approval when validations pass

`reviewing` and `applying_fixes` must remain separate phases.

### R3. Role Ownership Enforcement

The system must enforce artifact ownership at the phase level.

Minimum rules:

- `Architect` owns `spec.md`
- `Architect` owns `review.md`
- `Coder` owns `notes.md`
- `Coder` cannot modify `spec.md` or `review.md` during implementation
- planning/review phases must not modify product code unless explicitly allowed by a future command

Allowed write permissions should be expressed through named aliases resolved from project configuration, not hardcoded repo-specific paths.

### R4. Structured CLI Output

The CLI should support human-readable output and JSON output for wrappers and automation.

Minimum commands should expose:

- current mode
- current phase
- active role
- allowed writes
- next expected action
- approval requirements
- next-step metadata for runners:
  - `next_phase`
  - `next_role`
  - `approval_required`
  - `can_auto_advance`
  - `dispatch_hint`
  - `suggested_agent`

### R5. Minimal Prompt Contracts

Every phase should have a short generated contract that includes only:

- active role
- current objective
- owned artifacts
- forbidden writes
- completion condition

### R6. Resume Reliability

A user must be able to resume from `workflow.json` and feature artifacts alone, without relying on the prior chat history.

Resume behavior must work consistently across all three operating modes.

### R7. Cross-Platform Tooling

The v2 implementation should use Node.js and TypeScript/JavaScript to support macOS, Linux, and Windows more reliably than shell-only orchestration.

### R8. Keep Hooks Optional and Small

The system should work even if host-tool hooks are limited or unavailable. Hooks may enhance enforcement, but must not be essential to the core lifecycle.

### R9. Stateless Runner Contract

If a runner is used, it must read current state from `workflow.json` and CLI output only.

It must not maintain separate lifecycle memory or hidden state.

## Success Metrics

### Primary Metrics

- zero successful architect-artifact writes during implement phase without explicit CLI-permitted override
- successful resume after context compaction
- lower average prompt size per phase
- fewer stuck/looping hook incidents
- consistent behavior across manual, semi-auto, and auto execution paths

### Practical Metrics

- user can complete a full plan -> implement -> review -> close flow with two terminals and one shared repo
- invalid phase actions are rejected deterministically
- implementation phase can be run on a cheaper model without accidental plan/review edits
- semi-auto CLI output is sufficient for a host-specific runner to determine the next step without hidden state

## Risks

### Risk: too much complexity

Mitigation:
- keep CLI surface small
- avoid multiple state files
- avoid background services

### Risk: wrappers diverge across tools

Mitigation:
- keep core logic in CLI
- keep tool-specific wrappers very thin

### Risk: validation becomes brittle

Mitigation:
- validate only the most important invariants first
- keep ownership checks simple and explicit

### Risk: users bypass the CLI

Mitigation:
- make the CLI ergonomic enough that bypassing it is inconvenient
- use lightweight deny hooks where supported

## Open Questions

1. Should product-code writes during review be completely forbidden in v2, or only discouraged?
2. How much wrapper generation should be built into v2 versus maintained manually per tool?
3. Should v2 include a reference host-specific semi-auto runner example for Claude Code only, or no runner example at all?

## Recommendation

Proceed with `lean-spec v2` as:

- a new implementation on a new branch
- a small Node.js CLI
- one `workflow.json` per feature
- thin slash-command wrappers
- deny-first validation
- support for `manual`, `semi-auto`, and `auto` modes
- plan/close approvals in `semi-auto`
- `manual` fully implemented
- `semi-auto` CLI-complete and runner-optional
- `auto` specified but deferred as a full execution target

This preserves the original cost-saving and role-discipline intent while making the system more resilient, more portable, and more autonomy-ready.
