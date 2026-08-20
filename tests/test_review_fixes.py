"""Regression tests for findings from the independent Codex adapter audit."""
from __future__ import annotations

import json
import importlib.util
from importlib.machinery import SourceFileLoader
import contextlib
import io
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "lean-spec"
HOOKS = ROOT / "hooks"
INSTALLER = ROOT / "adapters" / "codex" / "install.py"


class RepoCase(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="lean-spec-review-")
        self.root = Path(self.temp.name)
        self.cmd("git", "init", "-q")
        self.cmd("git", "config", "user.email", "test@example.com")
        self.cmd("git", "config", "user.name", "Test User")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def cmd(self, *args: str, input: str | None = None, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            args,
            cwd=cwd or self.root,
            input=input,
            text=True,
            capture_output=True,
            check=False,
        )

    def lean(self, *args: str) -> subprocess.CompletedProcess[str]:
        return self.cmd(str(CLI), *args)

    def write(self, relative: str, text: str) -> Path:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def ensure(self, slug: str = "demo") -> None:
        result = self.lean("ensure", slug)
        self.assertEqual(result.returncode, 0, result.stderr)

    def advance_to_closed(self, slug: str = "demo") -> None:
        self.ensure(slug)
        self.write(f".lean-spec/features/{slug}/spec.md", "# Spec\n")
        self.assertEqual(self.lean("advance", slug, "specifying", "implementing").returncode, 0)
        self.write(f".lean-spec/features/{slug}/notes.md", "## What was built\nDone\n## TDD\nRED then GREEN\n")
        self.assertEqual(self.lean("advance", slug, "implementing", "reviewing").returncode, 0)
        self.write(f".lean-spec/features/{slug}/review.md", "verdict: APPROVE\n")
        self.assertEqual(self.lean("advance", slug, "reviewing", "closed").returncode, 0)


class AutoDriverTests(RepoCase):
    def test_auto_result_write_verifies_the_persisted_state(self) -> None:
        loader = SourceFileLoader("lean_spec_cli", str(CLI))
        spec = importlib.util.spec_from_loader("lean_spec_cli", loader)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        state = {"run_id": "run", "event_history": []}
        result = {"outcome": "READY", "run_id": "run"}
        module.atomic_write_json = lambda *_args, **_kwargs: None
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as raised:
                module._write_auto_result(str(self.root), state, "event", result)
        self.assertEqual(raised.exception.code, 1)

    def test_arm_tracks_phase_expected_after_first_dispatched_step(self) -> None:
        self.ensure()
        result = self.lean("auto", "arm", "demo")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = json.loads((self.root / ".lean-spec/auto.json").read_text())
        self.assertEqual(state["expected_phase"], "implementing")

    def test_completed_run_is_not_armed_and_cannot_restart_for_new_work(self) -> None:
        self.advance_to_closed()
        self.assertEqual(self.lean("auto", "arm", "demo").returncode, 0)
        state = json.loads((self.root / ".lean-spec/auto.json").read_text())
        finished = self.lean("auto", "tick", "--run-id", state["run_id"], "--event-id", "closed", "--json")
        self.assertEqual(finished.returncode, 0, finished.stderr)
        self.assertEqual(json.loads(finished.stdout)["outcome"], "COMPLETE")
        status = self.lean("auto", "status", "--json")
        self.assertFalse(json.loads(status.stdout)["armed"])
        self.ensure("later")
        replay = self.lean("auto", "tick", "--run-id", state["run_id"], "--event-id", "later", "--json")
        self.assertEqual(replay.returncode, 2)

    def test_no_remaining_scope_can_complete_an_auto_all_run(self) -> None:
        self.advance_to_closed()
        self.write(
            ".lean-spec/PRD.md",
            "## Existing System & Behaviour\nNone\n## Compatibility & Migration\nNone\n## Regression Checks\npython3 -m unittest\n",
        )
        self.assertEqual(self.lean("auto", "arm", "demo", "--chain-all", "--no-confirm").returncode, 0)
        state = json.loads((self.root / ".lean-spec/auto.json").read_text())
        tick = self.lean("auto", "tick", "--run-id", state["run_id"], "--event-id", "ask-architect", "--json")
        self.assertEqual(tick.returncode, 0, tick.stderr)
        self.assertEqual(json.loads(tick.stdout)["next_step"], "spec")
        complete = self.lean("auto", "complete", "--run-id", state["run_id"], "--no-remaining-scope", "--json")
        self.assertEqual(complete.returncode, 0, complete.stderr)
        self.assertEqual(json.loads(complete.stdout)["outcome"], "COMPLETE")
        self.assertFalse(json.loads(self.lean("auto", "status", "--json").stdout)["armed"])

    def test_next_json_carries_dispatch_identity(self) -> None:
        self.ensure()
        result = self.lean("next", "demo", "--json")
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        for field in ("schema_version", "outcome", "owner", "artifact", "gate", "expected_phase"):
            self.assertIn(field, data)
        self.assertEqual(data["owner"], "coder")
        self.assertEqual(data["artifact"], "notes.md")
        self.assertEqual(data["expected_phase"], "implementing")

    def test_retained_event_replay_does_not_mutate_a_later_phase(self) -> None:
        self.ensure()
        self.assertEqual(self.lean("auto", "arm", "demo").returncode, 0)
        state = json.loads((self.root / ".lean-spec/auto.json").read_text())
        self.write(".lean-spec/features/demo/spec.md", "# Spec\n")
        self.assertEqual(self.lean("advance", "demo", "specifying", "implementing").returncode, 0)
        first = self.lean("auto", "tick", "--run-id", state["run_id"], "--event-id", "one", "--json")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.write(".lean-spec/features/demo/notes.md", "## What was built\nDone\n## TDD\nRED then GREEN\n")
        self.assertEqual(self.lean("advance", "demo", "implementing", "reviewing").returncode, 0)
        second = self.lean("auto", "tick", "--run-id", state["run_id"], "--event-id", "two", "--json")
        self.assertEqual(second.returncode, 0, second.stderr)
        replay = self.lean("auto", "tick", "--run-id", state["run_id"], "--event-id", "one", "--json")
        self.assertEqual(replay.returncode, 0, replay.stderr)
        self.assertEqual(json.loads(replay.stdout), json.loads(first.stdout))


