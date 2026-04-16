# lean-spec v2 Implementation Plan

## Common Architecture

All features in this plan must follow these shared conventions.

### Tech Stack

- Node.js for orchestration and validation
- plain JavaScript or TypeScript, but keep runtime dependencies minimal
- JSON as the workflow state format
- cross-platform file/path handling via Node path utilities

### Architectural Rules

- the CLI is the workflow kernel
- the CLI does orchestration and validation only, never intelligence
- agents do planning, implementation, review, and fixes
- `workflow.json` is the single source of truth for lifecycle and role state
- `workflow.json` is also the single source of truth for operating mode
- tool-specific slash commands are thin wrappers around the CLI
- hooks are optional enhancements, not core workflow infrastructure
- validations must be explicit and deterministic
- any runner is stateless and reads only `workflow.json` plus CLI output

### Operating Modes

- `manual`
  - default mode
  - human advances every phase explicitly
- `semi-auto`
  - workflow runner may advance phases automatically
  - pauses at two human gates:
    - approve plan
    - approve close
  - v2 fully supports this at the CLI/state level
  - host-specific runner support is optional
- `auto`
  - workflow runner may advance the full lifecycle automatically
  - no human gates
  - v2 defines this mode in state and contracts, but does not promise full host-agnostic execution

All features below must preserve one shared lifecycle model while allowing mode-specific transition behavior.

### Artifact Conventions

- feature root: `lean-spec/features/<slug>/`
- canonical artifacts:
  - `spec.md`
  - `notes.md`
  - `review.md`
  - `workflow.json`
  - `artifacts/`

### Ownership Rules

- `architect` owns `spec.md`
- `architect` owns `review.md`
- `coder` owns `notes.md`
- `coder` owns implementation files during implement/fix phases
- the CLI enforces current phase and allowed writes

### Write Scope Conventions

- do not hardcode repo-specific paths like `src/**` as universal defaults
- use named write aliases resolved from project configuration
- initial alias examples:
  - `spec_artifact`
  - `notes_artifact`
  - `review_artifact`
  - `project_code`
  - `project_tests`

## Feature 1: Define v2 Workflow Model

### Build

Define the v2 lifecycle, operating modes, roles, statuses, phase transitions, approval points, and ownership rules as a single canonical design in code and docs.

### Expect

- one clear lifecycle model for v2
- one clear operating-mode model for v2
- one agreed role/ownership model
- one transition table that later CLI commands enforce
- reviewing and applying_fixes are locked as distinct phases

### Notes

- keep lifecycle minimal
- include plan approval and close approval
- avoid adding states that do not drive real validation behavior
- define exactly how `manual`, `semi-auto`, and `auto` change transition behavior

## Feature 2: Implement `workflow.json` Schema And Helpers

### Build

Add the `workflow.json` file format, including mode, default values, schema validation, read/write helpers, and timestamp handling.

### Expect

- new features can create a valid `workflow.json`
- existing features can be loaded deterministically
- invalid or missing workflow state surfaces clear errors
- operating mode is explicit and validated

### Notes

- use one file only
- support both human-readable and machine-safe fields
- keep fields stable for future automation
- default mode should be `manual`

## Feature 3: Add Automated Test Harness

### Build

Create the initial automated test setup for deterministic v2 behavior.

### Expect

- phase transition rules can be tested before command behavior expands
- ownership validation has automated coverage
- resume and state-loading behavior can be verified deterministically
- cross-platform path handling can be tested explicitly

### Notes

- prioritize tests for:
  - transition rejection
  - schema loading and validation
  - alias resolution
  - ownership enforcement
  - resume/recovery behavior

## Feature 4: Build Core CLI Skeleton

### Build

Create the Node CLI entrypoint, command parsing, shared utilities, structured output mode, and error handling.

### Expect

- one executable CLI surface for v2
- shared human output and JSON output modes
- stable place to add orchestration and validation commands

### Notes

- keep command names aligned with current lean-spec terminology
- avoid overengineering plugin systems or schema engines

## Feature 5: Implement Phase Commands

### Build

Implement the first set of deterministic workflow commands:

- `start-spec`
- `approve-plan`
- `implement-spec`
- `review-spec`
- `apply-fixes`
- `ready-to-close`
- `approve-close`
- `status`
- `validate`

### Expect

- commands update `workflow.json` consistently
- invalid transitions are denied
- each command emits the correct active role and next action
- mode-specific pause and advance behavior is enforced

### Notes

- keep each command narrow
- status and validate must work without prior chat context
- auto-advance logic must remain deterministic and explicit
- command output should be designed to support future runner consumption

## Feature 6: Add Scaffolding And Artifact Bootstrapping

### Build

Move feature scaffolding into the CLI so commands can create or repair:

- feature directory
- `spec.md`
- `notes.md`
- `review.md`
- `artifacts/`
- `workflow.json`

### Expect

- `start-spec` can initialize a clean feature reliably
- missing artifacts can be restored safely
- scaffolding is deterministic and reusable across tools

### Notes

