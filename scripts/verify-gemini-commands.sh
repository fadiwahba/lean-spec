#!/usr/bin/env bash
#
# verify-gemini-commands.sh — drift check for the Gemini CLI extension.
#
# Asserts:
#   1. Every commands/*.md (Claude) has a matching commands/lean-spec/*.toml (Gemini).
#   2. Every TOML file parses (via python3 tomllib).
#   3. Every TOML has non-empty `description` and `prompt` fields.
#
# Exits non-zero on any drift. Called from tests/gemini-commands.bats and can
# also be run directly during development.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$PLUGIN_ROOT/commands"
GEMINI_DIR="$PLUGIN_ROOT/commands/lean-spec"

FAIL=0

# 1:1 correspondence
for md in "$CLAUDE_DIR"/*.md; do
  name=$(basename "$md" .md)
  toml="$GEMINI_DIR/$name.toml"
  if [ ! -f "$toml" ]; then
    echo "DRIFT: commands/$name.md has no matching commands/lean-spec/$name.toml"
    FAIL=1
  fi
done

for toml in "$GEMINI_DIR"/*.toml; do
  name=$(basename "$toml" .toml)
  md="$CLAUDE_DIR/$name.md"
  if [ ! -f "$md" ]; then
    echo "DRIFT: commands/lean-spec/$name.toml has no matching commands/$name.md"
    FAIL=1
  fi
done

# TOML parse + required fields
for toml in "$GEMINI_DIR"/*.toml; do
  name=$(basename "$toml")
  out=$(python3 -c "
import tomllib, sys
try:
    with open('$toml','rb') as f: d = tomllib.load(f)
except Exception as e:
    sys.stderr.write(f'PARSE ERROR in $name: {e}\n'); sys.exit(2)
if not d.get('description','').strip():
    sys.stderr.write(f'MISSING description in $name\n'); sys.exit(3)
if not d.get('prompt','').strip():
    sys.stderr.write(f'MISSING prompt in $name\n'); sys.exit(4)
" 2>&1) || { echo "$out"; FAIL=1; }
done

if [ "$FAIL" -eq 0 ]; then
  echo "Gemini commands: all $(ls "$GEMINI_DIR"/*.toml | wc -l | tr -d ' ') TOMLs in sync with Claude MDs and well-formed."
fi
exit $FAIL
