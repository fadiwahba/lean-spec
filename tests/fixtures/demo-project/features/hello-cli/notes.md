# Notes: hello-cli

## What was built

`hello.py` implementing `greet(name)` (AC1) and a `__main__` CLI entry
(AC2, AC3): prints the greeting when a name is given, exits 1 with a
usage message on stderr when it is not.

## How to verify

Run `python3 -m pytest tests/test_hello.py -v`, then `python3 hello.py
Ada` (expect `Hello, Ada!`) and `python3 hello.py` (expect a non-zero exit
and a usage message on stderr).

## TDD

### RED

```
tests/test_hello.py::test_greet_returns_greeting FAILED
tests/test_hello.py::test_cli_prints_greeting FAILED
tests/test_hello.py::test_cli_missing_name_exits_nonzero FAILED
3 failed in 0.02s
```

### GREEN

```
tests/test_hello.py::test_greet_returns_greeting PASSED
tests/test_hello.py::test_cli_prints_greeting PASSED
tests/test_hello.py::test_cli_missing_name_exits_nonzero PASSED
3 passed in 0.03s
```