- keep current artifact naming
- preserve compatibility with existing lean-spec layout

## Feature 7: Add Ownership And Write Validation

### Build

Implement preflight and postflight validation for phase-specific ownership and allowed writes.

### Expect

- implement phase rejects edits to `spec.md` and `review.md`
- review/planning phases reject unauthorized source-code changes where intended
- validation messages are short and explicit
- named aliases resolve to project-specific paths at runtime

### Notes

- start with the highest-value invariants only
- prefer explicit checks over heuristic checks

## Feature 8: Generate Minimal Phase Contracts

### Build

Add CLI output that generates concise phase-specific instructions for the active role.

### Expect

- every phase emits a small contract containing role, owned artifacts, forbidden writes, and completion condition
- prompt size is materially smaller than v1 reminder hooks

### Notes

- this output is for wrappers and agents
- avoid repeating full workflow philosophy

## Feature 9: Convert Existing Slash Commands Into Thin Wrappers

### Build

Refactor Claude, Gemini, and OpenCode command assets so they call the CLI and present the returned phase contract, instead of embedding heavy orchestration logic.

### Expect

- host-tool commands become lightweight
- behavior across tools becomes more consistent
- orchestration logic lives in one place
- `/lean-spec:run-next` is the canonical semi-auto runner command name

### Notes

- keep wrappers tool-specific only where required by the host
- keep command UX close to v1 to reduce adoption friction
- prefer `/lean-spec:run-next` over names like `/lean-spec:auto-run` to avoid implying end-to-end unattended execution in semi-auto mode

## Feature 10: Reduce Hooks To Deny-First Guardrails

### Build

Refactor hooks so they only:

- deny invalid writes or shell actions
- attach a short hint when useful
- avoid long repeated reminder payloads

### Expect

- fewer loops
- lower token overhead
- clearer failures when role drift happens

### Notes

- hooks must not become a second state machine
- the system should still work if hooks are unavailable

## Feature 11: Add Resume And Recovery Commands

### Build

Implement robust `status` and `validate` behavior that reconstructs the current state from `workflow.json` plus feature artifacts.

### Expect

- users can recover after compaction or interruption
- the next action is discoverable from deterministic state
- the CLI can explain what is blocking progress
- resume behavior is correct for `manual`, `semi-auto`, and `auto`

### Notes

- this is a key v2 reliability feature
- keep output concise but structured
- resume logic must explicitly handle approval-wait states such as `waiting_plan_approval` and `waiting_close_approval`

## Feature 12: Add Approval Gates

### Build

Implement explicit commands and state transitions for:

- plan approval
- close approval

### Expect

- implementation cannot start without approved plan
- closure cannot complete without explicit final approval
- future autonomy has well-defined pause points
- approvals are required in `semi-auto`
- approvals can be bypassed only in `auto`

### Notes

- keep approvals manual in v2
- avoid additional approval categories unless clearly necessary
- `manual` still uses explicit human-driven commands for every phase, not just approval commands

## Feature 13: Add Mode-Aware Next-Step Output

### Build

Add explicit CLI output fields that support semi-auto runner behavior without making the runner stateful.

### Expect

- CLI emits:
  - `next_phase`
  - `next_role`
  - `approval_required`
  - `can_auto_advance`
  - `dispatch_hint`
  - `suggested_agent`
- semi-auto is CLI-complete even when no built-in runner ships
- host-specific orchestrators can consume next-step output without hidden state

### Notes

- runner behavior is optional in v2
- do not build a universal cross-tool runner in v2
- output must remain tool-agnostic, with host hints kept lightweight

## Delivery Order

Build in this order:

1. Feature 1: Define v2 Workflow Model
2. Feature 2: Implement `workflow.json` Schema And Helpers
3. Feature 3: Add Automated Test Harness
4. Feature 4: Build Core CLI Skeleton
5. Feature 5: Implement Phase Commands
6. Feature 6: Add Scaffolding And Artifact Bootstrapping
7. Feature 7: Add Ownership And Write Validation
8. Feature 8: Generate Minimal Phase Contracts
9. Feature 11: Add Resume And Recovery Commands
10. Feature 12: Add Approval Gates
11. Feature 13: Add Mode-Aware Next-Step Output
12. Feature 9: Convert Existing Slash Commands Into Thin Wrappers
13. Feature 10: Reduce Hooks To Deny-First Guardrails

## Done Criteria

The initial v2 implementation is ready when:

- `workflow.json` is authoritative for lifecycle and role state
- `workflow.json` is authoritative for operating mode
- phase transitions are enforced by CLI logic
- automated tests cover transition rejection, ownership validation, state loading, and alias resolution
- current wrappers call the CLI instead of embedding orchestration logic
- implement phase cannot modify architect-owned artifacts
- plan approval and close approval exist as explicit gates
- `manual`, `semi-auto`, and `auto` modes are represented and enforced consistently
- semi-auto next-step output is sufficient for a stateless host runner to act without hidden state
- `status` and `validate` can recover the next action from deterministic state
- hooks are smaller, simpler, and non-essential
