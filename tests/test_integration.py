"""Direct Python 3.11 integration coverage for lean-spec processes."""

from __future__ import annotations

import json
import os
import stat
import sys
import tomllib
from concurrent.futures import ThreadPoolExecutor

from tests.integration_helpers import CLI, HOOKS, REPO_ROOT, IntegrationCase


class LifecycleTests(IntegrationCase):
    def test_ensure_is_idempotent_and_creates_normal_state(self) -> None:
        self.ensure()
        workflow = self.read_json(".lean-spec/features/demo/workflow.json")
        self.assertEqual(workflow["phase"], "specifying")
        self.assertEqual(workflow["history"], [])
        self.assertTrue(workflow["created_at"].endswith("Z"))
        before = (self.project / ".lean-spec/features/demo/workflow.json").read_text()
        self.require_ok(self.cli("ensure", "demo"))
        state_path = self.project / ".lean-spec/features/demo/workflow.json"
        self.assertEqual(state_path.read_text(), before)
        self.assertNotEqual(stat.S_IMODE(state_path.stat().st_mode), 0o600)

    def test_every_slug_accepting_command_rejects_path_escapes(self) -> None:
        commands = [
            ("ensure", "../escape"), ("advance", "../escape", "specifying", "implementing"),
            ("assert", "../escape", "specifying"), ("validate", "../escape", "spec.md"),
            ("next", "../escape"), ("status", "../escape"), ("auto", "arm", "../escape"),
        ]
        for command in commands:
            with self.subTest(command=command):
                result = self.cli(*command)
                self.assertEqual(result.returncode, 1)
                self.assertIn("invalid slug", result.stderr)
        self.assertFalse((self.project.parent / "escape").exists())

    def test_phase_gates_history_fix_loop_and_close(self) -> None:
        self.ensure()
        missing = self.cli("advance", "demo", "specifying", "implementing")
        self.assertEqual(missing.returncode, 2)
        self.assertIn("spec.md", missing.stderr)
        self.write_spec()
        self.require_ok(self.cli("advance", "demo", "specifying", "implementing"))
        self.write_notes()
        self.require_ok(self.cli("advance", "demo", "implementing", "reviewing"))
        self.write_review(verdict="NEEDS_FIXES")
        self.assertEqual(self.cli("advance", "demo", "reviewing", "closed").returncode, 2)
        self.require_ok(self.cli("advance", "demo", "reviewing", "implementing"))
        self.require_ok(self.cli("advance", "demo", "implementing", "reviewing"))
        self.write_review()
        self.require_ok(self.cli("advance", "demo", "reviewing", "closed"))
        workflow = self.read_json(".lean-spec/features/demo/workflow.json")
        self.assertEqual(workflow["phase"], "closed")
        self.assertEqual(len(workflow["history"]), 5)
        self.assertTrue(all(entry["at"].endswith("Z") for entry in workflow["history"]))

    def test_visual_close_requires_cited_existing_evidence(self) -> None:
        self.ensure()
        self.write_spec()
        self.require_ok(self.cli("advance", "demo", "specifying", "implementing"))
        self.write_notes()
        self.require_ok(self.cli("advance", "demo", "implementing", "reviewing", "--visual"))
        self.write_review()
        result = self.cli("advance", "demo", "reviewing", "closed")
        self.assertEqual(result.returncode, 2)
        self.assertIn("visual evidence", result.stderr)
        self.write(".lean-spec/features/demo/evidence/visual/home.png", "fixture")
        self.write(".lean-spec/features/demo/review.md", "## Verdict\nverdict: APPROVE\n\n## Visual Fidelity\n![home](evidence/visual/home.png)\n")
        self.require_ok(self.cli("advance", "demo", "reviewing", "closed"))

    def test_locking_allows_only_one_concurrent_advance(self) -> None:
        self.ensure()
        self.write_spec()
        with ThreadPoolExecutor(max_workers=12) as workers:
            results = list(workers.map(lambda _: self.cli("advance", "demo", "specifying", "implementing"), range(12)))
        self.assertEqual(sum(result.returncode == 0 for result in results), 1)
        workflow = self.read_json(".lean-spec/features/demo/workflow.json")
        self.assertEqual((workflow["phase"], len(workflow["history"])), ("implementing", 1))


