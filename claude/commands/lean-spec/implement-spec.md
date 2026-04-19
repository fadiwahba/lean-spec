---
name: implement-spec
description: Run the implementation or apply-fixes phase for a lean-spec feature using the Coder agent.
---

Run the manual lean-spec implementation or apply-fixes phase for the feature slug in `$ARGUMENTS`.

Rules:
- Require a slug. If no slug is provided, ask for one.

**Step 1 — Determine the active phase by reading `review.md` first:**

Read `lean-spec/features/<slug>/review.md` before anything else.

- If `review.md` is empty or does not exist:
  **PHASE = initial-implementation** — implement the feature from `spec.md`.

- If `review.md` has a disposition of `review_clean` with no open findings:
  **PHASE = initial-implementation (re-entry)** — implement from `spec.md`.
  If the feature already appears fully implemented, report that and stop. Do not re-implement.

- If `review.md` contains open findings (issues, action items, or a non-`review_clean` disposition):
  **PHASE = apply-fixes** — address every open finding in `review.md`.
  Do not re-implement from scratch. Treat `spec.md` as reference context only.

**Step 2 — Execute the active phase:**

For initial-implementation:
- Read `spec.md` and `notes.md`.
- Use `Context7` when external APIs, libraries, or tool behavior matter.
- Use `sequential-thinking` when the work is multi-step, risky, or ambiguous.
- Implement all acceptance criteria from `spec.md`.
- Record blockers, deviations, and partial notes in `notes.md`.

For apply-fixes:
- Read `spec.md` and `notes.md` as reference only.
- Work through every open finding in `review.md` in order.
- For each finding: implement the fix, verify it is resolved.
- Use `sequential-thinking` when a fix is multi-step or has side-effects.
- Update `notes.md` with what was fixed, what was skipped, and why.
- Do not reopen or re-litigate findings already marked RESOLVED.

**Shared rules:**
- The Coder agent owns code implementation and `notes.md`.
- The default session must not edit implementation files directly, even for trivial fixes. Delegate to the Coder agent.
- Do not rewrite `spec.md` or `review.md`.
- Do not update `spec.md` status, checklist items, or timestamps.
- For frontend/UI work, use Playwright before reporting complete, unless explicitly unavailable.
- If Playwright is used, close any browser, context, or page before ending the phase.
- Do not save Playwright screenshots into the project root — use `lean-spec/features/<slug>/artifacts/` only.
- If a local dev server was started, stop it before ending the phase.
- If required verification cannot be completed, report incomplete and stop.
- Stop after the implementation or fixes pass. Do not auto-advance to review.

**Step 3 — Report:**
1. State the detected PHASE.
2. State implementation complete / partial / blocked.
3. List which findings were addressed (apply-fixes phase only).
4. State whether `Context7`, `sequential-thinking`, and Playwright were used or unavailable.
5. State whether `notes.md` was updated.
6. State the next manual phase (`/lean-spec:review-spec <slug>` when ready).
