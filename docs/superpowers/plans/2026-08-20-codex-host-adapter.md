# Codex Host Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make lean-spec host-neutral and usable from Codex without weakening its deterministic lifecycle.

**Architecture:** `bin/lean-spec` owns semantic state, layout, validation, and automatic-run decisions. Canonical `skills/` describe lifecycle work in host-neutral language. Claude and Codex adapter files only translate host events, commands, and agent definitions to that core contract.

**Tech Stack:** Python 3.11 stdlib, Bash, TOML, JSON, Markdown; macOS and Linux.

> **Superseded test note:** this historical plan used BATS. The approved
> delivery replaces it with direct Python 3.11 `unittest` coverage before
> removing BATS.

**Spec:** `docs/CODEX_ADAPTER_SPEC.md`

## Global Constraints

- Do not change the four phases or allow parallel feature execution.
- Do not add dependencies or make Windows first-class in this release.
- `.lean-spec/` owns project workflow artifacts; `.codex/`, `.agents/`, and `AGENTS.md` stay host-owned.
- The CLI is the only writer of workflow and auto state. Hooks never mutate it.
- `--no-confirm` may skip approval, never missing requirements.
- Keep Claude compatibility or provide an explicit, tested migration.
- Every task starts with a failing Python unittest and ends with the affected
  Python tests passing.

---

### Task 1: Canonical project layout and explicit migration

**Files:**
- Modify: `bin/lean-spec`
- Modify: `hooks/pre-tool-use-guard.sh`
- Modify: `hooks/subagent-stop-gate.sh`
- Modify: `tests/helpers.bash`, existing path-sensitive `tests/*.bats`
- Create: `tests/cli_layout_migration.bats`
- Modify: `.gitignore`, `examples/gitignore`, `README.md`, `templates/*.md`

**Interfaces:**
- Produces `artifact_root(root) -> <root>/.lean-spec` and all artifact path helpers.
- Produces `lean-spec migrate-layout [--dry-run]`, which reports a deterministic move plan before changing paths.
- Consumes legacy `docs/{PRD,CONSTITUTION}.md` and `features/<slug>/` only during migration.

- [x] **Step 1: Write layout migration tests**

Cover a fresh `ensure demo` producing `.lean-spec/features/demo/workflow.json`, a `--dry-run` which changes no paths, a successful legacy move, and refusal when old and new locations conflict.

```bash
lean_spec ensure demo
[ -f .lean-spec/features/demo/workflow.json ]
run lean_spec migrate-layout --dry-run
[ ! -e .lean-spec/PRD.md ]
```

- [x] **Step 2: Run the focused tests and verify failure**

Run: `bats tests/cli_layout_migration.bats`

Expected: FAIL because the current CLI uses `features/` and has no migration command.

- [x] **Step 3: Implement path helpers and migration**

Replace direct project-artifact joins with helpers:

```python
def artifact_root(root):
    return os.path.join(root, ".lean-spec")

def feature_dir(root, slug):
    return os.path.join(artifact_root(root), "features", slug)
```

`migrate-layout` must build the complete source/destination list, validate every destination before the first move, print it for `--dry-run`, and fail on conflicts. Use `os.replace` only after validation; do not delete legacy content.

- [x] **Step 4: Update guards, fixtures, templates, and docs**

Protect `.lean-spec/features/*/workflow.json`, update tests and gitignore patterns, and use only `.lean-spec/{PRD.md,CONSTITUTION.md,features/}` in generated-project documentation.

- [x] **Step 5: Verify and commit**

Run: `bats tests/cli_layout_migration.bats tests/cli_ensure.bats tests/cli_validate.bats tests/hooks_pre_tool_use_guard.bats`

Commit: `git commit -m "feat: move project artifacts under lean-spec"`

### Task 2: CLI-owned automatic-run tick

**Files:**
- Modify: `bin/lean-spec`
- Modify: `hooks/stop-auto-driver.sh`
- Modify: `hooks/subagent-stop-gate.sh`
- Modify: `tests/cli_auto.bats`, `tests/hooks_stop_auto_driver.bats`, `tests/hooks_subagent_stop_gate.bats`
- Create: `tests/cli_auto_tick.bats`

