# lean-spec — resume-spec (Codex)

Re-primes your Codex context for an in-progress feature by dumping its artifacts.

## Inputs

- **Slug**: <kebab-case-feature-name>

## Steps

```bash
SLUG="<paste slug>"
PROJ="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
WF="$PROJ/features/$SLUG/workflow.json"
[ -f "$WF" ] || { echo "Feature '$SLUG' not found"; exit 1; }

echo "=== workflow.json ==="
jq . "$WF"
for f in spec.md notes.md review.md; do
  [ -f "$PROJ/features/$SLUG/$f" ] && { echo ""; echo "=== $f ==="; cat "$PROJ/features/$SLUG/$f"; }
done
```

After reading the dump, summarize for the user:
- Current phase
- One-sentence state ("spec drafted, waiting for submit-implementation" / "review cycle 2 flagged 3 Important findings" / etc.)
- The exact prompt to paste next (see `next.md`)
