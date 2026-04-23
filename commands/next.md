---
description: Resolve and surface the next lifecycle command for the most-recently-updated open feature
argument-hint: "[<slug>]"
allowed-tools: Bash, Read
---

# /lean-spec:next

Semi-auto driver (PRD §11 F9). Given the current workflow state, compute the next lifecycle command and surface it for the user to execute.

**This command does NOT auto-dispatch.** It resolves "what should I run now?" and presents it — you can then type the command (or paste it) to proceed. Auto-dispatch is out of scope for F9: the single-keystroke UX would require deeper Claude Code integration than the plugin surface exposes.

## Steps

1. Determine the target feature:
   - If `$ARGUMENTS` is provided, treat it as `<slug>` and validate `features/$ARGUMENTS/workflow.json` exists.
   - If empty, auto-select the **most-recently-updated non-closed feature** using the helper below.

```bash
# Source the helper
source "${CLAUDE_PLUGIN_ROOT}/lib/next-command.sh"

# Default to the active feature if no slug given
SLUG="${ARGUMENTS:-}"
if [ -z "$SLUG" ]; then
  ACTIVE=$(active_feature "features")
  if [ -z "$ACTIVE" ]; then
    echo "No in-progress features found. Run /lean-spec:start-spec <slug> to begin."
    exit 0
  fi
  WF="$ACTIVE"
  SLUG=$(jq -r '.slug' "$WF")
else
  WF="features/$SLUG/workflow.json"
  if [ ! -f "$WF" ]; then
    echo "Feature '$SLUG' not found. Run /lean-spec:spec-status to list features."
    exit 1
  fi
fi

PHASE=$(jq -r '.phase // "unknown"' "$WF")
UPDATED=$(jq -r '.updated_at // ""' "$WF")
NEXT=$(next_command_for "$WF")

echo "Feature: $SLUG"
echo "Phase:   $PHASE"
echo "Updated: $UPDATED"
echo ""

if [ -z "$NEXT" ]; then
  if [ "$PHASE" = "closed" ]; then
    echo "No next step — feature is closed. ✅"
  else
    echo "No next command resolvable. Run /lean-spec:spec-status $SLUG for details."
  fi
  exit 0
fi

echo "Next: $NEXT"
echo ""
echo "Copy-paste that command, or type it to advance."
```

2. Print the output. The `Next:` line is the contract — it must be an exact, copy-pasteable slash command (or a `# BLOCKED ...` comment if human intervention is required).

## Phase → command mapping

Same mapping as `/lean-spec:spec-status` (authoritative — see `lib/next-command.sh`):

| Current phase | Resolves to |
|---|---|
| `specifying` | `/lean-spec:submit-implementation <slug>` |
| `implementing` | `/lean-spec:submit-review <slug>` |
| `reviewing` + verdict `APPROVE` | `/lean-spec:close-spec <slug>` |
| `reviewing` + verdict `NEEDS_FIXES` | `/lean-spec:submit-fixes <slug>` |
| `reviewing` + verdict `BLOCKED` | `# BLOCKED` (no advance — human decision required) |
| `reviewing` + no review.md yet | `/lean-spec:spec-status <slug>` (awaiting reviewer output) |
| `closed` | (none) |

## Why not auto-dispatch?

Semi-auto in the PRD meant "agent proposes next command; hook intercepts and shows single-keystroke confirm UX." The Claude Code hook surface doesn't support TTY-prompt interception in a portable way today. So F9 lands as the pragmatic equivalent: the plugin always tells you what's next (here and in the `SessionStart` summary), and `/lean-spec:next` resolves to one line the user can execute.

If Claude Code later exposes a confirm-and-run primitive, upgrade this command to call it directly; the resolver logic in `lib/next-command.sh` is already factored out for reuse.
