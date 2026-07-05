#!/usr/bin/env bash
# Stop hook: the shipped `/lean-spec:auto` driver (PRD R4). While
# .lean-spec/auto.json is present and the feature isn't closed/BLOCKED/capped,
# block the turn-end with a reason instructing the model to run
# `bin/lean-spec next <slug>` (and dispatch the resulting skill). Cycle count
# is mutated atomically (tmp + os.replace), matching the CLI's own state
# discipline even though this file lives outside features/*/workflow.json.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LEAN_SPEC="${PLUGIN_ROOT}/bin/lean-spec"

# Drain stdin; stop_hook_active is deliberately NOT an exit condition here.
# It is true on every stop after the first hook-driven continuation, so
# exiting on it would cap auto mode at one cycle per user prompt. PRD R4:
# block turn-end until closed/BLOCKED/cap — the max_cycles cap (incremented
# below on every block) is the runaway guard.
cat >/dev/null || true
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AUTO_PATH="${PROJECT_ROOT}/.lean-spec/auto.json"

if [ ! -f "$AUTO_PATH" ]; then
  exit 0
fi

slug="$(python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        print(json.load(f).get("slug", ""))
except (OSError, json.JSONDecodeError):
    print("")
' "$AUTO_PATH")"

if [ -z "$slug" ]; then
  rm -f "$AUTO_PATH"
  exit 0
fi

set +e
next_json="$(cd "$PROJECT_ROOT" && "$LEAN_SPEC" next "$slug" --json 2>/dev/null)"
set -e

action="$(printf '%s' "$next_json" | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("action",""))
except Exception:
    print("")
' 2>/dev/null || true)"

# Read/update cycle bookkeeping atomically. `chain_all` (set by
# /lean-spec:auto-all) makes a "closed" outcome pick the next non-closed
# feature and keep driving, instead of stopping — per PRD R9 / "auto-all
# drains every non-closed feature, one auto.json at a time". A BLOCKED
# verdict or the cycle cap always stops the whole chain (CONSTITUTION:
# "BLOCKED verdicts stop the line and escalate").
decision="$(python3 - "$AUTO_PATH" "$action" "$PROJECT_ROOT" <<'PYEOF'
import json
import os
import sys
import tempfile

auto_path, action, project_root = sys.argv[1], sys.argv[2], sys.argv[3]


def atomic_write(path, data):
    d = os.path.dirname(path)
    fd, tmp_path = tempfile.mkstemp(prefix=".autoXXXXXX", dir=d)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp_path, path)


def next_non_closed_slug(root):
    features_root = os.path.join(root, "features")
    if not os.path.isdir(features_root):
        return None
    for name in sorted(os.listdir(features_root)):
        wf_path = os.path.join(features_root, name, "workflow.json")
        if not os.path.isfile(wf_path):
            continue
        try:
            with open(wf_path) as f:
                phase = json.load(f).get("phase")
        except (OSError, json.JSONDecodeError):
            continue
        if phase != "closed":
            return name
    return None


try:
    with open(auto_path) as f:
        auto = json.load(f)
except (OSError, json.JSONDecodeError):
    print("stop")
    sys.exit(0)

def coerce_int(value, default):
    """Coerce a cleanly-numeric value (int, float, or numeric string) to
    int; anything nonsensical (None, "abc", non-numeric types) returns
    None so the caller can disarm instead of crashing on comparison."""
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        try:
            return int(value.strip())
        except ValueError:
            return None
    return None


max_cycles = coerce_int(auto.get("max_cycles", 20), 20)
cycles = coerce_int(auto.get("cycles", 0), 0)

if max_cycles is None or cycles is None:
    # Corrupted/hand-edited auto.json with non-numeric cycle bookkeeping —
    # the driver can never safely compare cycles >= max_cycles, so disarm
    # instead of raising (fail loudly, do not crash the Stop hook).
    # NOTE: keep comments in this $()-embedded heredoc free of the
    # single-quote character; bash 3.2 (macOS /bin/bash) mis-parses one
    # inside a $(...) body and dies with an EOF-looking-for-quote error.
    try:
        os.remove(auto_path)
    except OSError:
        pass
    print("disarm")
    sys.exit(0)

if action not in ("skill", "blocked", "closed"):
    # `lean-spec next` failed or returned garbage — the driver can never
    # resolve a step, so disarm instead of burning cycles (fail loudly).
    try:
        os.remove(auto_path)
    except OSError:
        pass
    print("disarm")
    sys.exit(0)

if action == "blocked" or cycles >= max_cycles:
    try:
        os.remove(auto_path)
    except OSError:
        pass
    print("stop")
    sys.exit(0)

