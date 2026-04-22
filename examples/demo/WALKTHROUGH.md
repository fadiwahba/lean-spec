# lean-spec v3 — Demo Walkthrough

**Time:** ~10 minutes  
**Goal:** Run a feature through the full spec → implement → review → close lifecycle.

## Prerequisites

- Claude Code installed
- This plugin loaded: `claude --plugin-dir /path/to/lean-spec`
- `jq` installed (`brew install jq` or `apt install jq`)

## Setup (1 minute)

Clone or navigate to this repo. Open Claude Code pointed at the demo project:
```
cd examples/demo
claude --plugin-dir ../..
```

## Step 1 — Check status (30 seconds)

Run `/lean-spec:spec-status` to see the pre-seeded `hello-world` feature in `specifying` phase.

> **Note on pre-seeding:** this walkthrough uses a pre-seeded `spec.md` to keep the demo under 10 minutes. In normal use you'd start with `/lean-spec:start-spec <slug> <brief>`, which dispatches the **architect subagent** (strong model) to author the spec. See PRD §4.2 for why all three roles — Architect, Coder, Reviewer — run as dispatched subagents with pinned model tiers.

## Step 2 — Review the spec (1 minute)

Run `/lean-spec:resume-spec hello-world` to load the feature context. Read `features/hello-world/spec.md`.

The spec has 3 acceptance criteria. This is what the coder will implement. If you want to try revisions, run `/lean-spec:update-spec hello-world` — the orchestrator will collect your feedback and re-dispatch the architect subagent.

## Step 3 — Submit for implementation (3 minutes)

Run `/lean-spec:submit-implementation hello-world`.

This advances the phase to `implementing` and dispatches the coder subagent. The coder reads `spec.md` and produces:
- Code changes (in this demo: `hello.sh`)
- `features/hello-world/notes.md`

Wait for the coder to finish. Verify: `cat features/hello-world/notes.md`

## Step 4 — Submit for review (3 minutes)

Run `/lean-spec:submit-review hello-world`.

This advances the phase to `reviewing` and dispatches the reviewer subagent. The reviewer runs two skills in sequence:
1. Spec compliance — checks each AC
2. Code quality — checks conventions and correctness

Wait for the reviewer to finish. Verify: `cat features/hello-world/review.md`

Expected verdict: `APPROVE` (unless the implementation has gaps).

## Step 5 — Close the spec (30 seconds)

Run `/lean-spec:close-spec hello-world`.

This sets the phase to `closed` and confirms the lifecycle is complete.

## Verify the full history

```bash
jq '.history' features/hello-world/workflow.json
```

Expected output: 4 history entries — specifying, implementing, reviewing, closed.

## Reference output

Pre-built reference artifacts are in `features/hello-world/` showing what the coder and reviewer outputs look like. These are snapshots — the actual walkthrough will produce fresh ones.

---

*This walkthrough exercises the M1 MVP: manual mode, Claude Code only. M2 adds semi-auto mode; M4 adds full auto.*
