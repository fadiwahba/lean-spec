---
slug: hello-world
phase: specifying
handoffs:
  next_command: /lean-spec:submit-implementation hello-world
  blocks_on: []
  consumed_by: [coder, reviewer]
---

# Spec: hello-world

## Scope

Add a `hello.sh` script to the project root that prints a greeting message with the current date. This is a smoke-test feature to demonstrate the lean-spec lifecycle end-to-end.

## Acceptance Criteria

1. `hello.sh` exists at the project root and is executable.
2. Running `./hello.sh` prints a line starting with "Hello from lean-spec!" followed by the current date in YYYY-MM-DD format.
3. `./hello.sh --name Alice` prints "Hello, Alice! Today is YYYY-MM-DD."

## Out of Scope

- Configuration files, .env support, or any persistent state.
- Colors, formatting, or terminal escape codes.

## Technical Notes

Use `date +%Y-%m-%d` for the date. No external dependencies — pure bash.
