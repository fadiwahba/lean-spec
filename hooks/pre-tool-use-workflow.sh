#!/usr/bin/env bash
set -uo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/wf_guard.py"
