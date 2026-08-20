#!/usr/bin/env python3
"""Plugin entry point for installing the Codex project adapter."""
from __future__ import annotations

import runpy
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[6]


if __name__ == "__main__":
    installer = ROOT / "adapters" / "codex" / "install.py"
    if not installer.is_file():
        raise SystemExit("lean-spec bootstrap: adapter installer not found in this plugin")
    sys.argv[0] = str(installer)
    runpy.run_path(str(installer), run_name="__main__")