**Interfaces:**
- Produces `lean-spec auto tick --run-id <id> --event-id <id> [--json]`.
- `auto arm` writes `schema_version`, `run_id`, `slug`, `expected_phase`, and duplicate-event history.
- `SubagentStop` only validates a slug explicitly supplied by the host payload or auto run; it never selects the newest feature.

- [x] **Step 1: Write failing tick tests**

Test stale run ID, mismatched phase, duplicate event replay, cycle cap, completed chain transition, and only-CLI mutation:

```bash
lean_spec auto arm demo
run lean_spec auto tick --run-id "$run_id" --event-id event-1 --json
[ "$status" -eq 0 ]
run lean_spec auto tick --run-id "$run_id" --event-id event-1 --json
[ "$output" = "$first_output" ]
```

- [x] **Step 2: Run focused tests and verify failure**

Run: `bats tests/cli_auto_tick.bats`

Expected: FAIL because `tick` does not exist and the hook writes/deletes state.

- [x] **Step 3: Implement locked semantic tick**

Use one `.lean-spec/.auto.lock` flock around load, validate, transition, and atomic replacement. The result is JSON with `schema_version`, `outcome`, `slug`, `expected_phase`, and `next_step`. A repeated accepted event returns the stored result with no second mutation.

- [x] **Step 4: Reduce the Stop hook to an adapter**

The hook obtains the current run ID from `auto status --json`, creates a host event ID, calls `auto tick`, and renders only its continuation reason. It must contain no Python state update, `rm`, feature scanning, or mtime logic.

- [x] **Step 5: Make SubagentStop explicit**

Read the host-provided feature identity. If absent, do nothing; never select by mtime. Validate the phase artifact only for that identity.

- [x] **Step 6: Verify and commit**

Run: `bats tests/cli_auto.bats tests/cli_auto_tick.bats tests/hooks_stop_auto_driver.bats tests/hooks_subagent_stop_gate.bats`

Commit: `git commit -m "feat: make auto progression CLI-owned"`

### Task 3: Readiness outcomes and host-neutral canonical skills

**Files:**
- Modify: `bin/lean-spec`, `templates/PRD.md`, `templates/CONSTITUTION.md`
- Modify: `skills/{plan,spec,auto,auto-all,init,status}/SKILL.md`
- Modify: relevant existing `tests/cli_*.bats`, `tests/scaffold.bats`
- Create: `tests/cli_readiness.bats`, `tests/skills_host_neutral.bats`

**Interfaces:**
- Produces versioned semantic outcomes: `READY`, `NEEDS_INPUT`, `BLOCKED`, `COMPLETE`.
- `NEEDS_INPUT` contains exactly one question, reason, scope, slug, and resume step.

- [x] **Step 1: Write failing outcome and readiness tests**

Cover one missing compatibility decision, one no-confirm run with enough evidence, and a no-confirm run that returns one `NEEDS_INPUT` object rather than inventing a requirement.

- [x] **Step 2: Implement semantic JSON and readiness validation**

Add a shared `emit_outcome()` helper. Inspect project files before posing an interview question. Record existing behavior, compatibility, migration, and regression requirements in the PRD only when they exist; a scaffolding-only project records that no behavior must be preserved.

- [x] **Step 3: Rewrite canonical skill wording**

Remove host-specific invocation syntax from canonical instructions. Define `--no-confirm` as skip-proposal-approval only. Each mutating skill names its slug, phase, artifact, and CLI gate.

- [x] **Step 4: Verify and commit**

Run: `bats tests/cli_readiness.bats tests/skills_host_neutral.bats tests/scaffold.bats`

Commit: `git commit -m "feat: add deterministic readiness outcomes"`

### Task 4: Codex project adapter and installer

