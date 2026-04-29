# lean-spec — What's Next

Living document. Updated after each session. Captures open design questions, queued experiments, and pending implementation work. Not a design spec (that's `PRD.md`) and not a history log (that's `CHANGELOG.md`).

---

## Status snapshot — 2026-04-29

**Plugin version:** v0.3.6  
**Branch:** `lean-spec-v3` (unmerged to `main`)  
**All PRD milestones (M1–M4) complete.** One PRD item unfinished: F12 (marketplace publish).

---

## Open design decisions

### D1 — Auto driver: replace per-phase gates with 2-gate model

**Current:** `/lean-spec:auto` pauses at every phase boundary.  
**Agreed design:** Only 2 human gates:
- Gate 1: after Architect writes `spec.md` — human reads + approves before implementation begins
- Gate 2: after Reviewer issues `APPROVE` — human inspects output before close

Everything between Gate 1 and Gate 2 (implement → review → fix cycles) runs autonomously.

**Command surface:**
- `/lean-spec:auto auth-flow` — default, gates on
- `/lean-spec:auto --gates-off auth-flow` — fully autonomous (alias: `--unattended`)

**Status:** Not yet implemented. Current per-phase behaviour is the wrong default.

---

### D2 — rules.yaml: auto-generate by default

**Current:** Purely opt-in. New users never encounter it.  
**Agreed design:**
- `/lean-spec:decompose-prd` (or a new `/lean-spec:init`) auto-generates `.lean-spec/rules.yaml` from a sensible default template
- `--no-rules` flag on phase-advancing commands (`submit-implementation`, `submit-review`, `close-spec`) bypasses validation for that invocation

**Status:** Not yet implemented.

---

### D3 — Greenfield auto entry point

**Gap:** No command to start a full greenfield project in auto mode after decompose-prd.  
**Proposed:** `/lean-spec:auto-all` — drives every slug from the decomposed PRD sequentially, using the 2-gate model per feature.

**Status:** Not yet designed or implemented.

---

### D4 — Token/cost telemetry

**Current:** Telemetry logs phase transitions + wall-clock time only. No token or cost data.  
**Agreed design:**

**Tier 1 — File-size heuristics (native subagent mode):**
- Measure artifact sizes (spec.md, notes.md, review.md) after each phase
- Estimate tokens at ~4 chars/token, multiply by model price
- Store in `telemetry.jsonl` as `estimated_tokens` + `estimated_cost_usd`
- Flag as `"precision": "estimated"` in the record

**Tier 2 — Exact counts (subprocess mode):**
- `/lean-spec:auto --precise-cost` dispatches phases as `claude --output-format json` subprocesses
- Captures `input_tokens`, `output_tokens`, `cache_read_input_tokens` exactly
- Stores as `"precision": "exact"` in the record

**Report format target (`/lean-spec:telemetry`):**
```
Feature: auth-flow
Total wall time: 47m 12s
Phase breakdown:
  specifying    →  8m 30s   ~12K tokens  ~$0.18  (Opus)    [estimated]
  implementing  → 22m 45s   ~38K tokens  ~$0.04  (Haiku)   [estimated]
  reviewing     → 11m 20s   ~41K tokens  ~$0.61  (Opus)    [estimated]
Total estimated cost: ~$0.83
```
For non-Claude providers: show token estimates only, note cost unavailable.

**Status:** Not yet implemented.

---

### D5 — Subprocess vs native subagent architecture

**Question:** Should `/lean-spec:auto` drive phases via native `Task` subagent dispatch (current) or `claude` CLI subprocesses (gives exact token counts, enables cross-provider)?

**Agreed position:** Keep native dispatch as default (cache efficiency, simpler). Subprocess is the `--precise-cost` escape hatch. Cross-provider routing (`--coder-provider gemini`) is a v0.4 experiment after baseline data is collected.

**Status:** Decision made, not yet implemented for `--precise-cost` path.

---

## Pending implementation work

| # | Item | Priority | Notes |
|---|---|---|---|
| P1 | Auto driver 2-gate redesign (D1) | High | Core UX is currently wrong |
| P2 | Token/cost telemetry — Tier 1 heuristics (D4) | High | Adds real value to all users |
| P3 | rules.yaml auto-generation (D2) | Medium | Discoverability fix |
| P4 | F12 — Marketplace publish | Medium | `lean-spec-marketplace` repo + install docs + plugin registry PR |
| P5 | PR lean-spec-v3 → main | Medium | Branch has never been merged |
| P6 | Token/cost telemetry — Tier 2 subprocess (D4) | Low | Only useful with `--precise-cost` flag |
| P7 | `/lean-spec:auto-all` greenfield entry point (D3) | Low | Needs D1 done first |
| P8 | Cross-provider live test | Low | Real Gemini CLI run picking up Claude-written spec |

---

## Experiments completed

| Experiment | Result | Key findings |
|---|---|---|
| Kanban board v1 (Express, vanilla JS) | Complete | Baseline cost data, workflow validated end-to-end |
| Kanban board v2 (Next.js 16 + shadcn) | Complete | 3 bugs surfaced by reviewer (chokidar v5 glob no-op, SSE flush timing, stream cleanup scope) |
| CLI hallucination audit (update-spec, submit-fixes) | No hallucination | Only `start-spec` and `close-spec` trigger it; pattern: command name matches training-data CLI |
| Cost capture via subprocess (`lsk-run.sh`) | Partial | Background tasks lose cost; write-to-file-first pattern required; Opus dominates at 64% |

## Experiments queued

| Experiment | Goal |
|---|---|
| Cross-provider live run (Gemini writes spec, Claude implements) | Validate real artifact hand-off across terminals |
| Subprocess dispatch with `--precise-cost` | Validate exact token capture; measure cold-start overhead |
| Multi-feature `/lean-spec:auto-all` | Validate sequential feature driving from one command |

---

## Known footguns (not yet in coder.md or spec templates)

- **Telemetry marker must contain "on"** — an empty `~/.lean-spec/telemetry` file does NOT enable telemetry. `echo "on" > ~/.lean-spec/telemetry`. Worth surfacing in install docs.
- **chokidar v5 glob no-op** — documented in `agents/coder.md` as of v0.3.6.
- **SSE initial frame required** — Next.js does not flush response head until first `enqueue()`. Must send `: connected\n\n` immediately in `start()` or `EventSource` stays in `CONNECTING` indefinitely.
