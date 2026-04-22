#!/usr/bin/env bash
set -euo pipefail

DATE=$(date +%Y-%m-%d)
NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -n "$NAME" ]]; then
  echo "Hello, $NAME! Today is $DATE."
else
  echo "Hello from lean-spec! Today is $DATE."
fi
