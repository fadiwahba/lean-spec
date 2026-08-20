#!/usr/bin/env python3
"""Render Codex-only invocation policies beside canonical skills."""
from __future__ import annotations

import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MUTATING_SKILLS = (
    "init", "plan", "spec", "respec", "implement", "review", "fix",
    "close", "auto", "auto-all",
)
POLICY = "policy:\n  allow_implicit_invocation: false\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    drift = []
    for name in MUTATING_SKILLS:
        path = ROOT / "skills" / name / "agents" / "openai.yaml"
        if path.exists() and path.read_text(encoding="utf-8") == POLICY:
            continue
        drift.append(path)
        if not args.check:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(POLICY, encoding="utf-8")
    if drift and args.check:
        for path in drift:
            print(f"Codex skill policy drift: {path.relative_to(ROOT)}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