if action == "closed":
    if auto.get("chain_all"):
        nxt = next_non_closed_slug(project_root)
        if nxt is not None:
            auto["slug"] = nxt
            auto["cycles"] = 0
            atomic_write(auto_path, auto)
            print(f"chained:{nxt}")
            sys.exit(0)
        if auto.get("no_confirm"):
            max_features = coerce_int(auto.get("max_features", 20), 20)
            features_specced = coerce_int(auto.get("features_specced", 0), 0)
            if (
                max_features is not None
                and features_specced is not None
                and features_specced < max_features
            ):
                auto["features_specced"] = features_specced + 1
                atomic_write(auto_path, auto)
                print("spec_next")
                sys.exit(0)
    try:
        os.remove(auto_path)
    except OSError:
        pass
    print("stop")
    sys.exit(0)

auto["cycles"] = cycles + 1
atomic_write(auto_path, auto)
print("continue")
PYEOF
)"

if [ "$decision" = "stop" ]; then
  exit 0
fi

if [ "$decision" = "disarm" ]; then
  echo "lean-spec auto: could not resolve next step for '${slug}' — auto mode disarmed" >&2
  exit 0
fi

if [ "$decision" = "spec_next" ]; then
  reason="lean-spec auto-all: no non-closed feature remains and --no-confirm is set — read ${PLUGIN_ROOT}/skills/spec/SKILL.md now and follow its no-arg Steps yourself with --no-confirm (skip the AskUserQuestion) to propose and write the next slice. The propose dispatch returns either '<slug>: <one-line scope>' or the literal sentinel NO_REMAINING_SCOPE — treat ANY other or malformed response the same as the sentinel (fail-safe: stop, do not retry or guess). If it is the sentinel (or unparseable): delete .lean-spec/auto.json and stop — the PRD is fully covered. Otherwise: ensure the new slug and dispatch the architect to write spec.md exactly as /lean-spec:spec normally would. Do not touch .lean-spec/auto.json yourself — the driver picks up the new feature (and resets its cycle count to 0) automatically via the existing next-non-closed-feature rescan on your next turn-end."
  python3 -c 'import json, sys; print(json.dumps({"decision": "block", "reason": sys.argv[1]}, ensure_ascii=False))' "$reason"
  exit 0
fi

case "$decision" in
  chained:*)
    slug="${decision#chained:}"
    set +e
    next_json="$(cd "$PROJECT_ROOT" && "$LEAN_SPEC" next "$slug" --json 2>/dev/null)"
    set -e
    # Re-check the chained-to feature. auto.json was already repointed to it
    # by the Python block, but "next non-closed" is not the same as
    # "actionable": only a "skill" action drives. A blocked (or unresolved)
    # chained feature stops the whole chain and disarms auto mode — per the
    # CONSTITUTION ("BLOCKED verdicts stop the line and escalate") — rather
    # than emitting a block round that points at a step which cannot run.
    chained_action="$(printf '%s' "$next_json" | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("action",""))
except Exception:
    print("")
' 2>/dev/null || true)"
    if [ "$chained_action" != "skill" ]; then
      rm -f "$AUTO_PATH"
      echo "lean-spec auto: chained feature '${slug}' is not actionable (${chained_action:-unresolved}) — auto mode stopped, escalate" >&2
      exit 0
    fi
    ;;
esac

# The named skill (e.g. /lean-spec:implement) has disable-model-invocation:
# true (scaffold_skills_agents.bats enforces this for every mutating skill),
# so the model has no Skill-tool path to "run" it — that phrasing was a
# dead end the driving model had to discover by trial and error. Point it
# at the actual SKILL.md instead: read it fresh and perform its Steps by
# hand, rather than improvising from memory of a prior cycle (the real
# source of auto-mode drift).
reason="$(printf '%s' "$next_json" | python3 -c '
import json, sys
try:
    r = json.load(sys.stdin)
except Exception:
    r = {}
skill = r.get("skill")
slug = r.get("slug", "")
plugin_root = sys.argv[1]
if skill:
    name = skill.rsplit(":", 1)[-1]
    print(
        f"lean-spec auto: {skill} is model-invocation-disabled -- read "
        f"{plugin_root}/skills/{name}/SKILL.md now (not from memory) and "
        f"perform its Steps yourself for \x27{slug}\x27 to continue the lifecycle."
    )
else:
    # Defensive: the driver now only reaches this printer for an actionable
    # ("skill") feature, so skill is normally set. This fallback keeps the
    # hook from emitting a broken reason if next-resolution ever regresses.
    print(f"lean-spec auto: run `bin/lean-spec next {slug}` to determine the next step.")
' "$PLUGIN_ROOT")"

python3 -c 'import json, sys; print(json.dumps({"decision": "block", "reason": sys.argv[1]}, ensure_ascii=False))' "$reason"

exit 0
