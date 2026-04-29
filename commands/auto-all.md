---
description: Drive all non-closed features through the full lifecycle sequentially
argument-hint: "[--gates-on] [--max-cycles=N]"
allowed-tools: Bash, Read, SlashCommand
---

# /lean-spec:auto-all

Runs after `/lean-spec:decompose-prd`. Finds every feature whose `workflow.json` phase is not `closed` and drives each through the full lifecycle using `/lean-spec:auto` as the per-feature driver.

**Default: fully autonomous (`--gates-off`)**. Pass `--gates-on` to pause before closing each feature.

## Pre-flight

```bash
GATES_ON=0
MAX_CYCLES=5

for tok in $ARGUMENTS; do
  case "$tok" in
    --gates-on)      GATES_ON=1 ;;
    --gates-off)     GATES_ON=0 ;;
    --max-cycles=*)  MAX_CYCLES="${tok#--max-cycles=}" ;;
  esac
done

PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
FEATURES_DIR="$PROJ/features"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "No features/ directory found. Run /lean-spec:decompose-prd first."
  exit 1
fi
```

## Driver

1. Collect all non-closed slugs:

   ```bash
   mapfile -t SLUGS < <(
     find "$FEATURES_DIR" -name "workflow.json" -exec \
       jq -r 'select(.phase != "closed") | .slug' {} \;
   )
   ```

2. If `SLUGS` is empty: report "All features are already closed." and stop.

3. Report the plan:

   ```
   lean-spec:auto-all — found N feature(s) to drive:
     • slug-a  (phase: specifying)
     • slug-b  (phase: implementing)
   Gates: on|off
   ```

   Read each non-closed workflow.json to get its current phase for the plan display.

4. For each slug in SLUGS:
   - Print: `[auto-all] Starting: <slug>`
   - Build the auto command:
     - If `GATES_ON=1`: `/lean-spec:auto <slug> --gates-on --max-cycles=N`
     - Otherwise: `/lean-spec:auto <slug> --max-cycles=N`
   - Dispatch via `SlashCommand` and wait for completion.
   - Re-read `features/<slug>/workflow.json`:
     - If phase is `closed`: print `[auto-all] Closed: <slug>`
     - Otherwise: print `[auto-all] BLOCKED: <slug> — stopping auto-all.` and stop the loop.

5. Final report:

   ```
   auto-all complete.
     Closed:  N features
     Blocked: M features
   ```

## Note

Each feature runs to completion before the next starts. Parallelism across features is not supported — sequential makes progress tracing straightforward and avoids concurrent `workflow.json` writes.
