#!/usr/bin/env python3
"""Validate headless agent-provider settings and build safe argv lists."""
from __future__ import annotations

import shutil


SUPPORTED = {"claude", "codex", "gemini"}
CODEX_EFFORTS = {"none", "low", "medium", "high", "xhigh", "max"}


def build_argv(provider: str, model: str, effort: str | None, prompt: str) -> list[str]:
    if provider not in SUPPORTED:
        raise ValueError(f"unknown provider {provider!r}; expected claude, codex, or gemini")
    if not isinstance(model, str) or not model:
        raise ValueError(f"provider {provider!r} requires a non-empty model")
    if provider == "codex":
        if effort not in CODEX_EFFORTS:
            allowed = ", ".join(sorted(CODEX_EFFORTS))
            raise ValueError(f"Codex effort must be one of {allowed}")
        return ["codex", "exec", "--json", "--model", model,
                "-c", f"model_reasoning_effort={effort}", prompt]
    if effort is not None:
        raise ValueError(f"provider {provider!r} has no documented headless effort flag")
    if provider == "claude":
        return ["claude", "-p", "--output-format", "json", "--model", model, prompt]
    return ["gemini", "--output-format", "json", "--model", model, "--prompt", prompt]


def require_executable(argv: list[str]) -> None:
    if shutil.which(argv[0]) is None:
        raise ValueError(f"provider executable {argv[0]!r} is not on PATH")
