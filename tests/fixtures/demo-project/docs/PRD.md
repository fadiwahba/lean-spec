# hello-cli — Product Requirements Document

> F9 fixture: this is the "interview output" for the demo target project
> used by `scripts/demo.sh` and `tests/test_integration.py`. It is
> hand-written here to simulate what `/lean-spec:plan`'s interview would
> produce — no live model is involved in the e2e proof (PRD §11 F9).

## Problem & Users

Onboarding scripts need a fast, scriptable way to print a personalized
greeting banner from the command line. Users are internal support
engineers writing shell-based onboarding tooling who need a single,
dependable command they can drop into a script.

## Features

- `hello-cli`: a single-file Python CLI that prints `Hello, <name>!` for a
  given name, and fails loudly with no name given.

## Constraints

Python 3 stdlib only, single file, no third-party dependencies, no network
access.

## Quality Bar

TDD mandatory (RED then GREEN); all tests pass before review; no silent
failures — missing/invalid input exits non-zero with a one-line message.

## Non-Goals

No internationalization, no config file, no interactive prompt, no
packaging/distribution.