class ValidationAndHookTests(RepoCase):
    def test_subagent_stop_uses_cli_bound_agent_identity(self) -> None:
        self.ensure()
        self.write(".lean-spec/features/demo/spec.md", "# Spec\n")
        self.assertEqual(self.lean("advance", "demo", "specifying", "implementing").returncode, 0)
        prepared = self.lean("dispatch", "prepare", "demo", "coder")
        self.assertEqual(prepared.returncode, 0, prepared.stderr)
        bound = self.lean("dispatch", "bind", "agent-1", "lean-spec-coder")
        self.assertEqual(bound.returncode, 0, bound.stderr)
        payload = json.dumps({"agent_id": "agent-1", "agent_type": "lean-spec-coder", "stop_hook_active": False})
        blocked = self.cmd("bash", str(HOOKS / "subagent-stop-gate.sh"), input=payload)
        self.assertEqual(blocked.returncode, 0, blocked.stderr)
        self.assertIn('"decision": "block"', blocked.stdout)
        self.write(".lean-spec/features/demo/notes.md", "## What was built\nDone\n## TDD\nRED then GREEN\n")
        allowed = self.cmd("bash", str(HOOKS / "subagent-stop-gate.sh"), input=payload)
        self.assertEqual(allowed.returncode, 0, allowed.stderr)
        self.assertEqual(allowed.stdout, "")

    def test_dispatch_cancel_recovers_from_a_failed_agent_launch(self) -> None:
        self.ensure()
        prepared = self.lean("dispatch", "prepare", "demo", "architect")
        self.assertEqual(prepared.returncode, 0, prepared.stderr)
        self.assertEqual(self.lean("dispatch", "prepare", "demo", "architect").returncode, 2)
        cancelled = self.lean("dispatch", "cancel")
        self.assertEqual(cancelled.returncode, 0, cancelled.stderr)
        self.assertEqual(self.lean("dispatch", "prepare", "demo", "architect").returncode, 0)

    def test_required_feature_section_must_have_a_body(self) -> None:
        self.ensure()
        rules = (ROOT / "examples" / "rules.toml").read_text(encoding="utf-8")
        rules = rules.replace('"spec.md"   = ["Scope", "Acceptance Criteria", "Out of Scope", "Coder Guardrails"]', '"spec.md" = ["Acceptance Criteria"]')
        self.write(".lean-spec/rules.toml", rules)
        self.write(".lean-spec/features/demo/spec.md", "## Acceptance Criteria\n")
        result = self.lean("validate", "demo", "spec.md")
        self.assertEqual(result.returncode, 2)
        self.assertIn("unfilled", result.stderr)

    def test_codex_bash_command_targeting_state_is_denied(self) -> None:
        payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": "printf x > .lean-spec/auto.json"}})
        result = self.cmd("bash", str(HOOKS / "pre-tool-use-guard.sh"), input=payload)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"permissionDecision": "deny"', result.stdout)

    def test_codex_apply_patch_command_targeting_state_is_denied(self) -> None:
        payload = json.dumps({"tool_name": "apply_patch", "tool_input": {"command": "*** Begin Patch\n*** Update File: .lean-spec/auto.json\n*** End Patch"}})
        result = self.cmd("bash", str(HOOKS / "pre-tool-use-guard.sh"), input=payload)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"permissionDecision": "deny"', result.stdout)

    def test_codex_apply_patch_command_targeting_dispatch_state_is_denied(self) -> None:
        payload = json.dumps({"tool_name": "apply_patch", "tool_input": {"command": "*** Begin Patch\n*** Update File: .lean-spec/dispatch.json\n*** End Patch"}})
        result = self.cmd("bash", str(HOOKS / "pre-tool-use-guard.sh"), input=payload)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"permissionDecision": "deny"', result.stdout)

    def test_installed_hook_command_works_from_nested_directory(self) -> None:
        installed = self.cmd("python3", str(INSTALLER), "--project", str(self.root))
        self.assertEqual(installed.returncode, 0, installed.stderr)
        config = json.loads((self.root / ".codex/hooks.json").read_text())
        command = config["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
        nested = self.root / "src" / "nested"
        nested.mkdir(parents=True)
        payload = json.dumps({"tool_name": "apply_patch", "tool_input": {"command": "*** Begin Patch\n*** Update File: .lean-spec/auto.json\n*** End Patch"}})
        result = subprocess.run(command, shell=True, cwd=nested, input=payload, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"permissionDecision": "deny"', result.stdout)

    def test_codex_plugin_leaves_hooks_to_the_project_installer(self) -> None:
        manifest = json.loads((ROOT / ".codex-plugin/plugin.json").read_text())
        self.assertNotIn("hooks", manifest)

    def test_plugin_bootstrap_installs_the_project_adapter(self) -> None:
        bootstrap = ROOT / "adapters" / "codex" / "plugin" / "skills" / "lean-spec-bootstrap" / "scripts" / "codex_bootstrap.py"
        result = self.cmd("python3", str(bootstrap), "--project", str(self.root))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / ".codex/agents/lean-spec-coder.toml").is_file())
        self.assertTrue((self.root / ".agents/skills/lean-spec-init/SKILL.md").is_file())
        self.assertTrue((self.root / ".codex/hooks.json").is_file())

    def test_installer_replaces_legacy_lean_spec_hook_commands(self) -> None:
        self.write(
            ".codex/hooks.json",
            json.dumps({"hooks": {"PreToolUse": [{"matcher": "^(apply_patch|Bash)$", "hooks": [{"type": "command", "command": ".lean-spec/runtime/hooks/pre-tool-use-guard.sh"}]}], "SubagentStop": [{"hooks": [{"type": "command", "command": ".lean-spec/runtime/hooks/subagent-stop-gate.sh"}]}], "Stop": [{"hooks": [{"type": "command", "command": ".lean-spec/runtime/hooks/stop-auto-driver.sh"}]}]}}),
        )
        installed = self.cmd("python3", str(INSTALLER), "--project", str(self.root))
        self.assertEqual(installed.returncode, 0, installed.stderr)
        hooks = json.loads((self.root / ".codex/hooks.json").read_text())["hooks"]
        self.assertEqual(len(hooks["PreToolUse"]), 1)
        self.assertEqual(len(hooks["SubagentStop"]), 1)
        self.assertEqual(len(hooks["Stop"]), 1)

    def test_rules_example_documents_real_provider_model_examples(self) -> None:
        rules = (ROOT / "examples" / "rules.toml").read_text()
        self.assertIn('provider = "codex", model = "gpt-5.4"', rules)
        self.assertIn('provider = "claude", model = "opus"', rules)
        self.assertIn('provider = "gemini", model = "gemini-3.7-flash"', rules)


if __name__ == "__main__":
    unittest.main()
