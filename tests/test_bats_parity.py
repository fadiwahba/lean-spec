"""Parity checks for behavior that was covered by the retired BATS suite."""
from __future__ import annotations

import json
import stat

from tests.integration_helpers import IntegrationCase


class LegacyCliParityTests(IntegrationCase):
    def test_usage_and_missing_feature_errors_are_explicit(self) -> None:
        cases = [
            ((), 1),
            (("unknown-command",), 1),
            (("ensure",), 1),
            (("advance", "demo", "specifying"), 1),
            (("assert", "demo"), 1),
            (("validate", "demo"), 1),
            (("next",), 1),
            (("status", "demo", "extra"), 1),
            (("auto",), 1),
            (("auto", "unknown"), 1),
        ]
        for args, code in cases:
            with self.subTest(args=args):
                result = self.cli(*args)
                self.assertEqual(result.returncode, code)
                self.assertNotIn("Traceback", result.stderr)
        for args in (("advance", "missing", "specifying", "implementing"), ("assert", "missing", "specifying")):
            with self.subTest(args=args):
                self.assertEqual(self.cli(*args).returncode, 1)

    def test_transition_and_verdict_matrix_preserves_state_on_rejection(self) -> None:
        self.ensure()
        before = (self.project / ".lean-spec/features/demo/workflow.json").read_text()
        for transition, code in ((("specifying", "reviewing"), 2), (("specifying", "closed"), 2), (("specifying", "unknown"), 1)):
            with self.subTest(transition=transition):
                self.assertEqual(self.cli("advance", "demo", *transition).returncode, code)
                self.assertEqual((self.project / ".lean-spec/features/demo/workflow.json").read_text(), before)
        self.write_spec()
        self.require_ok(self.cli("advance", "demo", "specifying", "implementing"))
        self.write_notes()
        self.require_ok(self.cli("advance", "demo", "implementing", "reviewing"))
        for verdict in ("NEEDS_FIXES", "BLOCKED", "APPROVED", ""):
            with self.subTest(verdict=verdict):
                self.write_review(verdict=verdict or "APPROVED")
                self.assertEqual(self.cli("advance", "demo", "reviewing", "closed").returncode, 2)
        self.write_review(verdict="APPROVE with evidence")
        self.require_ok(self.cli("advance", "demo", "reviewing", "closed"))
        self.assertEqual(self.cli("advance", "demo", "closed", "reviewing").returncode, 2)

    def test_advance_preserves_existing_workflow_mode(self) -> None:
        self.ensure()
        workflow = self.project / ".lean-spec/features/demo/workflow.json"
        workflow.chmod(0o640)
        self.write_spec()
        self.require_ok(self.cli("advance", "demo", "specifying", "implementing"))
        self.assertEqual(stat.S_IMODE(workflow.stat().st_mode), 0o640)

    def test_validation_and_rules_invalid_shapes_fail_loudly(self) -> None:
        self.ensure()
        self.write_spec()
        invalid_rules = (
            'required_sections = "bad"\n',
            'defaults = "bad"\n',
            'max_tokens = []\n',
            '[defaults]\ntdd = "yes"\n',
            '[defaults]\nrequired_verdict = "MAYBE"\n',
            '[max_tokens]\n"spec.md" = "many"\n',
        )
        for rules in invalid_rules:
            with self.subTest(rules=rules):
                self.write(".lean-spec/rules.toml", rules)
                result = self.cli("validate", "demo", "spec.md")
                self.assertEqual(result.returncode, 1)
                self.assertIn("rules.toml", result.stderr)
                self.assertNotIn("Traceback", result.stderr)
        self.write(".lean-spec/rules.toml", '[max_tokens]\n"spec.md" = 1\n')
        self.assertEqual(self.cli("validate", "demo", "spec.md").returncode, 2)

    def test_auto_argument_shape_corruption_and_rearm_contract(self) -> None:
        self.ensure()
        failures = (
            ("auto", "arm", "demo", "--unknown"),
            ("auto", "arm", "demo", "--max-cycles=zero"),
            ("auto", "arm", "demo", "--max-cycles=0"),
            ("auto", "tick", "--run-id", "x"),
            ("auto", "complete", "--run-id", "x"),
        )
        for args in failures:
            with self.subTest(args=args):
                self.assertEqual(self.cli(*args).returncode, 1)
        self.require_ok(self.cli("auto", "arm", "demo", "--chain-all"))
        state = self.read_json(".lean-spec/auto.json")
        self.assertNotIn("no_confirm", state)
        self.require_ok(self.cli("auto", "arm", "demo", "--max-cycles=2"))
        self.assertEqual(self.read_json(".lean-spec/auto.json")["cycles"], 0)
        self.write(".lean-spec/auto.json", "[]")
        corrupt = self.cli("auto", "status", "--json")
        self.assertEqual(corrupt.returncode, 1)
        self.assertIn("corrupt", corrupt.stderr)
        self.require_ok(self.cli("auto", "disarm"))
        self.require_ok(self.cli("auto", "disarm"))

    def test_guard_covers_legacy_file_tools_and_codex_patch_shape(self) -> None:
        denied = [
            {"tool_name": tool, "tool_input": {"file_path": path}}
            for tool in ("Write", "Edit", "MultiEdit", "NotebookEdit")
            for path in ("./.lean-spec/auto.json", ".lean-spec/features/demo/workflow.json")
        ]
        denied.extend([
            {"tool_name": "apply_patch", "tool_input": {"command": "*** Begin Patch\n*** Update File: /repo/.lean-spec/features/demo/../demo/Workflow.json\n*** End Patch"}},
            {"tool_name": "Bash", "tool_input": {"command": "echo x > .lean-spec/auto.json"}},
        ])
        for payload in denied:
            with self.subTest(payload=payload):
                result = self.hook("pre-tool-use-guard.sh", payload)
                self.require_ok(result)
                self.assertEqual(json.loads(result.stdout)["hookSpecificOutput"]["permissionDecision"], "deny")
        for payload in (
            {"tool_name": "Read", "tool_input": {"file_path": ".lean-spec/auto.json"}},
            {"tool_name": "Write", "tool_input": {"file_path": ".lean-spec/rules.toml"}},
            {"tool_name": "apply_patch", "tool_input": {"command": "*** Begin Patch\n*** Update File: README.md\n*** End Patch"}},
        ):
            with self.subTest(payload=payload):
                result = self.hook("pre-tool-use-guard.sh", payload)
                self.require_ok(result)
                self.assertEqual(result.stdout, "")

    def test_claude_subagent_stop_fallback_still_validates_the_named_feature(self) -> None:
        self.ensure()
        payload = {"lean_spec": {"slug": "demo"}, "stop_hook_active": False}
        blocked = self.hook("subagent-stop-gate.sh", payload)
        self.require_ok(blocked)
        self.assertEqual(json.loads(blocked.stdout)["decision"], "block")
        self.write_spec()
        allowed = self.hook("subagent-stop-gate.sh", payload)
        self.require_ok(allowed)
        self.assertEqual(allowed.stdout, "")
        repeated = self.hook("subagent-stop-gate.sh", {**payload, "stop_hook_active": True})
        self.require_ok(repeated)
        self.assertEqual(repeated.stdout, "")

    def test_stop_driver_handles_disarmed_cap_closed_and_chain_states(self) -> None:
        self.assertEqual(self.hook("stop-auto-driver.sh", {}).stdout, "")
        self.ensure()
        self.require_ok(self.cli("auto", "arm", "demo", "--max-cycles=1"))
        self.write_spec()
        self.require_ok(self.cli("advance", "demo", "specifying", "implementing"))
        state = self.read_json(".lean-spec/auto.json")
        state["cycles"] = 1
        self.write(".lean-spec/auto.json", json.dumps(state))
        capped = self.hook("stop-auto-driver.sh", {})
        self.require_ok(capped)
        self.assertEqual(capped.stdout, "")
        self.assertEqual(self.read_json(".lean-spec/auto.json")["status"], "blocked")
        self.require_ok(self.cli("auto", "disarm"))
        self.write_notes()
        self.require_ok(self.cli("advance", "demo", "implementing", "reviewing"))
        self.write_review()
        self.require_ok(self.cli("advance", "demo", "reviewing", "closed"))
        self.require_ok(self.cli("auto", "arm", "demo"))
        closed = self.hook("stop-auto-driver.sh", {})
        self.require_ok(closed)
        self.assertEqual(closed.stdout, "")
        self.assertEqual(self.read_json(".lean-spec/auto.json")["status"], "complete")
        self.ensure("next")
        self.require_ok(self.cli("auto", "arm", "demo", "--chain-all"))
        chained = self.hook("stop-auto-driver.sh", {})
        self.require_ok(chained)
        self.assertEqual(json.loads(chained.stdout)["decision"], "block")
        self.assertIn("'next'", json.loads(chained.stdout)["reason"])

    def test_installer_rejects_bad_hooks_and_applies_explicit_role_models(self) -> None:
        self.write(".codex/hooks.json", '{"hooks": "bad"}\n')
        rejected = self.install_codex()
        self.assertEqual(rejected.returncode, 2)
        self.assertFalse((self.project / ".lean-spec/runtime").exists())
        self.write(".codex/hooks.json", '{"hooks": {}}\n')
        self.write(".lean-spec/rules.toml", '[hosts.codex]\nimplement = { model = "gpt-5.4", effort = "high" }\n')
        self.require_ok(self.install_codex())
        coder = (self.project / ".codex/agents/lean-spec-coder.toml").read_text()
        self.assertIn('model = "gpt-5.4"', coder)
        self.assertIn('model_reasoning_effort = "high"', coder)
