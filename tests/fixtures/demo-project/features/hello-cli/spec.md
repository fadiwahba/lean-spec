# Spec: hello-cli

## Scope

Implement `hello.py`: a `greet(name: str) -> str` function returning
`"Hello, {name}!"`, plus a `__main__` CLI entry that prints the greeting
for `sys.argv[1]`.

## Acceptance Criteria

1. `greet("World")` returns exactly `"Hello, World!"`.
2. Running `python3 hello.py Ada` prints `Hello, Ada!` followed by a
   newline to stdout.
3. Running `python3 hello.py` with no name argument exits non-zero with a
   one-line usage message on stderr.

## Out of Scope

No internationalization, no config file, no packaging.

## Coder Guardrails

Single file `hello.py`, stdlib only, no third-party dependencies. Do not
touch `spec.md`, `review.md`, or `workflow.json`.
