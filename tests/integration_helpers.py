"""Small stdlib-only helpers for direct lean-spec process tests."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CLI = REPO_ROOT / "bin" / "lean-spec"
HOOKS = REPO_ROOT / "hooks"
INSTALLER = REPO_ROOT / "adapters" / "codex" / "install.py"


class IntegrationCase(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        self._temporary_directory = tempfile.TemporaryDirectory(prefix="lean-spec-integration-")
        self.project = Path(self._temporary_directory.name)
        self.process("git", "init", "-q")
        self.process("git", "config", "user.email", "test@example.com")
        self.process("git", "config", "user.name", "Test User")

    def tearDown(self) -> None:
        self._temporary_directory.cleanup()

    def process(
        self,
        *argv: str,
        input: str | None = None,
        cwd: Path | None = None,
        env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            argv,
            cwd=cwd or self.project,
            input=input,
            text=True,
            capture_output=True,
            check=False,
            env={**os.environ, **(env or {})},
        )

    def cli(self, *args: str, **kwargs: object) -> subprocess.CompletedProcess[str]:
        return self.process(str(CLI), *args, **kwargs)

    def hook(self, name: str, payload: object, **kwargs: object) -> subprocess.CompletedProcess[str]:
        content = payload if isinstance(payload, str) else json.dumps(payload)
        return self.process("bash", str(HOOKS / name), input=content, **kwargs)

    def install_codex(self, *args: str) -> subprocess.CompletedProcess[str]:
        return self.process(sys.executable, str(INSTALLER), "--project", str(self.project), *args)

    def write(self, relative_path: str, content: str) -> Path:
        path = self.project / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def read_json(self, relative_path: str) -> object:
        return json.loads((self.project / relative_path).read_text(encoding="utf-8"))

    def require_ok(self, result: subprocess.CompletedProcess[str]) -> None:
        self.assertEqual(
            result.returncode,
            0,
            f"argv={result.args!r}\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}",
        )

    def ensure(self, slug: str = "demo") -> None:
        self.require_ok(self.cli("ensure", slug))

    def write_spec(self, slug: str = "demo") -> None:
        self.write(
            f".lean-spec/features/{slug}/spec.md",
            "# Spec\n\n## Scope\nOne slice.\n\n## Acceptance Criteria\nIt works.\n\n"
            "## Out of Scope\nNone.\n\n## Coder Guardrails\nUse the CLI.\n",
        )

    def write_notes(self, slug: str = "demo", *, with_tdd: bool = True) -> None:
        content = "## What was built\nOne slice.\n\n## How to verify\nRun tests.\n"
        if with_tdd:
            content += "\n## TDD\nRed then green.\n"
        self.write(f".lean-spec/features/{slug}/notes.md", content)

    def write_review(self, slug: str = "demo", verdict: str = "APPROVE") -> None:
        self.write(
            f".lean-spec/features/{slug}/review.md",
            f"## Verdict\nverdict: {verdict}\n\n## Spec Compliance\nYes.\n\n## Code Quality\nGood.\n",
        )

    def advance_to_reviewing(self, slug: str = "demo") -> None:
        self.ensure(slug)
        self.write_spec(slug)
        self.require_ok(self.cli("advance", slug, "specifying", "implementing"))
        self.write_notes(slug)
        self.require_ok(self.cli("advance", slug, "implementing", "reviewing"))

    def write_ready_project(self) -> None:
        self.write(
            ".lean-spec/PRD.md",
            "## Problem & Users\nPeople need it.\n\n## Features\nOne safe slice.\n\n"
            "## Constraints\nUse Python.\n\n## Quality Bar\nRun the suite.\n\n"
            "## Existing System & Behaviour\nNo existing product behavior.\n\n"
            "## Compatibility & Migration\nNo migration is required.\n\n"
            "## Regression Checks\nRun unittest.\n\n## Non-Goals\nNone.\n",
        )
        self.write(
            ".lean-spec/CONSTITUTION.md",
            "## Stack\nPython.\n\n## Principles\nUse CLI gates.\n\n"
            "## Delegation\nOne owner.\n\n## Quality Bars\nTests pass.\n\n"
            "## Process\nUse Git.\n\n## Non-Goals\nNone.\n",
        )
