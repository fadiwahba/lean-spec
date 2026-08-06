---
name: auto
description: Hands-free mode for one feature — writes .lean-spec/auto.json and runs the first step; the Stop hook (stop-auto-driver.sh) drives every subsequent phase until the feature is closed, BLOCKED, or the cycle cap is hit.
disable-model-invocation: true
---

# /lean-spec:auto <slug> [--gates-on] [--max-cycles=N]

This skill only *starts* the loop — it never drives more than the first
step itself. Everything after that is `hooks/stop-auto-driver.sh` (a
`Stop` hook), per PRD R4: a deterministic JSON check beats a model
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
   skill it names (exactly as `/lean-spec:next` would). This performs the
   first cycle in the same turn as `/lean-spec:auto` was invoked.
4. From here on, do nothing further yourself: when your turn ends, the
   `Stop` hook reads `.lean-spec/auto.json`, and if the feature isn't
   closed/BLOCKED/capped, blocks the stop with a reason naming the next
   skill to run. It removes `.lean-spec/auto.json` and allows the stop
   once the feature reaches `closed`, a reviewer verdict is `BLOCKED`, or
   `cycles` reaches `max_cycles`.

## Never does

- Loop manually in prose ("now I'll run implement, then review, ...") —
  that duplicates the hook's job and can't be interrupted safely. Start
  the loop, then stop; the hook takes it from there.
- Bypass the cycle cap or the BLOCKED-stops-the-line rule — those are
  enforced in `hooks/stop-auto-driver.sh`, not here.
- Write, edit, or delete `.lean-spec/auto.json` by hand (including via a
  Bash heredoc or `rm`). Arming a run is the user's decision; use
  `bin/lean-spec auto arm`/`auto disarm` and only when the user asked
  for it.
