#!/usr/bin/env bats
# F9 — end-to-end lifecycle proof (PRD §11, M3).
#
# Drives one feature slug through the FULL lifecycle
# interview(simulated) -> spec -> implement -> review -> closed against the
# REAL bin/lean-spec CLI + the REAL hooks. No live model: the model-driven
# artifacts (docs/PRD.md, docs/CONSTITUTION.md, spec.md, notes.md,
# review.md) are simulated fixture content from
# tests/fixtures/demo-project/, written via the shared helpers in
# scripts/lib/demo-lifecycle.sh (also sourced by scripts/demo.sh — DRY,
# same content either way). This is a harness smoke test: it proves the
# deterministic spine (CLI transitions, hook gates, validation, verdict
# routing) works end-to-end with zero model dependency, not that any model
# produces good specs/code.
#
# Layer rule: this test never hand-writes workflow.json. Every phase
# transition goes through `bin/lean-spec ensure/advance`.

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
  source "${LEAN_SPEC_REPO_ROOT}/scripts/lib/demo-lifecycle.sh"
}

teardown() {
  lean_spec_teardown_repo
}

# Local hook wrappers, matching the pattern already used in
# tests/hooks_*.bats (echo payload | bash hook, inspect $status/$output).
guard() {
  echo "$1" | bash "${LEAN_SPEC_HOOKS}/pre-tool-use-guard.sh"
}

gate() {
  echo '{}' | bash "${LEAN_SPEC_HOOKS}/subagent-stop-gate.sh"
}

@test "e2e: full lifecycle interview(simulated) -> spec -> implement -> review -> closed" {
  # --- init + plan (simulated): scaffold config + docs, validate exactly
  # as /lean-spec:init and /lean-spec:plan would via the CLI ---
  demo_scaffold_project "${PWD}"
  lean_spec validate --project PRD.md
  [ "$status" -eq 0 ]
  lean_spec validate --project CONSTITUTION.md
  [ "$status" -eq 0 ]

  slug="$DEMO_SLUG"

  # --- spec: ensure creates workflow.json in `specifying` ---
  lean_spec ensure "$slug"
  [ "$status" -eq 0 ]
  lean_spec assert "$slug" specifying
  [ "$status" -eq 0 ]

  # architect (simulated) writes spec.md
  demo_write_spec "${PWD}" "$slug"
  lean_spec validate "$slug" spec.md
  [ "$status" -eq 0 ]

  # SubagentStop gate allows a valid spec.md (silent allow on the happy path)
  run gate
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  lean_spec advance "$slug" specifying implementing
  [ "$status" -eq 0 ]

  # --- implement: coder (simulated) writes notes.md w/ TDD evidence ---
  demo_write_notes "${PWD}" "$slug"
  lean_spec validate "$slug" notes.md
  [ "$status" -eq 0 ]

  run gate
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  lean_spec advance "$slug" implementing reviewing
  [ "$status" -eq 0 ]

  # --- review: reviewer (simulated) writes review.md, verdict APPROVE ---
  demo_write_review "${PWD}" "$slug" APPROVE
  lean_spec validate "$slug" review.md
  [ "$status" -eq 0 ]

  run gate
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  # next resolves to close, now that the verdict is APPROVE
  lean_spec next "$slug" --json
  [ "$status" -eq 0 ]
  next_output="$output"
  run python3 -c "
import json
d = json.loads('''$next_output''')
assert d['action'] == 'skill', d
assert d['skill'] == '/lean-spec:close', d
print('ok')
"
  [ "$output" = "ok" ]

  # --- close: the CLI gate really enforces APPROVE (not a formality — it
  # is the one and only close path; see the negative test below for the
  # rejection case) ---
  lean_spec advance "$slug" reviewing closed
  [ "$status" -eq 0 ]
  lean_spec assert "$slug" closed
  [ "$status" -eq 0 ]

  # final phase + history: 3 transitions, correct order
  lean_spec status "$slug" --json
  [ "$status" -eq 0 ]
  status_output="$output"
  run python3 -c "
import json
d = json.loads('''$status_output''')
assert d['phase'] == 'closed', d
assert d['history_len'] == 3, d
print('ok')
"
  [ "$output" = "ok" ]

  run python3 -c "
import json
h = json.load(open('features/${slug}/workflow.json'))['history']
assert [e['from'] for e in h] == ['specifying', 'implementing', 'reviewing'], h
assert [e['to'] for e in h] == ['implementing', 'reviewing', 'closed'], h
print('ok')
"
  [ "$output" = "ok" ]
}

@test "e2e negative: NEEDS_FIXES verdict blocks close and routes to fix; hand-edit of workflow.json is denied mid-flow" {
  demo_scaffold_project "${PWD}"
  slug="second-slice"

  lean_spec ensure "$slug"
  [ "$status" -eq 0 ]

  demo_write_spec "${PWD}" "$slug"
  lean_spec validate "$slug" spec.md
  [ "$status" -eq 0 ]
  lean_spec advance "$slug" specifying implementing
  [ "$status" -eq 0 ]

  # Pre-tool-use guard denies a hand-edit attempt mid-flow (the feature is
  # currently `implementing`) — the model must go through
  # `bin/lean-spec advance`, never Write/Edit the state file directly.
  run guard "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"features/${slug}/workflow.json\"}}"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
  # ...and the gate is real enforcement, not theater: the phase truly did
  # not move (nothing wrote through the denied edit).
  lean_spec assert "$slug" implementing
  [ "$status" -eq 0 ]

  demo_write_notes "${PWD}" "$slug"
  lean_spec validate "$slug" notes.md
  [ "$status" -eq 0 ]
  lean_spec advance "$slug" implementing reviewing
  [ "$status" -eq 0 ]

  demo_write_review "${PWD}" "$slug" NEEDS_FIXES
  lean_spec validate "$slug" review.md
  [ "$status" -eq 0 ]

  # close gate rejects a NEEDS_FIXES verdict outright
  lean_spec advance "$slug" reviewing closed
  [ "$status" -eq 2 ]
  [[ "$output" == *"NEEDS_FIXES"* ]]

  # phase is unchanged by the rejected advance
  lean_spec assert "$slug" reviewing
  [ "$status" -eq 0 ]

  # next routes to /lean-spec:fix, not /lean-spec:close
  lean_spec next "$slug" --json
  [ "$status" -eq 0 ]
  next_output="$output"
  run python3 -c "
import json
d = json.loads('''$next_output''')
assert d['action'] == 'skill', d
assert d['skill'] == '/lean-spec:fix', d
print('ok')
"
  [ "$output" = "ok" ]
}
