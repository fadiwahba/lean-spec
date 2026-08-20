#!/usr/bin/env bats

load 'helpers.bash'

setup() {
  lean_spec_setup_repo
}

teardown() {
  lean_spec_teardown_repo
}

provider() {
  python3 - "$@" <<'PY'
import importlib.util
import json
from pathlib import Path
import sys

path = Path(sys.argv[1]) / 'adapters/providers.py'
spec = importlib.util.spec_from_file_location('providers', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
try:
    print(json.dumps(module.build_argv(*sys.argv[2:])))
except ValueError as error:
    print(error, file=sys.stderr)
    raise SystemExit(2)
PY
}

@test "Codex provider creates a structured headless argv with effort" {
  run provider "$LEAN_SPEC_REPO_ROOT" codex gpt-5.6-terra medium 'write the artifact'

  [ "$status" -eq 0 ]
  [ "$output" = '["codex", "exec", "--json", "--model", "gpt-5.6-terra", "-c", "model_reasoning_effort=medium", "write the artifact"]' ]
}

@test "provider routing rejects an unknown provider before dispatch" {
  run provider "$LEAN_SPEC_REPO_ROOT" unknown model '' prompt

  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown provider"* ]]
}

@test "provider routing rejects unsupported effort before dispatch" {
  run provider "$LEAN_SPEC_REPO_ROOT" gemini gemini-4.7-flash high prompt

  [ "$status" -eq 2 ]
  [[ "$output" == *"no documented headless effort flag"* ]]
}

@test "CLI loads explicit owner provider settings and prints argv without dispatching" {
  mkdir -p .lean-spec fake-bin
  cat > .lean-spec/rules.toml <<'EOF'
[agents]
implement = { provider = "codex", model = "gpt-5.6-terra", effort = "medium" }
EOF
  cat > fake-bin/codex <<'EOF'
#!/usr/bin/env bash
exit 99
EOF
  chmod +x fake-bin/codex

  run env PATH="$PWD/fake-bin:$PATH" "$LEAN_SPEC_BIN" provider argv implement --prompt 'write notes'

  [ "$status" -eq 0 ]
  [[ "$output" == *'"provider": "codex"'* ]]
  [[ "$output" == *'"model_reasoning_effort=medium"'* ]]
}

@test "provider run requires an explicit auth check before agent dispatch" {
  mkdir -p .lean-spec fake-bin
  cat > .lean-spec/rules.toml <<'EOF'
[agents]
implement = { provider = "codex", model = "gpt-5.6-terra", effort = "medium" }
EOF
  cat > fake-bin/codex <<'EOF'
#!/usr/bin/env bash
exit 99
EOF
  chmod +x fake-bin/codex

  run env PATH="$PWD/fake-bin:$PATH" "$LEAN_SPEC_BIN" provider run implement --prompt 'write notes'

  [ "$status" -eq 1 ]
  [[ "$output" == *"auth_check"* ]]
}

@test "provider run stops when the configured auth check fails" {
  mkdir -p .lean-spec fake-bin
  cat > .lean-spec/rules.toml <<'EOF'
[agents]
implement = { provider = "codex", model = "gpt-5.6-terra", effort = "medium", auth_check = ["false"] }
EOF
  cat > fake-bin/codex <<'EOF'
#!/usr/bin/env bash
exit 99
EOF
  chmod +x fake-bin/codex

  run env PATH="$PWD/fake-bin:$PATH" "$LEAN_SPEC_BIN" provider run implement --prompt 'write notes'

  [ "$status" -eq 1 ]
  [[ "$output" == *"authentication check failed"* ]]
}
