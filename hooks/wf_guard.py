#!/usr/bin/env python3
"""Workflow.json write guard — blocks direct edits to features/*/workflow.json.

Handles both Claude PreToolUse and Gemini BeforeTool JSON shapes.
Fails open (exit 0) on any parse error or unknown format.
"""
import json
import os
import re
import sys


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    # --- Claude PreToolUse format ---
    # {"tool_name": "Write", "cwd": "/path", "tool_input": {"file_path": "..."}}
    cwd = data.get("cwd", os.getcwd())
    file_path = (data.get("tool_input") or {}).get("file_path", "")

    # --- Gemini BeforeTool format ---
    # {"toolName": "write_file", "args": {"filename": "..."}} (no cwd field)
    if not file_path:
        args = data.get("args") or data.get("parameters") or {}
        file_path = (
            args.get("filename")
            or args.get("path")
            or args.get("file_path")
            or ""
        )

    if not file_path:
        sys.exit(0)

    if not os.path.isabs(file_path):
        file_path = os.path.join(cwd, file_path)

    if re.search(r"/features/[^/]+/workflow\.json$", file_path):
        print(
            json.dumps(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "deny",
                        "permissionDecisionReason": (
                            "Direct edits to workflow.json are blocked. "
                            "Use /lean-spec:* commands to advance the lifecycle. "
                            "If the state is wedged, edit the file manually via "
                            "your terminal (not through Claude)."
                        ),
                    }
                }
            )
        )


if __name__ == "__main__":
    main()
