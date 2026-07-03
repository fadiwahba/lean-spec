# hello-cli — Constitution

> F9 fixture: simulated `/lean-spec:plan` output (see `docs/PRD.md` in this
> same fixture for context). How this toy project builds; what it builds
> lives in `docs/PRD.md`.

## Stack

Python 3 stdlib only (`sys.argv`, no `argparse` dependency required);
pytest for tests; no external dependencies.

## Principles

Fail loudly: unknown/missing arguments exit non-zero with a one-line
message. Stay small: one file, one function, one CLI entry point.

## Delegation

Architect writes `spec.md`; coder implements with TDD and writes
`notes.md`; reviewer writes `review.md` with a verdict. Same lean-spec
lifecycle as the parent project that generated this fixture.

## Quality Bars

All tests green before review. TDD evidence (RED + GREEN runs) required in
`notes.md`. Review requires `verdict: APPROVE` to close — no manual
override.

## Process

Commits: `type(scope): subject`, no emoji. One feature in flight at a time.

## Non-Goals

No web UI, no server, no database.
