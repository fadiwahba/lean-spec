---
description: Drive a feature through the full lifecycle (specify → implement → review → close), pausing at phase boundaries for optional human confirmation
argument-hint: <slug> [--unattended] [--max-cycles N]
allowed-tools: Bash, Read, SlashCommand, Task
---

# /lean-spec:auto

Auto-driver (PRD F17+F18). Given a feature slug, runs phase-advancing slash commands back-to-back using `lib/next-command.sh` as the resolver. By default, pauses at each phase boundary for user confirmation; `--unattended` skips the checkpoints.

**Safety**: hard cap of 5 cycles (override with `--max-cycles N`). `BLOCKED` or review verdict `BLOCKED` stops immediately. User can interrupt the orchestrator turn at any time — each phase command is a separate dispatch, so stopping mid-feature leaves a valid workflow.json.

## Pre-flight

Parse `$ARGUMENTS`:

```bash
ARGS="$ARGUMENTS"
SLUG=""
UNATTENDED=0
MAX_CYCLES=5

# Simple positional + flag parse
for tok in $ARGS; do
  case "$tok" in
    --unattended) UNATTENDED=1 ;;
    --max-cycles=*) MAX_CYCLES="${tok#--max-cycles=}" ;;
    --*) echo "Unknown flag: $tok" ;;
    *)
      [ -z "$SLUG" ] && SLUG="$tok"
      ;;
  esac
done

if [ -z "$SLUG" ]; then
  echo "Usage: /lean-spec:auto <slug> [--unattended] [--max-cycles=N]"
  exit 1
fi

WF="features/$SLUG/workflow.json"
if [ ! -f "$WF" ]; then
  echo "Feature '$SLUG' not found. Run /lean-spec:start-spec $SLUG first, then /lean-spec:auto."
  echo ""
  echo "(This command does not auto-run start-spec because it needs a brief/PRD reference"
  echo "that would be ambiguous in auto mode. Explicit start is safer.)"
  exit 1
fi

source "${CLAUDE_PLUGIN_ROOT}/lib/next-command.sh"
```

## Driver loop (orchestrator executes this)

The orchestrator iterates up to `MAX_CYCLES` times. On each iteration:

1. **Read workflow.json** → current `phase`.
2. **If `phase == "closed"`**, STOP — report success.
3. **Resolve next command** via `next_command_for "$WF"`. If empty (or starts with `#`), STOP — report the reason (likely `BLOCKED` or `closed`).
4. **Checkpoint** (unless `--unattended`):
   Print:
   ```
   [Auto cycle N/MAX_CYCLES] Feature '$SLUG' is in phase: $PHASE
   Next step: <resolved command>
   Continue? (reply 'yes' to run, anything else to stop)
   ```
   Wait for the user's next message. If they reply "yes" (case-insensitive, trimmed), proceed. Otherwise stop and print:
   ```
   Auto-driver paused by user. Resume with /lean-spec:auto $SLUG or run the next step manually.
   ```
5. **Dispatch the next command** using the `SlashCommand` tool with the resolved command string. Wait for completion.
6. **Re-read workflow.json** — the phase should have advanced. If it hasn't (e.g. hook blocked), report the error and stop.
7. **Loop**.

## Verdict handling in reviewing phase

When the reviewer returns:

- `APPROVE` → resolver returns `/lean-spec:close-spec`; auto continues to the close step
- `NEEDS_FIXES` → resolver returns `/lean-spec:submit-fixes`; auto continues to fix cycle, then back through review
- `BLOCKED` → resolver returns a `# BLOCKED …` comment; auto STOPS and prints the reason

## Why 5 cycles

Empirically from the Pomodoro experiments, good-plugin + precise-spec converges in 0–1 fix cycles. 3+ is a signal the spec was weak or the coder's model tier is under-provisioned for the feature. 5 is a generous cap; if you hit it, stop and fix the spec (or widen the coder tier) rather than continuing the loop.

## Unattended mode

Use `/lean-spec:auto <slug> --unattended` for CI-style runs or when you're confident the spec is tight. No checkpoints, pure forward drive until closed or BLOCKED.

## Interaction with telemetry (F19)

When `LEAN_SPEC_TELEMETRY=1` is set, each phase transition is also appended to `~/.lean-spec/telemetry.jsonl`. See `commands/telemetry.md` for the report view.
