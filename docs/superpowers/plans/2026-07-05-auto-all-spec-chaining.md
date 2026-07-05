# auto-all spec-chaining Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `/lean-spec:auto-all` an opt-in `--no-confirm` flag that chains into speccing the next slice (one at a time, sentinel-terminated) instead of stopping when nothing's left to drain — including a cold start on a project with zero specced features — so a small/simple PRD can run hands-off from a single command, without reopening R8 (no upfront decomposition).

**Architecture:** All new logic lives in `hooks/stop-auto-driver.sh` (one new decision branch reusing the existing, unmodified `chained:` rescan for the ongoing handoff) plus four markdown files (`skills/auto-all/SKILL.md`, `skills/spec/SKILL.md`, `agents/architect.md`, `docs/PRD.md`). No `bin/lean-spec` (CLI) changes. No changes to `subagent-stop-gate.sh` or `pre-tool-use-guard.sh`.

**Tech Stack:** bash (macOS bash 3.2 compatible — no bashisms) + embedded python3 stdlib (the hook), bats-core (tests), markdown (skills/agents/docs).

## Global Constraints

- Full design: `docs/superpowers/specs/2026-07-05-auto-all-spec-chaining-design.md` (read it — this plan implements it exactly; do not reintroduce the rejected approaches listed in its "Revision history").
- bash 3.2 compatible: no `${var,,}`, no associative arrays, no `[[ ]]` inside a `$()`-embedded python heredoc's *comments* if it contains a literal single-quote (see existing comment in `hooks/stop-auto-driver.sh` around line 125 for why).
- No fenced ` ```bash `/` ```sh ` code blocks inside any `SKILL.md` — `tests/scaffold_skills_agents.bats` greps for and rejects this (use a bare ` ``` ` fence, exactly as `skills/plan/SKILL.md` and `skills/spec/SKILL.md` already do for their preflight command blocks).
- `json.dumps(..., ensure_ascii=False)` for any new block-reason JSON emission — the existing code already does this (fixed in a prior release) so a non-ASCII character (em dash, etc.) doesn't reintroduce `\uXXXX` backslash escapes.
- Run `.tools/bin/bats tests/` (bootstrap via `./scripts/bootstrap-bats.sh` if `.tools/bin/bats` doesn't exist yet) after every task — all green is the acceptance bar for that task, and the whole plan is done when the full suite passes with the new cases included.
- Every commit is small and scoped to its task; follow the repo's existing commit style (`fix:`/`feat:`/`docs:` prefix, no "Co-Authored-By" line per this project's own convention observed in its git log).
- Branch: `feature/auto-all-spec-chaining` (already exists, already has the two design-doc commits on it — work continues on this branch, do not create a new one).

---

### Task 1: `hooks/stop-auto-driver.sh` — the `spec_next` decision

**Files:**
- Modify: `hooks/stop-auto-driver.sh` (python decision block ~lines 100-171, bash reason-building ~lines 175-242)
- Test: `tests/hooks_stop_auto_driver.bats` (insert after the existing `"chain_all: stops entirely once every feature is closed"` test, which currently ends at line 243)

**Interfaces:**
- Consumes: nothing new from other tasks — this is the foundational task.
- Produces: the `.lean-spec/auto.json` schema gains three optional fields (`no_confirm: bool`, `max_features: int`, `features_specced: int`) that Task 4 (`skills/auto-all/SKILL.md`) documents as being written by `/lean-spec:auto-all --no-confirm [--max-features=N]`. The new block-reason text (produced here) references `skills/spec/SKILL.md`'s `--no-confirm` mode, which Task 2 implements — but this task's tests only check the *reason text*, not that the referenced skill file behaves correctly, so there's no build-order dependency; Task 1 can be built and tested standalone.

- [ ] **Step 1: Write the failing tests**

Open `tests/hooks_stop_auto_driver.bats` and insert the following seven `@test` blocks immediately after the `"chain_all: stops entirely once every feature is closed"` test (i.e. right before the `"chain_all: chaining to a blocked feature stops the chain and escalates"` test):

```
@test "chain_all + no_confirm: no feature remains and cap not hit emits spec_next, increments features_specced" {
  lean_spec ensure demo
  write_valid_spec demo
  lean_spec advance demo specifying implementing
  write_valid_notes demo
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":5,"chain_all":true,"no_confirm":true,"max_features":20,"features_specced":0}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *"--no-confirm"* ]]
  [[ "$output" == *"NO_REMAINING_SCOPE"* ]]
  run python3 -c "import json; d=json.load(open('.lean-spec/auto.json')); print(d['slug'], d['cycles'], d['features_specced'])"
  [ "$output" = "demo 5 1" ]
}

@test "chain_all + no_confirm: cap reached stops and removes auto.json" {
  lean_spec ensure demo
  write_valid_spec demo
  lean_spec advance demo specifying implementing
  write_valid_notes demo
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":5,"chain_all":true,"no_confirm":true,"max_features":3,"features_specced":3}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f .lean-spec/auto.json ]
}

@test "chain_all + no_confirm: max_features defaults to 20 when omitted" {
  lean_spec ensure demo
  write_valid_spec demo
  lean_spec advance demo specifying implementing
  write_valid_notes demo
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":0,"chain_all":true,"no_confirm":true}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "block"'* ]]
  run python3 -c "import json; print(json.load(open('.lean-spec/auto.json'))['features_specced'])"
  [ "$output" = "1" ]
}

@test "chain_all + no_confirm: non-numeric max_features stops instead of spec_next (safe default on garbage)" {
  lean_spec ensure demo
  write_valid_spec demo
  lean_spec advance demo specifying implementing
  write_valid_notes demo
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":0,"chain_all":true,"no_confirm":true,"max_features":"garbage","features_specced":0}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f .lean-spec/auto.json ]
}

@test "chain_all + no_confirm: spec_next reason uses the absolute plugin-root path, not a bare relative one" {
  lean_spec ensure demo
  write_valid_spec demo
  lean_spec advance demo specifying implementing
  write_valid_notes demo
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":0,"chain_all":true,"no_confirm":true,"max_features":20,"features_specced":0}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"${LEAN_SPEC_REPO_ROOT}/skills/spec/SKILL.md"* ]]
}

@test "chain_all + no_confirm: spec_next reason does not leak the closed slug or the generic fallback text" {
  lean_spec ensure demo
  write_valid_spec demo
  lean_spec advance demo specifying implementing
  write_valid_notes demo
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":0,"chain_all":true,"no_confirm":true,"max_features":20,"features_specced":0}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [[ "$output" != *"bin/lean-spec next demo"* ]]
}

@test "chain_all without no_confirm: no feature remains still stops exactly as today (regression guard)" {
  lean_spec ensure demo
  write_valid_spec demo
  lean_spec advance demo specifying implementing
  write_valid_notes demo
  lean_spec advance demo implementing reviewing
  mkdir -p features/demo
  echo "verdict: APPROVE" > features/demo/review.md
  lean_spec advance demo reviewing closed
  write_auto <<'EOF'
{"slug":"demo","gates_on":false,"max_cycles":20,"cycles":1,"chain_all":true}
EOF
  run driver '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f .lean-spec/auto.json ]
}
```

Note: the last test duplicates the existing `"chain_all: stops entirely once every feature is closed"` test almost exactly — that's intentional. It's a regression guard specifically placed *next to* the new `no_confirm` tests so a future reader sees the "off" and "on" behaviors side by side; the original test stays as-is too (belt and suspenders, not a replacement).

- [ ] **Step 2: Run the new tests to verify they fail**

Run:
```
cd /Users/fady/sandbox/lean-spec/lean-spec && ./scripts/bootstrap-bats.sh && .tools/bin/bats tests/hooks_stop_auto_driver.bats
```
Expected: the six new `no_confirm`-related tests FAIL (the seventh, the regression guard, PASSES already since it doesn't touch new behavior) — because `auto.json`'s `no_confirm`/`max_features`/`features_specced` fields don't exist yet in the driver script, so every "no feature remains" case falls straight to today's `stop`/remove behavior regardless of `no_confirm`.

- [ ] **Step 3: Implement the python decision-block change**

In `hooks/stop-auto-driver.sh`, find this existing block (inside the `if action == "closed":` handling):

```python
if action == "closed":
    if auto.get("chain_all"):
        nxt = next_non_closed_slug(project_root)
        if nxt is not None:
            auto["slug"] = nxt
            auto["cycles"] = 0
            atomic_write(auto_path, auto)
            print(f"chained:{nxt}")
            sys.exit(0)
    try:
        os.remove(auto_path)
    except OSError:
        pass
    print("stop")
    sys.exit(0)
```

Replace it with:

```python
if action == "closed":
    if auto.get("chain_all"):
        nxt = next_non_closed_slug(project_root)
        if nxt is not None:
            auto["slug"] = nxt
            auto["cycles"] = 0
            atomic_write(auto_path, auto)
            print(f"chained:{nxt}")
            sys.exit(0)
        if auto.get("no_confirm"):
            max_features = coerce_int(auto.get("max_features", 20), 20)
            features_specced = coerce_int(auto.get("features_specced", 0), 0)
            if (
                max_features is not None
                and features_specced is not None
                and features_specced < max_features
            ):
                auto["features_specced"] = features_specced + 1
                atomic_write(auto_path, auto)
                print("spec_next")
                sys.exit(0)
    try:
        os.remove(auto_path)
    except OSError:
        pass
    print("stop")
    sys.exit(0)
```

This is the only python change. Note it reuses the existing `coerce_int` helper (already defined above this block) and the existing `atomic_write` helper — no new helper functions needed. A garbage/non-numeric `max_features`/`features_specced` makes the `is not None` guard false, so it falls through to the unchanged `stop`/remove path — the safe default (per the design: don't auto-spec on garbage cap data, but still let the run terminate cleanly).

- [ ] **Step 4: Implement the bash-side `spec_next` interception**

In `hooks/stop-auto-driver.sh`, find this existing block:

```bash
if [ "$decision" = "disarm" ]; then
  echo "lean-spec auto: could not resolve next step for '${slug}' — auto mode disarmed" >&2
  exit 0
fi

case "$decision" in
```

Insert a new `if` block between them, so it reads:

```bash
if [ "$decision" = "disarm" ]; then
  echo "lean-spec auto: could not resolve next step for '${slug}' — auto mode disarmed" >&2
  exit 0
fi

if [ "$decision" = "spec_next" ]; then
  reason="lean-spec auto-all: no non-closed feature remains and --no-confirm is set — read ${PLUGIN_ROOT}/skills/spec/SKILL.md now and follow its no-arg Steps yourself with --no-confirm (skip the AskUserQuestion) to propose and write the next slice. The propose dispatch returns either '<slug>: <one-line scope>' or the literal sentinel NO_REMAINING_SCOPE — treat ANY other or malformed response the same as the sentinel (fail-safe: stop, do not retry or guess). If it is the sentinel (or unparseable): delete .lean-spec/auto.json and stop — the PRD is fully covered. Otherwise: ensure the new slug and dispatch the architect to write spec.md exactly as /lean-spec:spec normally would. Do not touch .lean-spec/auto.json yourself — the driver picks up the new feature (and resets its cycle count to 0) automatically via the existing next-non-closed-feature rescan on your next turn-end."
  python3 -c 'import json, sys; print(json.dumps({"decision": "block", "reason": sys.argv[1]}, ensure_ascii=False))' "$reason"
  exit 0
fi

case "$decision" in
```

This must come *before* the `case "$decision" in chained:*) ... esac` block and the generic reason-builder that follows it, so `spec_next` never falls through to code that rebuilds `reason` from the stale `$next_json`/`$slug` (the just-closed feature's `next` output, which has `skill: null` — that fallback path would emit a broken, wrong-feature reason). `$PLUGIN_ROOT` is already in scope (set at the top of the script); the em dash and single quotes in the reason string are safe as a plain bash double-quoted assignment (no python argv threading needed here, since nothing in this reason is dynamic per-call).

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```
cd /Users/fady/sandbox/lean-spec/lean-spec && .tools/bin/bats tests/hooks_stop_auto_driver.bats
```
Expected: all tests pass (the file should report `1..26` or similar with zero `not ok` lines — 19 pre-existing + 7 new).

- [ ] **Step 6: Run the full suite to check for regressions**

Run:
```
cd /Users/fady/sandbox/lean-spec/lean-spec && .tools/bin/bats tests/*.bats
```
Expected: all tests pass, including every pre-existing `chain_all`/`cycles`/`max_cycles` test — this change only adds a new branch reached exclusively when `no_confirm` is truthy, so nothing else should move.

- [ ] **Step 7: Commit**

```bash
git add hooks/stop-auto-driver.sh tests/hooks_stop_auto_driver.bats
git commit -m "feat: chain auto-all into speccing the next slice (--no-confirm)

Adds the spec_next decision to stop-auto-driver.sh: when chain_all is
active, no non-closed feature remains, and no_confirm is set (below
the max_features cap), the driver now points the model at
skills/spec/SKILL.md's no-arg --no-confirm flow instead of stopping.
The ongoing handoff (once the new spec exists) reuses the existing,
unmodified chained: rescan -- no new bookkeeping for slug/cycles."
```

---

### Task 2: `skills/spec/SKILL.md` — `--no-confirm` mode

**Files:**
- Modify: `skills/spec/SKILL.md`
- Test: `tests/scaffold_skills_agents.bats`

**Interfaces:**
- Consumes: nothing from Task 1 directly (this is a documentation-only change to the skill's own contract).
- Produces: the documented `--no-confirm` contract that Task 1's block reason (already written) tells the model to follow, and that Task 4's `auto-all` cold-start clause references by name.

- [ ] **Step 1: Write the failing test**

In `tests/scaffold_skills_agents.bats`, insert immediately after the existing `"spec skill feeds the architect the delivered ACs of closed slices"` test:

```
@test "spec skill documents --no-confirm and the fail-safe sentinel rule" {
  grep -q -- '--no-confirm' "${LEAN_SPEC_REPO_ROOT}/skills/spec/SKILL.md"
  grep -q 'NO_REMAINING_SCOPE' "${LEAN_SPEC_REPO_ROOT}/skills/spec/SKILL.md"
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `.tools/bin/bats tests/scaffold_skills_agents.bats`
Expected: this new test FAILS (neither string exists in `skills/spec/SKILL.md` yet).

- [ ] **Step 3: Update `skills/spec/SKILL.md`**

Replace the file's content with the following (every section shown — this is the complete new file):

```
---
name: spec
description: Specs the next feature slice (or a named one) by dispatching the architect agent to write features/<slug>/spec.md. Use --refine to revise an existing spec, --no-confirm to skip the propose-confirmation for an unattended run (auto-all). One slice at a time — never decomposes the whole PRD upfront.
disable-model-invocation: true
---

# /lean-spec:spec [<slug>] [--refine] [--no-confirm]

## Preflight (fail-loud)

Before proposing or speccing any slice, verify the project docs the
architect depends on exist and are actually filled (not the
`/lean-spec:init` placeholder skeletons):

```
bin/lean-spec validate --project PRD.md
bin/lean-spec validate --project CONSTITUTION.md
```

If either `validate --project` call exits non-zero, STOP and show the
CLI's one-line message verbatim. Do not dispatch the architect against a
missing or placeholder PRD/CONSTITUTION — run `/lean-spec:init` then
`/lean-spec:plan` first.

## Determine the slug

- **No argument:** dispatch the `architect` agent (Task tool) to read
  `docs/PRD.md`, every `features/*/workflow.json` phase (via
  `bin/lean-spec status`), **and the `## Acceptance Criteria` of every
  closed slice's `spec.md`** — then propose the *next* slice. The
  architect's entire response is either `<slug>: <one-line scope>`, or,
  if no PRD scope remains undelivered, the literal sentinel
  `NO_REMAINING_SCOPE`.
  - **Without `--no-confirm`:** present the proposal to the user for
    confirmation before writing anything.
  - **With `--no-confirm`:** skip that confirmation — there is no live
    user to answer it in an unattended run (e.g. driven by
    `/lean-spec:auto-all --no-confirm`). Parse the response as
    `<slug>: <scope>`; treat the sentinel, or *any* response that
    doesn't parse that way (padding, extra prose, garbage, empty), the
    same — fail-safe, not exact-string-match-only. On the
    sentinel/unparseable case: delete `.lean-spec/auto.json` if it
    exists (a no-op if it doesn't — e.g. a cold-start caller that hasn't
    written it yet) and stop, reporting that the PRD is fully covered;
    write nothing. Otherwise proceed straight to Dispatch below with the
    parsed slug.
