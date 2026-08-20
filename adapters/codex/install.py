#!/usr/bin/env python3
"""Install lean-spec's Codex adapter into a target repository."""
from __future__ import annotations

import argparse
import json
import shutil
import stat
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MARKER_BEGIN = "<!-- lean-spec:begin -->"
MARKER_END = "<!-- lean-spec:end -->"


def copy_tree(source: Path, destination: Path, dry_run: bool) -> None:
    if dry_run:
        print(f"copy {source} -> {destination}")
        return
    shutil.copytree(source, destination, dirs_exist_ok=True)


def write_text(path: Path, text: str, dry_run: bool) -> None:
    if dry_run:
        print(f"write {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def merge_agents_md(path: Path, dry_run: bool) -> None:
    block = "\n".join((
        MARKER_BEGIN,
        "# lean-spec",
        "Use `.lean-spec/runtime/bin/lean-spec` as the only writer of lean-spec state.",
        "Do not edit `.lean-spec/features/*/workflow.json` or `.lean-spec/auto.json` directly.",
        "Read the installed `.agents/skills/lean-spec-*/SKILL.md` instructions before running a lifecycle step.",
        MARKER_END,
        "",
    ))
    current = path.read_text() if path.exists() else ""
    if MARKER_BEGIN in current and MARKER_END in current:
        before, _, remainder = current.partition(MARKER_BEGIN)
        _, _, after = remainder.partition(MARKER_END)
        current = before.rstrip() + "\n\n" + block + after.lstrip()
    else:
        current = current.rstrip() + ("\n\n" if current.strip() else "") + block
    write_text(path, current, dry_run)


def hook_config() -> dict:
    runtime = ".lean-spec/runtime"
    return {
        "hooks": {
            "PreToolUse": [{
                "matcher": "^(apply_patch|Bash)$",
                "hooks": [{"type": "command", "command": f"{runtime}/hooks/pre-tool-use-guard.sh"}],
            }],
            "SubagentStop": [{
                "hooks": [{"type": "command", "command": f"{runtime}/hooks/subagent-stop-gate.sh"}],
            }],
            "Stop": [{
                "hooks": [{"type": "command", "command": f"{runtime}/hooks/stop-auto-driver.sh"}],
            }],
        }
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    project = args.project.resolve()
    if not (project / ".git").exists():
        parser.error("--project must be a git repository")

    runtime = project / ".lean-spec" / "runtime"
    copy_tree(ROOT / "bin", runtime / "bin", args.dry_run)
    copy_tree(ROOT / "hooks", runtime / "hooks", args.dry_run)
    copy_tree(ROOT / "templates", runtime / "templates", args.dry_run)
    copy_tree(ROOT / "examples", runtime / "examples", args.dry_run)
    for skill in (ROOT / "skills").iterdir():
        if skill.is_dir():
            copy_tree(skill, project / ".agents" / "skills" / f"lean-spec-{skill.name}", args.dry_run)

    for role in ("architect", "coder", "reviewer"):
        source = ROOT / "agents" / f"{role}.md"
        content = source.read_text()
        write_text(
            project / ".codex" / "agents" / f"lean-spec-{role}.toml",
            f'name = "lean-spec-{role}"\ndescription = "Lean-spec {role} role"\ndeveloper_instructions = {json.dumps(content)}\n',
            args.dry_run,
        )
    write_text(project / ".codex" / "hooks.json", json.dumps(hook_config(), indent=2) + "\n", args.dry_run)
    merge_agents_md(project / "AGENTS.md", args.dry_run)
    if not args.dry_run:
        for script in (runtime / "bin").iterdir():
            script.chmod(script.stat().st_mode | stat.S_IXUSR)
        for script in (runtime / "hooks").iterdir():
            script.chmod(script.stat().st_mode | stat.S_IXUSR)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
