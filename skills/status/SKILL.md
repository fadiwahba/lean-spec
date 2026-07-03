---
name: status
description: Read-only — reports current phase (and, in reviewing, the verdict) for one feature or every feature, by calling bin/lean-spec status. Safe to invoke any time; makes no state changes.
---

# /lean-spec:status [<slug>]

Passthrough to the CLI — this skill contains no logic of its own.

## Steps

1. No argument: run `bin/lean-spec status` and report the phase of every
   feature.
2. `<slug>` given: run `bin/lean-spec status <slug>` and report its full
   detail (phase, created/updated timestamps, history length, and verdict
   when in `reviewing`).

## Never does

- Mutate any state — `status` is read-only by construction (the CLI
  subcommand never writes).
