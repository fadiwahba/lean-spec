"""Static repository contracts for lean-spec's Python test suite."""
from __future__ import annotations

import json
import os
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILLS = ("init", "plan", "spec", "respec", "implement", "review", "fix", "close", "auto", "auto-all", "next", "status", "help")
MUTATING_SKILLS = ("init", "plan", "spec", "respec", "implement", "review", "fix", "close", "auto", "auto-all")
AGENTS = ("architect", "coder", "reviewer")


class RepositorySurfaceTests(unittest.TestCase):
    def test_manifests_declare_existing_surface_and_hooks(self) -> None:
        claude = json.loads((ROOT / ".claude-plugin/plugin.json").read_text())
        codex = json.loads((ROOT / ".codex-plugin/plugin.json").read_text())
        self.assertEqual(claude["name"], "lean-spec")
        self.assertTrue(claude["version"])
        self.assertEqual({path.rsplit("/", 1)[-1] for path in claude["skills"]}, set(SKILLS))
        self.assertEqual({path.rsplit("/", 1)[-1].removesuffix(".md") for path in claude["agents"]}, set(AGENTS))
        self.assertEqual(set(claude["hooks"]), {"PreToolUse", "SubagentStop", "Stop"})
        self.assertEqual(codex["skills"], "./adapters/codex/plugin/skills/")
        self.assertNotIn("hooks", codex)
        self.assertTrue((ROOT / "adapters/codex/plugin/skills/lean-spec-bootstrap/SKILL.md").is_file())
        self.assertFalse((ROOT / "skills/bootstrap").exists())

    def test_canonical_skills_agents_templates_and_policies_are_consistent(self) -> None:
        rules = tomllib.loads((ROOT / "examples/rules.toml").read_text())
        self.assertEqual(rules["agents"], {"plan": {"model": "session"}})
        plan = (ROOT / "skills" / "plan" / "SKILL.md").read_text()
        self.assertIn("grouped, targeted questions", plan)
        self.assertIn("NEEDS_INPUT", plan)
        for skill in SKILLS:
            with self.subTest(skill=skill):
                content = (ROOT / "skills" / skill / "SKILL.md").read_text()
                self.assertIn(f"name: {skill}", content)
                self.assertRegex(content, r"description:\s*.+")
                self.assertNotRegex(content, r"/lean-spec:|AskUserQuestion|Task tool|Claude Code|Codex|bin/lean-spec dispatch|^disable-model-invocation:")
                self.assertNotIn("```bash", content)
                self.assertNotIn("```sh", content)
        for skill in MUTATING_SKILLS:
            self.assertIn("allow_implicit_invocation: false", (ROOT / "skills" / skill / "agents/openai.yaml").read_text())
        for skill in ("next", "status", "help"):
            self.assertFalse((ROOT / "skills" / skill / "agents/openai.yaml").exists())
        for agent in AGENTS:
            content = (ROOT / "agents" / f"{agent}.md").read_text()
            self.assertRegex(content, r"(?m)^model:\s*.+")
            self.assertRegex(content, r"(?m)^effort:\s*.+")
            self.assertIn("## Never does", content)
        for artifact, headings in rules["required_sections"].items():
            template = (ROOT / "templates" / artifact).read_text()
            for heading in headings:
                self.assertIn(f"## {heading}", template)

    def test_ci_gitignore_and_runtime_files_match_declared_contract(self) -> None:
        ci = (ROOT / ".github/workflows/ci.yml").read_text()
        self.assertIn("setup-python", ci)
        self.assertIn("3.11", ci)
        self.assertIn("unittest discover", ci)
        for path in (ROOT / ".gitignore", ROOT / "examples/gitignore"):
            content = path.read_text().splitlines()
            for required in (".lean-spec/features/*/evidence/", ".lean-spec/features/*/.workflow*", ".lean-spec/.auto*"):
                self.assertIn(required, content)
        for template in ("PRD.md", "CONSTITUTION.md", "spec.md", "notes.md", "review.md"):
            self.assertTrue((ROOT / "templates" / template).is_file())
        self.assertTrue(os.access(ROOT / "bin/lean-spec", os.X_OK))


if __name__ == "__main__":
    unittest.main()
