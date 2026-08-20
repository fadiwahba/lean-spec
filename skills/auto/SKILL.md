---
name: auto
description: Hands-free mode for one feature. The CLI writes .lean-spec/auto.json and the automatic-run adapter requests each subsequent phase until the feature is closed, BLOCKED, NEEDS_INPUT, or the cycle cap is hit.
---

# `auto` <slug> [--gates-on] [--max-cycles=N]

This skill only *starts* the loop — it never drives more than the first
step itself. Everything after that is the host automatic-run adapter, which
calls CLI-owned `auto tick`. A deterministic JSON check beats a model
"should I continue?" judgment call.

## Steps

1. `bin/lean-spec ensure <slug>` (idempotent — no-op if it already exists).
2. Arm the driver via the CLI — **never write the file yourself**:
   ```
   bin/lean-spec auto arm <slug> [--gates-on] [--max-cycles=N]
   ```
   The CLI owns `.lean-spec/auto.json`'s schema, defaults, provenance and
   atomic write, exactly as `advance` owns `workflow.json`. A direct
   `Write`/`Edit` of that path is denied by
   `hooks/pre-tool-use-guard.sh`.

   `--gates-on` sets `gates_on: true` (reserved for stricter per-phase
   confirmation policies — today every quality gate is already always-on
   via the CLI/hooks regardless of this flag; it is recorded for
   forward-compatibility). `--max-cycles=N` overrides the default cap of
   20; omit for the default.
3. Run `bin/lean-spec next <slug>` yourself once, and dispatch whatever
   skill it names (exactly as `next` would). This performs the
   first cycle in the same turn as `auto` was invoked.
4. From here on, do nothing further yourself. When the host reports a stop
   event, its adapter calls `bin/lean-spec auto tick --run-id <id> --event-id
   <id>`. The CLI returns `READY`, `NEEDS_INPUT`, `BLOCKED`, or `COMPLETE` and
   persists that result. It never relies on the adapter to delete or edit
   `.lean-spec/auto.json`.

## Never does

- Loop manually in prose ("now I'll run implement, then review, ...") —
  that duplicates the hook's job and can't be interrupted safely. Start
  the loop, then stop; the hook takes it from there.
- Bypass the cycle cap, input stop, or BLOCKED-stops-the-line rule — the CLI
  enforces them, not this skill.
- Write, edit, or delete `.lean-spec/auto.json` by hand (including via a
  Bash heredoc or `rm`). Arming a run is the user's decision; use
  `bin/lean-spec auto arm`/`auto disarm` and only when the user asked
  for it.
