#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
  lean_spec ensure demo
  lean_spec ensure second
}

teardown() {
  lean_spec_teardown_repo
}

@test "next --all --json emits a JSON array covering every feature" {
  lean_spec next --all --json
  [ "$status" -eq 0 ]
  run python3 -c "
import json
d = json.loads('''$output''')
slugs = sorted(x['slug'] for x in d)
assert slugs == ['demo', 'second'], slugs
print('ok')
"
  [ "$output" = "ok" ]
}

@test "status --json (no slug) emits a JSON array covering every feature" {
  lean_spec advance second specifying implementing
  lean_spec status --json
  [ "$status" -eq 0 ]
  run python3 -c "
import json
d = json.loads('''$output''')
by_slug = {x['slug']: x['phase'] for x in d}
assert by_slug == {'demo': 'specifying', 'second': 'implementing'}, by_slug
print('ok')
"
  [ "$output" = "ok" ]
}
