# Codex host adapter and deterministic orchestration — requirements spec

> Status: DRAFT FOR FADY REVIEW
> Branch: `feat/codex-host-adapter`
> Research source: `docs/CODEX_ADAPTER_PLAN.md`
> This is a standalone implementation spec. It is not a lean-spec lifecycle artifact.

## 1. Goal

Make lean-spec work natively in Codex while keeping the framework agent-agnostic. Preserve the existing deterministic feature lifecycle, phase owners, artifacts, gates, and one-spec-at-a-time rule.

The result must support Claude Code and Codex from one canonical source. Future hosts must be able to reuse the same core without copying lifecycle logic.

## 2. Non-negotiable rules

1. The feature lifecycle stays:

   ```text
   specifying → implementing → reviewing → closed
                       ↑           │
                       └ NEEDS_FIXES
   ```

2. Every phase keeps one owner, one mandatory artifact, and one gate.
3. Skills describe work. Host hooks enforce host events. `bin/lean-spec` is the only state mutator.
4. `features/<slug>/workflow.json` and `.lean-spec/auto.json` must never be written or deleted outside the CLI.
5. Canonical skills use host-neutral wording. Generated or packaged host files must not become a second hand-maintained source.
6. No agent may guess a product, compatibility, security, migration, or acceptance requirement.
7. Greenfield and brownfield projects use the same lifecycle.
8. This release supports macOS and Linux. Keep Python 3.11+ stdlib, Bash, TOML, JSON, Markdown, and the existing BATS suite. Do not add a runtime dependency or attempt a Windows-first rewrite in this release.
9. Existing Claude behaviour stays compatible by default.

## 3. Architecture boundaries

### 3.1 Core CLI

The CLI owns:

- Feature and automatic-run state.
- Atomic transitions and locking.
- Artifact validation.
- Readiness checks.
- Semantic workflow outcomes.
- Explicit owner, artifact, gate, feature, and run identity.

The CLI must not emit Claude or Codex invocation syntax in its semantic JSON contract.

### 3.2 Project artifact layout

All lean-spec project-owned artifacts live under one root-level `.lean-spec/`
directory:

```text
.lean-spec/
  rules.toml
  PRD.md
  CONSTITUTION.md
  auto.json
  features/<slug>/
    workflow.json
    spec.md
    notes.md
    review.md
    evidence/
```

Host-owned files remain outside this directory: `AGENTS.md`, `.agents/`, and
`.codex/` belong to their respective hosts. The CLI must provide an explicit,
idempotent migration with a dry run. It must never silently mix old `docs/` or
`features/` artifacts with the new layout.

### 3.3 Canonical skills

`skills/*/SKILL.md` remains the canonical skill source. Wording must refer to semantic operations such as `spec`, `implement`, and `review`, not host commands such as `/lean-spec:spec` or `$lean-spec-spec`.

Host metadata may be generated from the canonical source. CI must regenerate it and fail on drift.

### 3.4 Host adapters

A host adapter may only handle:

- Skill invocation syntax and discovery paths.
- Hook payload normalization and response rendering.
- Agent definition format.
- Model and reasoning-effort names.
- Authoritative host instruction files.
- Installation and packaging.

It must not own phases, gates, state schemas, artifact rules, or auto-loop decisions.

### 3.5 Delivery

Normal installation must not depend on symbolic links. Symlinks are allowed only for contributor development.

Codex should support:

1. A normal Codex plugin install when the required component is supported by the documented plugin format.
2. An idempotent project bootstrap for files that must live in the target repository.
3. A direct installer for source checkouts, local development, and CI.

## 4. Semantic CLI contract

Machine-readable workflow commands must return a versioned object with this common shape:

```json
{
  "schema_version": 1,
  "outcome": "READY",
  "step": "implement",
  "slug": "example-feature",
  "owner": "coder",
  "artifact": "notes.md",
  "gate": "implementation-artifact-valid"
}
```

Allowed outcomes are:

- `READY`: the named step may run.
- `NEEDS_INPUT`: one required user decision is missing.
- `BLOCKED`: progress cannot continue until a named external or technical blocker is resolved.
- `COMPLETE`: no workflow work remains for the requested scope.

`NEEDS_INPUT` is a result, not a lifecycle phase. It must include:

```json
{
  "outcome": "NEEDS_INPUT",
  "input_scope": "project|feature",
  "slug": "example-feature",
  "question": "One specific question",
  "reason": "Why this decision is required",
  "resume_step": "plan|spec"
}
```

Only one question may be active in one result. Missing or malformed required fields must fail loudly.

Human-readable output may remain for compatibility. Host adapters must use the semantic JSON output.

## 5. Interview and requirement rules

### 5.1 Information order

Before asking a question, the planner or architect must inspect:

1. Existing PRD and Constitution.
2. Relevant feature artifacts and closed acceptance criteria.
3. Repository manifests, README, tests, CI, and relevant code.
4. Explicit defaults in `.lean-spec/rules.toml`.