- **`<slug>` given:** spec that named slice directly.
- **`--refine`:** the slug must already exist and have a `spec.md`; dispatch
  the architect to revise it in place (same slug, same file).

## Dispatch

1. `bin/lean-spec ensure <slug>` — idempotent; creates `workflow.json` in
   `specifying` phase if this is a new feature.
2. Dispatch the `architect` agent via Task, with `docs/CONSTITUTION.md`'s
   content injected into the prompt, plus `docs/PRD.md`, current feature
   status, **the `## Acceptance Criteria` of every closed slice's `spec.md`
   (the "already delivered" ledger, so the architect never re-specs shipped
   work),** and (on `--refine`) the reason for revision. The architect
   writes `features/<slug>/spec.md`.
3. The `SubagentStop` hook validates `spec.md` automatically the moment
   the architect finishes (early gate). As a backstop, also run:
   ```
   bin/lean-spec validate <slug> spec.md
   ```
   If it fails, dispatch the architect again with the validator's output
   as feedback — do not hand-patch `spec.md` yourself.
4. Tell the orchestrator to commit: `spec(<slug>): <one-line scope>`.

`.lean-spec/auto.json` is never touched by this skill except the one
delete described above (the sentinel/unparseable case) — no slug or
cycle bookkeeping is this skill's job, whether run standalone or chained
from `/lean-spec:auto-all --no-confirm`.

