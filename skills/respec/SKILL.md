---
name: respec
description: Revises an existing .lean-spec/features/<slug>/spec.md in place (the --refine path named separately in the PRD's lifecycle diagram). Equivalent to /lean-spec:spec <slug> --refine.
disable-model-invocation: true
---

# /lean-spec:respec <slug>

The PRD's lifecycle diagram (§4.1) names the refine arrow `respec`
separately from `spec`; this skill is that named entry point. It is
identical in behavior to `/lean-spec:spec <slug> --refine` — see
`skills/spec/SKILL.md` for the full procedure (dispatch the architect
agent with the revision reason, validate via `bin/lean-spec validate
<slug> spec.md`, commit `spec(<slug>): refine — <reason>`).

Use this when a blocker discovered while implementing feeds back into a
spec revision *without* going through `/lean-spec:plan --refine` first
(the PRD/CONSTITUTION didn't need to change, just this one spec).

## Never does

Everything `skills/spec/SKILL.md`'s "Never does" list covers — this is the
same gate, not a separate one.