Facts that can be verified must not be asked as interview questions.

### 5.2 Interactive `plan`

- First run uses the current short project interview.
- Brownfield runs prefill stack, test, CI, and repository facts before asking.
- `plan --refine` means “update existing project documents using new information.” It may handle a blocker, repository change, compatibility decision, or incomplete context without restarting the full interview.
- Ask one targeted question at a time and only for a required decision.
- Validate the final PRD and Constitution through the CLI.

### 5.3 Interactive `spec`

- The architect may return `NEEDS_INPUT` instead of writing a speculative spec.
- The host turns that result into a targeted interview, one question at a time.
- The architect receives each answer and continues only when the feature has testable acceptance criteria.
- The final spec records compatibility and regression decisions that affect implementation.

### 5.4 `--no-confirm`

`--no-confirm` skips approval of the proposed next slice. It does not grant permission to invent missing requirements.

- If information is sufficient, continue without asking for proposal approval.
- If an explicit project default resolves the decision, apply it and continue.
- If a required decision is missing, return `NEEDS_INPUT`, persist it through CLI-owned auto state when an auto run exists, and stop safely.
- Rerunning after the answer must resume the same feature and expected phase.

## 6. Greenfield and brownfield readiness

Both project situations use the same feature phases. Do not persist a fixed
`greenfield` or `brownfield` label: a project can begin as a new product and
later need compatibility controls. The interview must ask whether existing
behaviour, users, data, APIs, or integrations must be preserved. A scaffolded
Next.js/Shadcn/Vitest project with no product behaviour is greenfield.

Before an unattended brownfield run, readiness validation must confirm that the project documents state:

- The existing system or affected area.
- Existing behaviour that must remain unchanged.
- Compatibility limits.
- Migration requirements, or an explicit statement that none are needed.
- Regression checks and the configured verification command.

These requirements should be added to the existing PRD structure. Do not add a separate permanent baseline artifact unless implementation evidence proves it is needed.

An interactive run may interview to fill a readiness gap. An unattended run returns `NEEDS_INPUT` and does not start implementation.

## 7. Deterministic automatic execution

### 7.1 CLI ownership

Add a CLI operation that advances automatic execution from the current authoritative state. The preferred interface is:

```text
bin/lean-spec auto tick --run-id <id> --event-id <id>
```

The exact internal function layout may follow existing code style, but the behaviour below is required.

`auto tick` must:

- Lock automatic state before reading and writing it.
- Check the supplied run ID.
- Check the expected feature and phase.
- Consume a unique event ID.
- Return the same result without a second mutation when an event is repeated.
- Choose work by explicit slug and state, never modification time.
- Perform any cycle count, feature switch, pending-input, blocked, complete, or disarm mutation itself.
- Write atomically and verify the result after replacement.
- Return the semantic outcome and next step.

Hooks and skills may call `auto arm`, `auto tick`, `auto status`, and `auto disarm`. They must never rewrite or delete `.lean-spec/auto.json` themselves.

### 7.2 Auto state

CLI-owned auto state must include enough data to reject stale or duplicate events:

- Schema version.
- Run ID.
- Mode: one feature or all features.
- Current feature slug and expected phase.
- Cycle and feature limits.
- Completed-feature count.
- Confirmation policy.
- Current run status.
- Last accepted event ID or an equivalent bounded duplicate guard.
- Pending `NEEDS_INPUT` data when present.

### 7.3 `auto-all --no-confirm`

The command must compose the same canonical one-slice `spec` and `auto` operations used interactively. The auto-all skill and Stop hook must not contain a second prose implementation of spec selection or artifact validation.

It must:

- Process one feature at a time.
- Create at most one new spec per spec operation.
- Stop on `NEEDS_INPUT`, `BLOCKED`, a failed gate, a cycle cap, or a feature cap.
- Return `COMPLETE` only when the PRD has no undelivered scope.
- Resume the same run after required input is supplied.

## 8. Artifact and dispatch discipline

Every agent dispatch must explicitly carry:

- Feature slug.
- Owner role.
- Expected phase.
- Artifact path.
- Gate that will validate the artifact.
- Run or work identity.
- Constitution content or its verified path.

Modification-time selection and implicit “latest feature” selection are forbidden.

Every enforceable artifact rule must live in CLI validation. This includes visual-review evidence location, required citations, and required visual sections. Skill prose may explain a rule but cannot be its only gate.

## 9. Codex adapter requirements

### 9.1 Authoritative locations

- Skills: plugin-provided skills or project `.agents/skills/`.
- Project instructions: root and per-directory `AGENTS.md` files.
- Custom agents: project `.codex/agents/*.toml`.
- Hooks: project or plugin Codex hook configuration.
- Command policy rules: `.codex/rules/*.rules`; these are execpolicy rules, not Claude-style instruction files.

Do not describe `.agents/` as the general authoritative instruction directory. It is the cross-tool skill location. `AGENTS.md` is authoritative for project instructions.

