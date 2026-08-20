#!/usr/bin/env python3
"""Install lean-spec's Codex adapter into a target repository."""
from __future__ import annotations

import argparse
import json
import shutil
import stat
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MARKER_BEGIN = "<!-- lean-spec:begin -->"
MARKER_END = "<!-- lean-spec:end -->"
ROLE_MODELS = {
    "architect": ("gpt-5.6-sol", "high"),
    "coder": ("gpt-5.6-terra", "medium"),
    "reviewer": ("gpt-5.6-sol", "high"),
}
ROLE_OWNERS = {"architect": "spec", "coder": "implement", "reviewer": "review"}


def copy_tree(source: Path, destination: Path, dry_run: bool) -> None:
    if dry_run:
        print(f"copy {source} -> {destination}")
        return
    shutil.copytree(source, destination, dirs_exist_ok=True)


def copy_codex_skill(source: Path, destination: Path, dry_run: bool) -> None:
    """Copy one canonical skill and render its installed runtime path."""
    copy_tree(source, destination, dry_run)
    canonical = source / "SKILL.md"
    rendered = canonical.read_text(encoding="utf-8").replace(
        "bin/lean-spec", ".lean-spec/runtime/bin/lean-spec"
    )
    write_text(destination / "SKILL.md", rendered, dry_run)


def write_text(path: Path, text: str, dry_run: bool) -> None:
    if dry_run:
        print(f"write {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def merged_agents_md(path: Path) -> str:
    block = (ROOT / "adapters" / "codex" / "AGENTS.md.fragment").read_text(encoding="utf-8") + "\n"
    current = path.read_text(encoding="utf-8") if path.exists() else ""
    has_begin = MARKER_BEGIN in current
    has_end = MARKER_END in current
    if has_begin != has_end:
        raise ValueError(f"{path} has an incomplete lean-spec marker block")
    if has_begin:
        before, _, remainder = current.partition(MARKER_BEGIN)
        _, _, after = remainder.partition(MARKER_END)
        current = before.rstrip() + "\n\n" + block + after.lstrip()
    else:
        current = current.rstrip() + ("\n\n" if current.strip() else "") + block
    return current


def merge_agents_md(path: Path, dry_run: bool) -> None:
    write_text(path, merged_agents_md(path), dry_run)


def desired_hook_config() -> dict:
    config = json.loads((ROOT / "adapters" / "codex" / "hooks.json").read_text(encoding="utf-8"))
    if not isinstance(config, dict) or not isinstance(config.get("hooks"), dict):
        raise ValueError("bundled Codex hooks configuration is invalid")
    return config


def merge_hook_config(path: Path, desired: dict) -> dict:
    if not path.exists():
        return desired
    try:
        existing = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(f"{path} is not valid JSON: {error.msg}") from error
    if not isinstance(existing, dict) or not isinstance(existing.get("hooks"), dict):
        raise ValueError(f"{path} must contain an object at hooks")
    for event, entries in existing["hooks"].items():
        if not isinstance(event, str) or not isinstance(entries, list):
            raise ValueError(f"{path} has an unsupported hooks entry for {event!r}")

    merged = dict(existing)
    hooks = dict(existing["hooks"])
    for event, entries in desired["hooks"].items():
        current = list(hooks.get(event, []))
        for entry in entries:
            if entry not in current:
                current.append(entry)
        hooks[event] = current
    merged["hooks"] = hooks
    return merged


def codex_role_models(project: Path) -> dict[str, tuple[str, str]]:
    rules_path = project / ".lean-spec" / "rules.toml"
    models = dict(ROLE_MODELS)
    if not rules_path.exists():
        return models
    try:
        rules = tomllib.loads(rules_path.read_text(encoding="utf-8"))
    except tomllib.TOMLDecodeError as error:
        raise ValueError(f"{rules_path} is not valid TOML: {error}") from error
    hosts = rules.get("hosts", {})
    codex = hosts.get("codex", {}) if isinstance(hosts, dict) else None
    if codex is None:
        return models
    if not isinstance(codex, dict):
        raise ValueError(f"{rules_path} [hosts.codex] must be a table")
    for role, owner in ROLE_OWNERS.items():
        override = codex.get(owner)
        if override is None:
            continue
        if not isinstance(override, dict):
            raise ValueError(f"{rules_path} hosts.codex.{owner} must be a table")
        model, effort = override.get("model"), override.get("effort")
        if not isinstance(model, str) or not isinstance(effort, str):
            raise ValueError(f"{rules_path} hosts.codex.{owner} requires string model and effort")
        models[role] = (model, effort)
    return models


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    project = args.project.resolve()
    if not (project / ".git").exists():
        parser.error("--project must be a git repository")

    try:
        desired_hooks = desired_hook_config()
        merged_hooks = merge_hook_config(project / ".codex" / "hooks.json", desired_hooks)
        merged_agents_md(project / "AGENTS.md")
        role_models = codex_role_models(project)
    except ValueError as error:
        parser.error(str(error))

    runtime = project / ".lean-spec" / "runtime"
    copy_tree(ROOT / "bin", runtime / "bin", args.dry_run)
    copy_tree(ROOT / "adapters", runtime / "adapters", args.dry_run)
    copy_tree(ROOT / "hooks", runtime / "hooks", args.dry_run)
    copy_tree(ROOT / "templates", runtime / "templates", args.dry_run)
    copy_tree(ROOT / "examples", runtime / "examples", args.dry_run)
    for skill in (ROOT / "skills").iterdir():
        if skill.is_dir():
            copy_codex_skill(
                skill,
                project / ".agents" / "skills" / f"lean-spec-{skill.name}",
                args.dry_run,
            )

    for role in ("architect", "coder", "reviewer"):
        source = ROOT / "agents" / f"{role}.md"
        content = source.read_text()
        model, effort = role_models[role]
        write_text(
            project / ".codex" / "agents" / f"lean-spec-{role}.toml",
            f'name = "lean-spec-{role}"\ndescription = "Lean-spec {role} role"\n'
            f'model = "{model}"\nmodel_reasoning_effort = "{effort}"\n'
            f'developer_instructions = {json.dumps(content)}\n',
            args.dry_run,
        )
    write_text(project / ".codex" / "hooks.json", json.dumps(merged_hooks, indent=2) + "\n", args.dry_run)
    merge_agents_md(project / "AGENTS.md", args.dry_run)
    if not args.dry_run:
        for script in (runtime / "bin").iterdir():
            script.chmod(script.stat().st_mode | stat.S_IXUSR)
        for script in (runtime / "hooks").iterdir():
            script.chmod(script.stat().st_mode | stat.S_IXUSR)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