class ValidationAndQueryTests(IntegrationCase):
    def test_rules_tdd_verdict_and_project_validation(self) -> None:
        self.ensure()
        self.write(".lean-spec/rules.toml", '[required_sections]\n"spec.md" = ["Scope", "Acceptance Criteria"]\n[max_tokens]\n"spec.md" = 3\n')
        self.write(".lean-spec/features/demo/spec.md", "## Scope\nOne two three four\n")
        result = self.cli("validate", "demo", "spec.md")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Acceptance Criteria", result.stderr)
        self.assertIn("max_tokens", result.stderr)
        self.write(".lean-spec/features/demo/review.md", "verdict: APPROVED\n")
        self.assertEqual(self.cli("validate", "demo", "review.md").returncode, 2)
        self.write(".lean-spec/features/demo/notes.md", "## What was built\nDone\n")
        self.assertEqual(self.cli("validate", "demo", "notes.md").returncode, 2)
        self.write(".lean-spec/rules.toml", "[defaults]\ntdd = false\n")
        self.require_ok(self.cli("validate", "demo", "notes.md"))
        self.write(".lean-spec/PRD.md", (REPO_ROOT / "templates/PRD.md").read_text())
        self.assertEqual(self.cli("validate", "--project", "PRD.md").returncode, 2)
        self.write_ready_project()
        self.require_ok(self.cli("validate", "--project", "PRD.md"))
        self.require_ok(self.cli("validate", "--project", "CONSTITUTION.md"))

    def test_no_tdd_feature_override_allows_validation_and_phase_gate(self) -> None:
        self.ensure()
        self.write_spec()
        self.require_ok(self.cli("advance", "demo", "specifying", "implementing", "--no-tdd"))
        self.write_notes(with_tdd=False)
        self.require_ok(self.cli("validate", "demo", "notes.md"))
        self.require_ok(self.cli("advance", "demo", "implementing", "reviewing"))
        self.assertFalse(self.read_json(".lean-spec/features/demo/workflow.json")["tdd"])

    def test_corrupt_rules_and_workflow_fail_loudly(self) -> None:
        self.ensure()
        self.write(".lean-spec/features/demo/spec.md", "# Spec\n")
        for rules in ('required_sections = "bad"\n', '[defaults]\ntdd = "yes"\n', '[max_tokens]\n"spec.md" = "many"\n'):
            with self.subTest(rules=rules):
                self.write(".lean-spec/rules.toml", rules)
                result = self.cli("validate", "demo", "spec.md")
                self.assertEqual(result.returncode, 1)
                self.assertIn("rules.toml", result.stderr)
                self.assertNotIn("Traceback", result.stderr)
        self.write(".lean-spec/rules.toml", "")
        self.write(".lean-spec/features/demo/workflow.json", "[]")
        result = self.cli("status", "demo")
        self.assertEqual(result.returncode, 1)
        self.assertIn("corrupt workflow.json", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_assert_next_status_and_all_json_are_host_neutral(self) -> None:
        self.ensure()
        self.require_ok(self.cli("assert", "demo", "specifying"))
        self.assertEqual(self.cli("assert", "demo", "implementing").returncode, 2)
        next_data = json.loads(self.cli("next", "demo", "--json").stdout)
        self.assertEqual((next_data["action"], next_data["step"], next_data["owner"]), ("skill", "implement", "coder"))
        self.ensure("second")
        report = self.cli("next", "--all", "--json")
        self.require_ok(report)
        self.assertEqual(sorted(item["slug"] for item in json.loads(report.stdout)), ["demo", "second"])
        self.assertEqual(json.loads(self.cli("status", "demo", "--json").stdout)["history_len"], 0)

    def test_next_routes_each_review_verdict(self) -> None:
        self.advance_to_reviewing()
        for verdict, step, code in (("APPROVE", "close", 0), ("NEEDS_FIXES", "fix", 0), ("BLOCKED", None, 3)):
            with self.subTest(verdict=verdict):
                self.write_review(verdict=verdict)
                result = self.cli("next", "demo", "--json")
                self.assertEqual(result.returncode, code)
                self.assertEqual(json.loads(result.stdout)["step"], step)

    def test_layout_migration_is_dry_run_safe_and_conflict_safe(self) -> None:
        self.write("docs/PRD.md", "# legacy\n")
        self.write("features/demo/workflow.json", "{}")
        self.require_ok(self.cli("migrate-layout", "--dry-run"))
        self.assertTrue((self.project / "docs/PRD.md").exists())
        self.require_ok(self.cli("migrate-layout"))
        self.assertTrue((self.project / ".lean-spec/PRD.md").exists())
        self.write("docs/PRD.md", "# old\n")
        conflict = self.cli("migrate-layout")
        self.assertEqual(conflict.returncode, 1)
        self.assertIn("conflict", conflict.stderr)


class AutoTests(IntegrationCase):
    def test_auto_arm_status_and_disarm_cover_all_configuration(self) -> None:
        self.ensure()
        self.require_ok(self.cli("auto", "arm", "demo", "--gates-on", "--chain-all", "--no-confirm", "--max-cycles=3", "--max-features=5"))
        state = self.read_json(".lean-spec/auto.json")
        self.assertEqual((state["slug"], state["max_cycles"], state["max_features"]), ("demo", 3, 5))
        self.assertTrue(state["gates_on"] and state["chain_all"] and state["no_confirm"])
        self.assertEqual(state["features_specced"], 0)
        status = self.cli("auto", "status", "--json")
        self.require_ok(status)
        self.assertTrue(json.loads(status.stdout)["armed"])
        self.require_ok(self.cli("auto", "disarm"))
        self.assertFalse((self.project / ".lean-spec/auto.json").exists())

    def test_auto_tick_is_duplicate_safe_and_rejects_stale_run_and_phase(self) -> None:
        self.ensure()
        self.require_ok(self.cli("auto", "arm", "demo"))
        state = self.read_json(".lean-spec/auto.json")
        self.write_spec()
        self.require_ok(self.cli("advance", "demo", "specifying", "implementing"))
        first = self.cli("auto", "tick", "--run-id", state["run_id"], "--event-id", "one", "--json")
        self.require_ok(first)
        replay = self.cli("auto", "tick", "--run-id", state["run_id"], "--event-id", "one", "--json")
        self.require_ok(replay)
        self.assertEqual(json.loads(replay.stdout), json.loads(first.stdout))
        stale = self.cli("auto", "tick", "--run-id", "stale", "--event-id", "two", "--json")
        self.assertEqual(stale.returncode, 2)
        changed = self.cli("auto", "tick", "--run-id", state["run_id"], "--event-id", "three", "--json")
        self.assertEqual(changed.returncode, 2)
        self.assertIn("expected phase", changed.stderr)

    def test_auto_no_confirm_persists_project_readiness_input(self) -> None:
        self.ensure()
        self.require_ok(self.cli("auto", "arm", "demo", "--chain-all", "--no-confirm"))
        state = self.read_json(".lean-spec/auto.json")
        self.write_spec()
        self.require_ok(self.cli("advance", "demo", "specifying", "implementing"))
        result = self.cli("auto", "tick", "--run-id", state["run_id"], "--event-id", "input", "--json")
        self.require_ok(result)
        self.assertEqual(json.loads(result.stdout)["outcome"], "NEEDS_INPUT")
        self.assertEqual(self.read_json(".lean-spec/auto.json")["status"], "needs_input")


class HookTests(IntegrationCase):
    def test_pre_tool_guard_enforces_state_files_and_handles_safe_input(self) -> None:
        denied = [
            {"tool_name": "Write", "tool_input": {"file_path": ".lean-spec/features/demo/workflow.json"}},
            {"tool_name": "Edit", "tool_input": {"file_path": "./.lean-spec/auto.json"}},
            {"tool_name": "apply_patch", "tool_input": {"command": "*** Begin Patch\n*** Update File: /repo/.lean-spec/features/demo/../demo/Workflow.json\n*** End Patch"}},
            {"tool_name": "Bash", "tool_input": {"command": "printf x > .lean-spec/auto.json"}},
        ]
        for payload in denied:
            with self.subTest(payload=payload):
                result = self.hook("pre-tool-use-guard.sh", payload)
                self.require_ok(result)
                self.assertEqual(json.loads(result.stdout)["hookSpecificOutput"]["permissionDecision"], "deny")
        for payload in ("not json", [], {"tool_name": "Write", "tool_input": {"file_path": "README.md"}}):
            with self.subTest(payload=payload):
                result = self.hook("pre-tool-use-guard.sh", payload)
                self.require_ok(result)
                self.assertEqual(result.stdout, "")

    def test_pre_tool_guard_handles_large_payload_and_special_root(self) -> None:
        payload = {"tool_name": "Write", "tool_input": {"file_path": ".lean-spec/auto.json", "content": "x" * 200_000}}
        result = self.hook("pre-tool-use-guard.sh", payload, env={"CLAUDE_PLUGIN_ROOT": '/tmp/a"b\\c\nd'})
        self.require_ok(result)
        self.assertEqual(json.loads(result.stdout)["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_subagent_stop_gate_uses_bound_agent_identity(self) -> None:
        self.ensure()
        self.write_spec()
        self.require_ok(self.cli("advance", "demo", "specifying", "implementing"))
        self.require_ok(self.cli("dispatch", "prepare", "demo", "coder"))
        self.require_ok(self.cli("dispatch", "bind", "agent-1", "lean-spec-coder"))
        payload = {"agent_id": "agent-1", "agent_type": "lean-spec-coder"}
        blocked = self.hook("subagent-stop-gate.sh", payload)
        self.require_ok(blocked)
        self.assertEqual(json.loads(blocked.stdout)["decision"], "block")
        self.write_notes()
        allowed = self.hook("subagent-stop-gate.sh", payload)
        self.require_ok(allowed)
        self.assertEqual(allowed.stdout, "")

    def test_stop_auto_driver_delegates_to_tick_and_returns_instruction(self) -> None:
        self.ensure()
        self.require_ok(self.cli("auto", "arm", "demo"))
        self.write_spec()
        self.require_ok(self.cli("advance", "demo", "specifying", "implementing"))
        result = self.hook("stop-auto-driver.sh", {})
        self.require_ok(result)
        decision = json.loads(result.stdout)
        self.assertEqual(decision["decision"], "block")
        self.assertIn("skills/review/SKILL.md", decision["reason"])
        self.assertEqual(json.loads(self.cli("auto", "status", "--json").stdout)["last_result"]["outcome"], "READY")


class CodexAdapterTests(IntegrationCase):
    def test_installer_dry_run_failure_and_idempotent_merge(self) -> None:
        dry_run = self.install_codex("--dry-run")
        self.require_ok(dry_run)
        self.assertIn(".agents/skills/lean-spec-plan", dry_run.stdout)
        self.assertFalse((self.project / ".agents").exists())
        self.write(".codex/hooks.json", '{"hooks": []}\n')
        failed = self.install_codex()
        self.assertNotEqual(failed.returncode, 0)
        self.assertFalse((self.project / ".lean-spec/runtime").exists())
        self.write(".codex/hooks.json", '{"hooks": {}}\n')
        self.write("AGENTS.md", "# Local rules\n")
        self.write(".lean-spec/rules.toml", '[hosts.codex]\nspec = { model = "gpt-5.6-terra", effort = "medium" }\n')
        self.require_ok(self.install_codex())
        self.require_ok(self.install_codex())
        self.assertEqual((self.project / "AGENTS.md").read_text().count("<!-- lean-spec:begin -->"), 1)
        architect = (self.project / ".codex/agents/lean-spec-architect.toml").read_text()
        self.assertIn('model = "gpt-5.6-terra"', architect)
        self.assertTrue((self.project / ".agents/skills/lean-spec-plan/SKILL.md").is_file())

    def test_installer_renders_codex_host_profile_and_interview_input(self) -> None:
        self.require_ok(self.install_codex())
        rules = (self.project / ".lean-spec/runtime/examples/rules.toml").read_text()
        installed_plan = (self.project / ".agents/skills/lean-spec-plan/SKILL.md").read_text()
        self.assertIn("[hosts.codex]", rules)
        self.assertEqual(tomllib.loads(rules)["agents"], {"plan": {"model": "session"}})
        self.assertIn('spec = { model = "gpt-5.6-sol", effort = "high" }', rules)
        self.assertIn("request_user_input", installed_plan)
        self.assertIn("Markdown fallback", installed_plan)

    def test_installed_runtime_runs_lifecycle_and_enforces_guard(self) -> None:
        self.require_ok(self.install_codex())
        runtime = self.project / ".lean-spec/runtime/bin/lean-spec"
        self.require_ok(self.process(str(runtime), "ensure", "codex-demo"))
        guard = self.process("bash", str(self.project / ".lean-spec/runtime/hooks/pre-tool-use-guard.sh"), input=json.dumps({"tool_name": "Write", "tool_input": {"file_path": ".lean-spec/features/codex-demo/workflow.json"}}))
        self.require_ok(guard)
        self.assertEqual(json.loads(guard.stdout)["hookSpecificOutput"]["permissionDecision"], "deny")
        self.write_spec("codex-demo")
        self.require_ok(self.process(str(runtime), "advance", "codex-demo", "specifying", "implementing"))
        self.write_notes("codex-demo")
        self.require_ok(self.process(str(runtime), "advance", "codex-demo", "implementing", "reviewing"))
        self.write_review("codex-demo")
        self.require_ok(self.process(str(runtime), "advance", "codex-demo", "reviewing", "closed"))

    def test_installed_stop_hook_routes_to_the_installed_codex_skill(self) -> None:
        self.require_ok(self.install_codex())
        runtime = self.project / ".lean-spec/runtime/bin/lean-spec"
        self.require_ok(self.process(str(runtime), "ensure", "demo"))
        self.write_spec()
        self.require_ok(self.process(str(runtime), "advance", "demo", "specifying", "implementing"))
        self.write_notes()
        self.require_ok(self.process(str(runtime), "advance", "demo", "implementing", "reviewing"))
        self.write_review()
        self.require_ok(self.process(str(runtime), "advance", "demo", "reviewing", "closed"))
        self.write_ready_project()
        self.require_ok(self.process(str(runtime), "auto", "arm", "demo", "--chain-all", "--no-confirm"))
        result = self.process("bash", str(self.project / ".lean-spec/runtime/hooks/stop-auto-driver.sh"), input="{}")
        self.require_ok(result)
        self.assertIn(".agents/skills/lean-spec-spec/SKILL.md", json.loads(result.stdout)["reason"])


class ProviderAndEndToEndTests(IntegrationCase):
    def provider_environment(self, *, auth_check: str = "") -> dict[str, str]:
        fake_bin = self.project / "fake-bin"
        fake_bin.mkdir(exist_ok=True)
        if not (fake_bin / "codex").exists():
            os.symlink(sys.executable, fake_bin / "codex")
        self.write(".lean-spec/rules.toml", '[agents]\nimplement = { provider = "codex", model = "gpt-5.6-terra", effort = "medium"' + auth_check + ' }\n')
        return {"PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}"}

    def test_provider_routing_uses_real_cli_and_auth_gate(self) -> None:
        env = self.provider_environment()
        result = self.cli("provider", "argv", "implement", "--prompt", "write notes", env=env)
        self.require_ok(result)
        self.assertEqual(json.loads(result.stdout)["argv"], ["codex", "exec", "--json", "--model", "gpt-5.6-terra", "-c", "model_reasoning_effort=medium", "write notes"])
        self.write(".lean-spec/rules.toml", '[agents]\nimplement = { provider = "unknown", model = "x" }\n')
        unknown = self.cli("provider", "argv", "implement", "--prompt", "write notes", env=env)
        self.assertEqual(unknown.returncode, 1)
        self.assertIn("unknown provider", unknown.stderr)
        env = self.provider_environment(auth_check=', auth_check = ["/usr/bin/false"]')
        blocked = self.cli("provider", "run", "implement", "--prompt", "write notes", env=env)
        self.assertEqual(blocked.returncode, 1)
        self.assertIn("authentication check failed", blocked.stderr)

    def test_end_to_end_lifecycle_uses_fixture_artifacts_and_cli(self) -> None:
        self.write_ready_project()
        self.require_ok(self.cli("validate", "--project", "PRD.md"))
        self.ensure("hello-cli")
        fixture = REPO_ROOT / "tests/fixtures/demo-project/features/hello-cli"
        for artifact in ("spec.md", "notes.md", "review.md"):
            self.write(f".lean-spec/features/hello-cli/{artifact}", (fixture / artifact).read_text())
        self.require_ok(self.cli("advance", "hello-cli", "specifying", "implementing"))
        self.require_ok(self.cli("advance", "hello-cli", "implementing", "reviewing"))
        self.assertEqual(json.loads(self.cli("next", "hello-cli", "--json").stdout)["step"], "close")
        self.require_ok(self.cli("advance", "hello-cli", "reviewing", "closed"))
        status = json.loads(self.cli("status", "hello-cli", "--json").stdout)
        self.assertEqual((status["phase"], status["history_len"]), ("closed", 3))

    def test_cli_and_hook_surface_is_executable(self) -> None:
        help_result = self.cli("--help")
        self.require_ok(help_result)
        self.assertIn("auto", help_result.stdout)
        self.require_ok(self.process(sys.executable, str(REPO_ROOT / "adapters/codex/render_skill_policies.py"), "--check"))
        for hook in HOOKS.glob("*.sh"):
            with self.subTest(hook=hook.name):
                self.assertTrue(os.access(hook, os.X_OK), f"{hook} must be executable")
                self.require_ok(self.process("bash", "-n", str(hook)))


if __name__ == "__main__":
    import unittest

    unittest.main()