**Files:**
- Create: `.codex-plugin/plugin.json`
- Create: `adapters/codex/install.py`, `adapters/codex/hooks.json`, `adapters/codex/agents/*.toml`, `adapters/codex/AGENTS.md.fragment`
- Create: `adapters/codex/skills/*/SKILL.md` or a deterministic renderer
- Create: `tests/codex_installer.bats`, `tests/codex_hooks.bats`, `tests/codex_e2e.bats`
- Modify: `README.md`, `docs/CODEX_ADAPTER_PLAN.md`

**Interfaces:**
- Produces `python3 adapters/codex/install.py --project <path> [--dry-run]`.
- Installer writes or merges project `.agents/skills/`, `.codex/hooks.json`, `.codex/agents/`, and marked root `AGENTS.md` content idempotently.

- [x] **Step 1: Write failing installer and hook fixture tests**

Use a temporary git project with an existing `AGENTS.md` and `.codex/hooks.json`. Assert that user content remains, one lean-spec marked block exists after two installs, and an `apply_patch` payload targeting a state file is denied.

- [x] **Step 2: Implement the documented plugin surface**

Package only documented plugin components. Put canonical skill copies/generated files in the plugin. Keep project hooks, agents, and instruction fragments installed by the bootstrap when the plugin manifest cannot declare them.

- [x] **Step 3: Implement idempotent project bootstrap**

Use Python `pathlib` and explicit marker blocks. Parse and preserve supported JSON hook configuration. On an unsupported existing shape, fail before writing it. Generate role TOML using configured Codex model and effort mappings.

- [x] **Step 4: Implement Codex hook adapters**

Normalize Codex stdin payloads, deny direct `apply_patch` state edits, call the common SubagentStop and Stop logic, and render Codex decisions. Test absolute paths, traversal, case changes, and multi-file patches.

- [x] **Step 5: Verify and commit**

Run: `bats tests/codex_installer.bats tests/codex_hooks.bats tests/codex_e2e.bats`

Commit: `git commit -m "feat: add Codex project adapter"`

### Task 5: Explicit external CLI provider routing

**Files:**
- Create: `adapters/providers.py`
- Modify: `bin/lean-spec`, `.lean-spec/rules.toml` example, `README.md`
- Create: `tests/provider_routing.bats`

**Interfaces:**
- Consumes `{ provider, model, effort }` per owner.
- Produces validated argv for `claude`, `codex`, or `gemini`; it never invokes a shell string.

- [x] **Step 1: Write failing provider configuration tests**

Assert that an unspecified provider, unknown provider, missing executable, bad model mapping, unsupported effort, and unavailable authentication fail with an actionable message before any agent dispatch.

- [x] **Step 2: Implement provider validation and argv construction**

Accept only explicit `provider` values. Use `subprocess.run([...])`, not `shell=True`. Map Codex to `codex exec`, Claude to `claude -p`, and Gemini to `gemini -p`; use their structured output modes. Core validation still owns artifact gates.

- [x] **Step 3: Verify and commit**

Run: `bats tests/provider_routing.bats`

Commit: `git commit -m "feat: add explicit provider routing"`

### Task 6: Whole-branch verification and documentation

**Files:**
- Modify: `README.md`, `docs/CODEX_ADAPTER_PLAN.md`, `docs/CODEX_ADAPTER_SPEC.md`
- Modify: CI workflow only if existing macOS/Linux matrices need updated paths

- [x] **Step 1: Run the full BATS suite**

Run: `bats tests`

Expected: PASS on the supported macOS/Linux toolchain.

- [x] **Step 2: Run static drift checks**

Verify canonical skill metadata and generated Codex files are in sync, no hook writes state, and no source or test still treats root `docs/` or `features/` as the generated-project artifact root.

- [x] **Step 3: Update user documentation**

Document normal Codex install, direct installer, contributor symlink option, supported platforms, migration command, automatic-run commands, `NEEDS_INPUT`, and the explicit privacy decision: no lean-spec telemetry in this release.

- [x] **Step 4: Final review and commit**

Run: `git diff --check && bats tests`

Commit: `git commit -m "docs: document Codex host adapter"`