## Never does

- Write `spec.md` content itself — only the architect agent does, via
  Task dispatch.
- Advance `workflow.json` — `specifying` is the entry phase; `ensure` is
  the only state mutation this skill performs. Phase advances to
  `implementing` at `/lean-spec:implement`.
- Spec more than one slice per invocation (R8: no upfront decomposition)
  — true with or without `--no-confirm`.
- Dispatch the architect when `validate --project` fails for PRD.md or
  CONSTITUTION.md — the preflight is mandatory.
- Retry or guess when the propose-dispatch response is ambiguous — treat
  any unparseable response as `NO_REMAINING_SCOPE` (fail-safe), never
  loop trying to reinterpret it.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `.tools/bin/bats tests/scaffold_skills_agents.bats`
Expected: all tests pass, including the new one.

- [ ] **Step 5: Run the full suite**

Run: `.tools/bin/bats tests/*.bats`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add skills/spec/SKILL.md tests/scaffold_skills_agents.bats
git commit -m "feat: add --no-confirm mode to /lean-spec:spec

Skips the propose-confirmation AskUserQuestion for unattended runs.
Fail-safe sentinel handling: any response that doesn't parse as
<slug>: <scope> (including but not limited to the literal
NO_REMAINING_SCOPE) is treated as PRD-fully-covered and stops cleanly
rather than retrying."
```

---

### Task 3: `agents/architect.md` — propose-dispatch sentinel contract

**Files:**
- Modify: `agents/architect.md`
- Test: `tests/scaffold_skills_agents.bats`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the `NO_REMAINING_SCOPE` sentinel contract that Tasks 1 and 2 both reference by name.

- [ ] **Step 1: Write the failing test**

In `tests/scaffold_skills_agents.bats`, insert immediately after the test added in Task 2:

```
@test "architect documents the NO_REMAINING_SCOPE sentinel for the propose dispatch only" {
  grep -q 'NO_REMAINING_SCOPE' "${LEAN_SPEC_REPO_ROOT}/agents/architect.md"
  grep -q 'Propose dispatch' "${LEAN_SPEC_REPO_ROOT}/agents/architect.md"
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `.tools/bin/bats tests/scaffold_skills_agents.bats`
Expected: FAILS (neither string exists in `agents/architect.md` yet).

- [ ] **Step 3: Update `agents/architect.md`**

Insert a new section between the existing `## Inputs` and `## Output — \`features/<slug>/spec.md\`` sections:

```
## Propose dispatch (no-arg `/lean-spec:spec` only)

When dispatched to *propose* the next slice — a separate, artifact-free
dispatch from the one below that writes `spec.md`, used only by the
no-arg form of `/lean-spec:spec` — your entire response is exactly one
of:

- `<slug>: <one-line scope>` — the next slice, cross-checked against the
  PRD and every closed slice's delivered ACs per Inputs above, or
- the literal string `NO_REMAINING_SCOPE`, nothing else, if no PRD scope
  remains undelivered.

Some callers (`/lean-spec:auto-all --no-confirm`) parse this response
without a human confirming it — return exactly one of the two forms
above, no extra prose, no partial-sentence padding around either one.
This section does not change the write dispatch below: once a slug is
chosen, you still write exactly one artifact, `spec.md`.
```

The full file, in order, is now: frontmatter → `# Architect` intro → `## Inputs` → `## Propose dispatch (no-arg /lean-spec:spec only)` (new) → `## Output — \`features/<slug>/spec.md\`` → `## Never does` → `## Constitution`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `.tools/bin/bats tests/scaffold_skills_agents.bats`
Expected: all green.

- [ ] **Step 5: Run the full suite**

Run: `.tools/bin/bats tests/*.bats`
Expected: all green. (Also spot-check the pre-existing `"each agent file has a Never does section"` and `"every artifact-writing agent grants a Write tool"` tests still pass — this insertion is between two existing sections and shouldn't perturb frontmatter or the `## Never does`/`## Constitution` sections those tests check.)

- [ ] **Step 6: Commit**

```bash
git add agents/architect.md tests/scaffold_skills_agents.bats
git commit -m "docs: scope the NO_REMAINING_SCOPE sentinel to the propose dispatch

Makes explicit that the architect's single-artifact mandate (spec.md)
applies only to the write dispatch -- the separate, no-arg propose
dispatch has its own two-shape contract (slug+scope, or the sentinel)
that /lean-spec:auto-all --no-confirm parses unattended."
```

---

### Task 4: `skills/auto-all/SKILL.md` — `--no-confirm [--max-features=N]` and cold start

**Files:**
- Modify: `skills/auto-all/SKILL.md`
- Test: `tests/scaffold_skills_agents.bats`

**Interfaces:**
- Consumes: Task 1's `auto.json` schema (`no_confirm`, `max_features`, `features_specced`) — this task documents that `/lean-spec:auto-all --no-confirm [--max-features=N]` is what writes those fields. Consumes Task 2's `/lean-spec:spec --no-confirm` contract by reference (the cold-start clause tells the model to inline that flow).
- Produces: nothing consumed by later tasks — this is the last skill-file change.

- [ ] **Step 1: Write the failing tests**

In `tests/scaffold_skills_agents.bats`, insert immediately after the test added in Task 3:

```
@test "auto-all skill documents --no-confirm and max_features" {
  grep -q -- '--no-confirm' "${LEAN_SPEC_REPO_ROOT}/skills/auto-all/SKILL.md"
  grep -q 'max_features' "${LEAN_SPEC_REPO_ROOT}/skills/auto-all/SKILL.md"
}

@test "auto-all skill documents the --no-confirm cold-start clause" {
  grep -qi 'cold start' "${LEAN_SPEC_REPO_ROOT}/skills/auto-all/SKILL.md"
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `.tools/bin/bats tests/scaffold_skills_agents.bats`
Expected: both new tests FAIL.

- [ ] **Step 3: Update `skills/auto-all/SKILL.md`**

Replace the file's content with the following (complete new file):

```
---
name: auto-all
description: Drives every non-closed feature to closed, sequentially, one .lean-spec/auto.json at a time. With --no-confirm, also chains into speccing the next slice (one at a time, sentinel-terminated) instead of stopping when nothing's left to drain. A BLOCKED verdict stops the whole chain and escalates.
disable-model-invocation: true
---

# /lean-spec:auto-all [--gates-on] [--no-confirm] [--max-features=N]

Same hook-owned mechanism as `/lean-spec:auto`, with `chain_all: true` so
`hooks/stop-auto-driver.sh` picks the next non-closed feature (sorted by
slug) instead of stopping when one closes.

`--no-confirm` additionally chains into speccing the *next* slice — one
at a time, never batch-decomposed (R8 unchanged) — instead of stopping
when no non-closed feature remains, so a whole small/simple PRD can run
hands-off from a single command. `--max-features=N` caps the total
number of slices auto-specced in one run (default 20, independent from
`--max-cycles`'s per-feature fix-loop cap). Omit `--no-confirm` and this
skill behaves exactly as it always has: drains only what already has a
`spec.md`, never specs new work.

## Steps

1. Find the first non-closed feature: `bin/lean-spec status --json` (or
   `next --all --json`), pick the first whose `phase` isn't `closed`.
   **If none exist:**
   - **`--no-confirm` not set:** report that and stop — this skill never
     runs `/lean-spec:spec` to create new work.
   - **`--no-confirm` set (cold start):** before writing `auto.json` at
     all, inline the exact same propose → sentinel-check → `ensure` →
     architect-write flow that `/lean-spec:spec --no-confirm` defines
     (see its SKILL.md's "Determine the slug" section). If the propose
     dispatch returns `NO_REMAINING_SCOPE` (or an unparseable response —
     treat it the same, fail-safe): report that the PRD has nothing to
     spec and stop; do not write `auto.json`. Otherwise the newly-specced
     slug becomes `<first-non-closed-slug>` below and you continue to
     step 2.
2. Write `.lean-spec/auto.json`:
   ```json
   {"slug": "<first-non-closed-slug>", "gates_on": <true|false>, "max_cycles": 20, "cycles": 0, "chain_all": true, "no_confirm": <true|false>, "max_features": <N, default 20>, "features_specced": 0}
   ```
   `no_confirm`/`max_features`/`features_specced` are only meaningful
   when `--no-confirm` is set; omit them when it isn't (today's exact
   shape, unchanged).
3. Run `bin/lean-spec next <slug>` once yourself and dispatch the named
   skill, same as `/lean-spec:auto`'s first step.
4. From here, `hooks/stop-auto-driver.sh` drives every phase for every
   feature in sequence: on each `closed` outcome it looks for the next
   non-closed feature and rewrites `auto.json` to target it (resetting
   `cycles` to 0). When none remain **and `--no-confirm` is not set**, it
   removes `auto.json` and allows the stop. **When `--no-confirm` is
   set** and none remain, the hook instead (bounded by `max_features`)
   points you at `/lean-spec:spec --no-confirm` for the next slice before
   falling back to the same stop once the cap is hit or the PRD is fully
   covered. A `BLOCKED` verdict or a `max_cycles` cap on any single
   feature stops the *entire* chain immediately (it does not skip ahead
   to the next feature) — this matches the CONSTITUTION's "BLOCKED
   verdicts stop the line and escalate to Fady."

## Never does

- Decompose the whole PRD upfront — even with `--no-confirm`, specs are
  written strictly one at a time, grounded in real closed-slice ACs
  (R8). `--no-confirm` automates the confirmation *cadence* between
  slices; it never batch-writes more than one `spec.md` in a single
  dispatch.
- Run two features concurrently — `chain_all` always drives exactly one
  `auto.json` at a time (PRD R9).
- Skip past a BLOCKED feature to keep draining the rest.
```

Note the removed bullet from the old `## Never does`: `"Spec a new feature — only drains features that already have a spec.md/workflow.json."` was accurate only when `--no-confirm` is absent; it's replaced above by the R8/batch-decomposition bullet, which is accurate unconditionally.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `.tools/bin/bats tests/scaffold_skills_agents.bats`
Expected: all green.

- [ ] **Step 5: Run the full suite**

Run: `.tools/bin/bats tests/*.bats`
Expected: all green — in particular re-check `tests/scaffold_skills_agents.bats`'s `"mutating skills set disable-model-invocation: true"` and `"no SKILL.md contains a bash phase-gate block"` tests, since this task rewrote the whole file (frontmatter must still have `disable-model-invocation: true`, and the one fenced block above must stay a bare ` ``` ` fence, not ` ```bash `/` ```json ` — the `json` fence used for the `auto.json` example is fine, the *bare* fence rule only forbids `bash`/`sh`).

- [ ] **Step 6: Commit**

```bash
git add skills/auto-all/SKILL.md tests/scaffold_skills_agents.bats
git commit -m "feat: add --no-confirm [--max-features=N] to /lean-spec:auto-all

Documents the new chaining behavior (step 4) and the cold-start clause
(step 1: when --no-confirm is set and no feature has ever been
specced, inline /lean-spec:spec --no-confirm's flow before writing
auto.json, instead of reporting and stopping). Corrects the old
unconditional 'never specs a new feature' Never-does bullet, which is
no longer true when --no-confirm is set."
```

---

### Task 5: `docs/PRD.md` — R17 and the skill-surface table

**Files:**
- Modify: `docs/PRD.md`

**Interfaces:**
- Consumes: nothing (pure documentation of what Tasks 1-4 already built).
- Produces: nothing consumed elsewhere — this is a project-history record, not behavior.

- [ ] **Step 1: Update the §6 skill-surface table**

Find this row (currently around line 99):

```
| `/lean-spec:auto-all [--gates-on]` | drive every non-closed feature to closed, sequentially (one `auto.json` at a time; does **not** spec new features) | hook-owned |
```

Replace it with:

```
| `/lean-spec:auto-all [--gates-on] [--no-confirm] [--max-features=N]` | drive every non-closed feature to closed, sequentially (one `auto.json` at a time); with `--no-confirm`, also chains into speccing the next slice one at a time, sentinel-terminated, instead of stopping (R17) | hook-owned |
```

- [ ] **Step 2: Add R17 to the §12 resolved-decisions table**

Find the last row of the table (currently `| R16 | ... |`) and add a new row immediately after it:

```
| R17 | `/lean-spec:auto-all --no-confirm` chains into speccing the next slice (one at a time, sentinel-terminated, fail-safe on any unparseable response) instead of stopping when nothing's left to drain | gives simple/small projects a hands-off "spec+build the whole PRD" flow without reopening R8: specs are still written sequentially, grounded in real closed-slice ACs, never batch-decomposed. Trades away the `--refine` mid-chain feedback loop for unattended projects — an accepted, scoped-down cost, not free. Opt-in and off by default — plain `/lean-spec:auto-all` is unchanged |
```

- [ ] **Step 3: Update the §13 resolved line**

Find (currently the last sentence of §13):

```
Resolved 2026-07-05: `spec` preflights project-doc readiness and `validate --project` rejects unfilled placeholders (R15) · `plan` grounds its interview in the existing repo for brownfield (R16).
```

Replace it with:

```
Resolved 2026-07-05: `spec` preflights project-doc readiness and `validate --project` rejects unfilled placeholders (R15) · `plan` grounds its interview in the existing repo for brownfield (R16) · `auto-all --no-confirm` chains into speccing the next slice, sentinel-terminated (R17).
```

- [ ] **Step 4: Run the full suite (no PRD.md-specific test exists, but confirm nothing else broke)**

Run: `.tools/bin/bats tests/*.bats`
Expected: all green (this file isn't grepped by any test — this step is a pure regression check).

- [ ] **Step 5: Commit**

```bash
git add docs/PRD.md
git commit -m "docs: record R17 (auto-all --no-confirm spec-chaining) in PRD.md"
```

---

### Task 6: Push, PR, review loop, and land

**Files:** none (process task).

- [ ] **Step 1: Run the complete test suite one final time**

Run:
```
cd /Users/fady/sandbox/lean-spec/lean-spec && .tools/bin/bats tests/*.bats
```
Expected: 100% pass, no `not ok` lines. Count should be the pre-existing baseline (175, per the last release) plus 11 new cases (7 from Task 1, 1 from Task 2, 1 from Task 3, 2 from Task 4) = 186.

- [ ] **Step 2: Push the branch**

```bash
git push -u origin feature/auto-all-spec-chaining
```

- [ ] **Step 3: Open the PR**

```bash
gh pr create --title "Chain auto-all into speccing the next slice (--no-confirm)" --body "$(cat <<'EOF'
## Summary
- /lean-spec:auto-all gets an opt-in --no-confirm flag [--max-features=N]: when no non-closed feature remains (mid-run, or cold-start on a fresh project), it chains into /lean-spec:spec --no-confirm instead of stopping, so a small/simple PRD can be spec+built hands-off from one command.
- Specs are still written strictly one at a time (R8 unchanged) -- this automates the confirmation cadence between slices, not upfront batch decomposition.
- Design + an adversarial Opus/xhigh review + revision history: docs/superpowers/specs/2026-07-05-auto-all-spec-chaining-design.md

## Test plan
- [x] 11 new bats cases across tests/hooks_stop_auto_driver.bats (7) and tests/scaffold_skills_agents.bats (4)
- [x] Full suite `.tools/bin/bats tests/*.bats` — all green
EOF
)"
```

- [ ] **Step 4: Wait for CI and Copilot review, same pattern as prior PRs in this repo**

Poll `gh pr checks <number>` until green; check `gh api repos/fadiwahba/lean-spec/pulls/<number>/reviews` for Copilot's review. If Copilot leaves an inline comment, note that this repo's branch-protection ruleset requires the review *thread* to be resolved (not just a follow-up commit pushed) — use the GraphQL `resolveReviewThread` mutation on the thread ID from `gh api graphql` if a fix commit doesn't clear the merge gate on its own (this bit the team on a prior PR in this repo).

- [ ] **Step 5: Merge**

```bash
gh pr merge <number> --squash --delete-branch
git checkout main && git pull --ff-only
```

- [ ] **Step 6: Version bump and release**

This is a new capability (not just a bug fix), so it's a **minor** semver bump. Check `.claude-plugin/plugin.json`'s current `version` first — bump to the next `X.Y+1.0`. Follow the exact release pattern already used twice in this repo's history (branch `release/vX.Y.0` → bump `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` → add a `CHANGELOG.md` entry under `### Added` → PR → merge → `git tag -a vX.Y.0` → `git push origin vX.Y.0` → `gh release create vX.Y.0`).

---

## Self-review notes (from the plan author, before handoff)

- **Spec coverage:** every numbered item in the design's Test plan section (1-11, after the cold-start addendum added item 11) has a corresponding test in Task 1, 2, 3, or 4 above. The design's "no new e2e_lifecycle.bats case" and "accepted coverage limit" notes are respected — no e2e test was added, and no test asserts the model-driven sentinel-parsing behavior itself (only the deterministic hook/doc pieces).
- **Placeholder scan:** no TBD/TODO; every code block above is the literal, complete text to write, not a description of it.
- **Type/name consistency:** `spec_next` (the decision string), `no_confirm`/`max_features`/`features_specced` (the `auto.json` keys), and `NO_REMAINING_SCOPE` (the sentinel) are spelled identically everywhere they appear across Tasks 1-4 — cross-checked against the design doc's final (post-review) wording.
- **Task boundary check:** Task 1 is the only one with real branching logic and is intentionally the largest — splitting the python/bash halves further would mean testing one half against the other's *absence*, which isn't meaningful here (the bats tests exercise the whole script via the `driver()` helper). Tasks 2-4 are independent, small, and reviewable in isolation from each other and from Task 1 (each only *references* the others' contracts by name, no code dependency).
