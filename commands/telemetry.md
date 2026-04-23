---
description: Print per-feature phase durations from the opt-in telemetry log
argument-hint: "[<slug>]"
allowed-tools: Bash, Read
---

# /lean-spec:telemetry

Report on the opt-in telemetry log (`~/.lean-spec/telemetry.jsonl`). Prints phase transitions + wall-time per phase per feature.

Telemetry is **opt-in** and **local-only**. No network calls; no aggregation service. Enable with:

```bash
export LEAN_SPEC_TELEMETRY=1
# OR persistent:
mkdir -p ~/.lean-spec && echo "on" > ~/.lean-spec/telemetry
```

Once enabled, every phase advance (architect finishes spec, coder finishes notes, reviewer finishes review, feature closed) is appended as a JSONL record. The sync is idempotent — the `Stop` hook scans `features/*/workflow.json` and catches up anything missing.

## Steps

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/telemetry.sh"

if ! telemetry_enabled; then
  echo "Telemetry is disabled. Enable with LEAN_SPEC_TELEMETRY=1 or ~/.lean-spec/telemetry=on."
  exit 0
fi

# Force a sync pass in case the Stop hook hasn't fired yet this session
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
telemetry_sync_all "$PROJ"

FILTER="${ARGUMENTS:-}"
telemetry_report "$FILTER"
```

## Use cases

- **Verify cost-arbitrage** empirically — measure wall-time per phase across the canonical Haiku-coder default vs. a Sonnet/Opus-coder override, at your own cost.
- **Spot feature outliers** — a feature stuck in `reviewing` for 10× the usual means something is wrong with the spec or review criteria.
- **Retro a sprint** — aggregate elapsed times across closed features to report "features/week" and "avg time to close".

## What's NOT tracked (by design)

- Token counts per call — Claude Code hooks don't expose these reliably; getting them requires wrapping the `claude` CLI, out of scope for this plugin.
- Individual prompts, agent outputs, or user messages — never written anywhere outside the project's own artifacts.
- Hostname, user identity, or any network-addressable metadata.

The record shape is exactly:

```json
{"slug": "pomodoro", "phase": "closed", "prev_phase": "reviewing", "entered_at": "...", "logged_at": "...", "elapsed_prev_ms": 200000}
```

## Disabling

```bash
unset LEAN_SPEC_TELEMETRY
# AND
rm ~/.lean-spec/telemetry
# Optionally, to wipe history:
rm ~/.lean-spec/telemetry.jsonl
```