### 9.2 Skills

- Expose all current lean-spec skills in Codex.
- Preserve explicit-only invocation for mutating skills through documented Codex skill policy metadata.
- Keep read-only skills eligible for normal discovery where safe.
- Render Codex invocation syntax only in Codex-facing help or adapter output.

### 9.3 Agents

Generate project-scoped Codex agent TOML for architect, coder, and reviewer. Map the canonical owner role to Codex `model` and `model_reasoning_effort` settings without placing Codex model names in core state.

The adapter must support explicit per-dispatch overrides. For example, the coder may use `gpt-5.6-terra` with `medium` effort while the architect or reviewer uses a stronger setting.

### 9.4 Hooks

- Normalize Codex hook payloads before passing them to shared enforcement logic.
- Guard Codex file-edit tools, including `apply_patch`, against direct state-file changes.
- Parse target paths defensively and test absolute paths, traversal, case differences, and multi-file patches.
- Let `SubagentStop` validate the explicitly named feature and artifact.
- Let `Stop` call the CLI auto tick and render its result as the continuation reason.
- Store captured, sanitized Codex payloads as test fixtures.

Codex execpolicy rules may allow or prompt for command prefixes. They are defense in depth and must not be treated as path-level artifact enforcement.

### 9.5 Installation

Provide one documented normal path and one contributor path:

- Normal: install the Codex plugin, then run the lean-spec init/bootstrap skill in the target project.
- Direct fallback: run an idempotent installer from a source checkout.
- Contributor: optional symlinks to canonical skills and scripts.

The bootstrap must install or merge only what Codex needs, including custom agent TOML, hook configuration, and a marked lean-spec block in root `AGENTS.md`. It must preserve user content, be idempotent, and show every changed file.

If the documented Codex plugin format cannot package a required component, the init/bootstrap step must install that component into the project. Do not rely on an undocumented manifest field.

## 10. Verification requirements

Add deterministic tests for:

1. Every semantic outcome and required JSON field.
2. Invalid or ambiguous architect output returning `NEEDS_INPUT` or failing safely, never being treated as completion.
3. Interactive question order and one-question results.
4. `--no-confirm` continuing with sufficient information.
5. `--no-confirm` stopping on a missing required decision.
6. Greenfield readiness.
7. Brownfield readiness, compatibility, migration, and regression requirements.
8. Auto locking, atomic writes, stale run IDs, expected-phase mismatches, and duplicate event IDs.
9. One-feature-at-a-time auto-all behaviour and every stop condition.
10. Removal of modification-time feature selection.
11. CLI validation of visual evidence requirements.
12. Claude compatibility for existing commands, text output, hooks, and skills.
13. Codex hook payload fixtures and state-write denial.
14. Codex agent generation and model/effort mapping.
15. Installer idempotency and preservation of existing `AGENTS.md` and Codex config.
16. Generated host files matching canonical skill sources.
17. A Codex end-to-end fixture that moves one feature from `specifying` to `closed` and proves a direct state edit is rejected.

All existing BATS tests must remain green. New behaviour must be covered before implementation code is accepted.

## 11. Backward compatibility

- Claude remains the default host when no host is configured.
- Existing human-readable CLI output remains available unless a documented breaking change is approved.
- Existing workflow files are accepted or migrated deterministically by the CLI.
- Existing rules without `[project]` must receive an explicit, documented migration error or a safe interactive migration path. Do not silently guess the project type.
- Existing skill names remain available on Claude.

## 12. Out of scope

- Changing the four feature phases.
- Batch decomposition of the full PRD.
- Parallel feature implementation.
- A web dashboard, server, database, or telemetry work.
- Hand-maintained copies of skills for each host.
- Symlinks as the normal user installation method.
- Claiming shell command policy is a complete state-file security boundary.
- Adding Gemini or OpenCode native-host support in this feature.

## 13. Definition of done

This work is complete when:

- Core workflow decisions and automatic state changes are CLI-owned and host-neutral.
- Interactive interviews collect missing decisions without asking for facts already in the repository.
- Unattended runs continue without proposal confirmation but stop safely on missing requirements.
- Greenfield and brownfield readiness are both enforced.
- Claude remains compatible.
- Codex can be installed, initialized, and used through its native skills, hooks, agents, and `AGENTS.md` instruction chain.
- The full BATS suite and the Codex end-to-end fixture pass.
- Installation and architecture documentation match the tested implementation.

## 14. Verified Codex references

- Skills: https://developers.openai.com/codex/skills
- Project instructions: https://developers.openai.com/codex/agents-md
- Subagents and model settings: https://developers.openai.com/codex/subagents
- Hooks: https://developers.openai.com/codex/hooks
- Rules: https://developers.openai.com/codex/rules
- Plugins: https://developers.openai.com/codex/plugins
- Plugin building: https://developers.openai.com/codex/build-plugins
- Non-interactive execution: https://developers.openai.com/codex/noninteractive
