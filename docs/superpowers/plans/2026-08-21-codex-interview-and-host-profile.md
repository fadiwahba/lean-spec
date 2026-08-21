# Codex Interview and Host Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a Codex-installed Lean Spec project start with a clear Codex profile and use Codex structured interview input when that tool is available.

**Architecture:** Keep canonical rules and skills host-neutral. The Codex installer renders the copied runtime rules with a `[hosts.codex]` role profile and appends one Codex-only interview instruction to the installed `plan` skill. The core plan skill specifies grouped rounds and the fail-loud `NEEDS_INPUT` outcome independently of host UI.

**Tech Stack:** Python 3.11 stdlib, TOML, Markdown, Python `unittest`.

**Spec:** [`docs/CODEX_ADAPTER_SPEC.md`](../../CODEX_ADAPTER_SPEC.md)

## Global Constraints

- Do not add a runtime dependency.
- Canonical skill text must remain host-neutral.
- At most three interview rounds; unresolved material input ends in `NEEDS_INPUT`.
- Host-native input is optional and has a Markdown fallback.
- Normal host dispatch must not require external provider configuration.

---

### Task 1: Lock the desired installer and interview contract with tests

**Files:**

- Modify: `tests/test_integration.py`
- Modify: `tests/test_repository_surface.py`

- [ ] **Step 1: Write failing tests**

Assert that a Codex installation copies a runtime `rules.toml` containing `[hosts.codex]`, without Claude provider defaults, and that its installed `lean-spec-plan` skill mentions the structured-input tool and Markdown fallback. Assert the canonical plan skill specifies grouped input and `NEEDS_INPUT` after unresolved material input.

- [ ] **Step 2: Run the targeted tests and verify RED**

Run:

```bash
python3 -m unittest tests.test_integration.CodexAdapterTests tests.test_repository_surface.RepositorySurfaceTests -v
```

Expected: failure because the current installer copies the Claude-biased example and does not render a Codex interview instruction.

### Task 2: Render the Codex profile and structured-input instruction

**Files:**

- Modify: `examples/rules.toml`
- Modify: `skills/plan/SKILL.md`
- Modify: `adapters/codex/install.py`

- [ ] **Step 1: Make the canonical template and interview contract host-neutral**

Remove default external-provider assignments from `[agents]`. Keep provider examples as comments. Define grouped rounds and `NEEDS_INPUT` for unresolved material requirements.

- [ ] **Step 2: Add the Codex-only renderer behavior**

After copying the runtime examples, append `[hosts.codex]` role defaults. When copying the `plan` skill, append instructions to call `request_user_input` when Codex offers it and otherwise use grouped Markdown questions.

- [ ] **Step 3: Run the targeted tests and verify GREEN**

Run:

```bash
python3 -m unittest tests.test_integration.CodexAdapterTests tests.test_repository_surface.RepositorySurfaceTests -v
```

Expected: PASS.

### Task 3: Verify, commit, push, and review

**Files:**

- Modify: all Task 1–2 files only

- [ ] **Step 1: Run full verification**

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
python3 adapters/codex/render_skill_policies.py --check
git diff --check
```

- [ ] **Step 2: Commit and push**

Stage only the plan, tests, template, skill, and installer. Commit with a concise subject and push `feat/codex-host-adapter`.

- [ ] **Step 3: Complete the Copilot gate**

Request Copilot review for the new SHA, poll until it reviews that SHA, and resolve only valid active findings within the five-round limit.
