---
description: Drive a feature from its current phase to closed with optional human gate before close
argument-hint: <slug> [--gates-on] [--gates-off] [--max-cycles=N]
allowed-tools: Bash, Read, SlashCommand, Task
---

# /lean-spec:auto

Auto-driver. Given a feature slug, runs phase-advancing slash commands back-to-back using `lib/next-command.sh` as the resolver. By default fully autonomous (`--gates-off`); pass `--gates-on` to pause once — before close — so you can inspect the output before the feature is marked closed.

**Safety**: hard cap of 5 cycles (override with `--max-cycles=N`). `BLOCKED` or review verdict `BLOCKED` stops immediately. User can interrupt the orchestrator turn at any time — each phase command is a separate dispatch, so stopping mid-feature leaves a valid `workflow.json`.

## Pre-flight

Parse `$ARGUMENTS`:

```bash
ARGS="$ARGUMENTS"
SLUG=""
GATES_ON=0
MAX_CYCLES=5

for tok in $ARGS; do
  case "$tok" in
    --gates-on)      GATES_ON=1 ;;
    --gates-off)     GATES_ON=0 ;;
    --unattended)    GATES_ON=0 ;;   # alias for --gates-off
    --max-cycles=*)  MAX_CYCLES="${tok#--max-cycles=}" ;;
    --*)             echo "Unknown flag: $tok" ;;
    *)               [ -z "$SLUG" ] && SLUG="$tok" ;;
  esac
done

if [ -z "$SLUG" ]; then
  echo "Usage: /lean-spec:auto <slug> [--gates-on] [--gates-off] [--max-cycles=N]"
  exit 1
fi

WF="features/$SLUG/workflow.json"
if [ ! -f "$WF" ]; then
  echo "Feature '$SLUG' not found. Run /lean-spec:start-spec $SLUG first, then /lean-spec:auto."
  exit 1
fi

source "${CLAUDE_PLUGIN_ROOT}/lib/next-command.sh"

# Read model overrides from .lean-spec/rules.yaml (if present)
RULES_YAML=".lean-spec/rules.yaml"
MODEL_ARCHITECT=""
MODEL_REVIEWER=""
MODEL_CODER=""
if [ -f "$RULES_YAML" ]; then
  MODEL_ARCHITECT=$(python3 -c "
import sys
try:
  import re
  txt = open('$RULES_YAML').read()
  m = re.search(r'^models:\s*\n(?:[ \t]+\S[^\n]*\n)*?[ \t]+architect:\s*(\S+)', txt, re.M)
  print(m.group(1) if m else '')
except: print('')
" 2>/dev/null || true)
  MODEL_REVIEWER=$(python3 -c "
import sys
try:
  import re
  txt = open('$RULES_YAML').read()
  m = re.search(r'^models:\s*\n(?:[ \t]+\S[^\n]*\n)*?[ \t]+reviewer:\s*(\S+)', txt, re.M)
  print(m.group(1) if m else '')
except: print('')
" 2>/dev/null || true)
  MODEL_CODER=$(python3 -c "
import sys
try:
  import re
  txt = open('$RULES_YAML').read()
  m = re.search(r'^models:\s*\n(?:[ \t]+\S[^\n]*\n)*?[ \t]+coder:\s*(\S+)', txt, re.M)
  print(m.group(1) if m else '')
except: print('')
" 2>/dev/null || true)
fi
```

## Driver loop (orchestrator executes this)

The orchestrator iterates up to `MAX_CYCLES` times. On each iteration:

1. **Read workflow.json** → current `phase`.
2. **If `phase == "closed"`**, STOP — report success.
3. **Resolve next command** via `next_command_for "$WF"`. If empty (or starts with `#`), STOP — report the reason (likely `BLOCKED` or `closed`).
4. **Close gate** (only when `--gates-on` AND the resolved command starts with `/lean-spec:close-spec`):
   Print:
   ```
   [lean-spec:auto] Feature '$SLUG' — reviewer approved.
   Next: close-spec (marks feature as closed).
   Review the output at features/$SLUG/ if you'd like, then reply 'yes' to close or anything else to stop.
   ```
   Wait for the user's next message. If they reply "yes" (case-insensitive, trimmed), proceed. Otherwise stop and print:
   ```
   Auto-driver paused at close gate. Resume with /lean-spec:close-spec $SLUG or /lean-spec:auto $SLUG --gates-on.
   ```
5. **Dispatch the next command** using the `SlashCommand` tool with the resolved command string. Wait for completion. (The model overrides in `$MODEL_ARCHITECT`, `$MODEL_REVIEWER`, `$MODEL_CODER` are propagated by the underlying slash commands — `update-spec`, `submit-implementation`, `submit-review`, and `submit-fixes` each read `.lean-spec/rules.yaml` independently before dispatching their subagents.)
6. **Re-read workflow.json** — the phase should have advanced. If it hasn't (e.g. hook blocked), report the error and stop.
7. **Loop**.

## Verdict handling in reviewing phase

When the reviewer returns:

- `APPROVE` → resolver returns `/lean-spec:close-spec`; close gate fires if `--gates-on`, otherwise auto-closes
- `NEEDS_FIXES` → resolver returns `/lean-spec:submit-fixes`; auto continues to fix cycle, then back through review
- `BLOCKED` → resolver returns a `# BLOCKED …` comment; auto STOPS and prints the reason

## Why 5 cycles

Empirically from the Pomodoro experiments, good-plugin + precise-spec converges in 0–1 fix cycles. 3+ is a signal the spec was weak or the coder's model tier is under-provisioned for the feature. 5 is a generous cap; if you hit it, stop and fix the spec (or widen the coder tier) rather than continuing the loop.

## Gate modes

| Flag | Behaviour |
|---|---|
| _(default / `--gates-off`)_ | Fully autonomous — drives spec→implement→review→close without pausing |
| `--gates-on` | Pauses once, before `close-spec`, for human inspection |
| `--unattended` | Alias for `--gates-off` (backward-compatible) |

Use `--gates-on` when you want to review the implementation before it's officially closed but don't want to babysit the implement/review/fix cycle.

## Interaction with telemetry (F19)

When `LEAN_SPEC_TELEMETRY=1` is set (or `~/.lean-spec/telemetry` contains `on`), each phase transition is appended to `~/.lean-spec/telemetry.jsonl`. See `/lean-spec:telemetry` for the report view.
