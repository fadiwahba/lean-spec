---
name: reviewing-performance
description: Optional review skill — invoke when /lean-spec:submit-review is called with `performance` in $ARGUMENTS. Audits the diff for render hot-paths, N+1 patterns, bundle bloat, and obvious algorithmic regressions.
---

## When to Invoke

Invoke ONLY when the Reviewer subagent receives `performance` in its dispatch payload's extras list. Owned by the Reviewer subagent during the `reviewing` phase. Never invoked by default — performance review is opt-in via:

```
/lean-spec:submit-review <slug> performance
```

## What to Audit

Scope is the **diff under review**. Don't propose performance findings for code the spec didn't touch unless it directly amplifies a diff-introduced issue.

### Render performance (frontend)

- **Avoidable re-renders**: state lifted higher than necessary; props that change identity each render (`{}`, `[]`, inline functions) into memoised children.
- **Missing key props** on dynamic lists, or non-stable keys (`index`, random uuid generated per-render).
- **Heavy work in render**: synchronous JSON parse, sort, filter on large arrays inside the function body — should be `useMemo` or moved outside.
- **Effect storms**: `useEffect` with object/array deps that change identity each render → infinite loops or wasted renders.
- **Layout thrashing**: read-then-write DOM in tight loops; `getBoundingClientRect` inside scroll handlers without `requestAnimationFrame`.

### Network & data fetching

- **N+1 patterns**: `for (item of list) { await fetch(item.id) }` — should be batched / parallel.
- **Waterfalls**: sequential `await` chains where parallel `Promise.all` is correct.
- **Over-fetching**: requesting full resources when a projection / GraphQL fragment / index column would suffice.
- **Missing cache**: same data fetched on every navigation when stale-while-revalidate or ISR would apply.

### Bundle / cold-start

- **Newly-imported heavy dependencies** in the diff (moment, lodash full, three.js, etc.) when a smaller alternative or tree-shake is available. Note the size impact roughly.
- **Synchronous import of code that should be `next/dynamic` / `lazy`** (modals, charts, editors not on the critical path).
- **Server-only code accidentally bundled to client** (large libraries, secrets-adjacent helpers) — flag but defer to actual bundle inspection if uncertain.

### Algorithmic

- **O(n²) where O(n) trivially possible** — nested loops over the same collection, repeated `Array.includes` in a hot path (use `Set`).
- **Repeated work**: same expensive computation per render or per request when caching is straightforward.

### Server / API

- **Database round-trips per loop iteration** — should be a single query with `IN` clause or a join.
- **Missing indexes** when the diff adds a query on a non-indexed column. Note the column; defer the actual `CREATE INDEX` to the user's migration workflow.
- **Synchronous I/O on the request path** when async would unblock the event loop.

## What to Skip

- Micro-optimisations under measurement noise (sub-millisecond differences)
- Rewrites of code outside the diff for "consistency"
- Anything requiring a real profiler / load test — this is a static audit
- "We could use Rust here" — out of scope

## Output

Append findings to `review.md` under a `## Performance Review` heading. Group by severity:

```markdown
## Performance Review

### Critical
- `path/to/file.ts:LINE` — Issue. Quantified impact (e.g. "renders 3× per keystroke"). Specific fix.

### Important
- ...

### Minor
- ...

### Notes
- Bundle delta estimate: <added/removed dependencies and rough kB impact, if computable from diff>
- N/A items: <categories audited but clean, e.g. "no list rendering in diff", "no DB layer touched">
```

If zero findings: `**No performance findings.**` Heading mandatory.

## Verdict contribution

- Critical → contributes to `NEEDS_FIXES`. Block on user-visible regressions (perceptible jank, broken pagination, etc.).
- Important → `NEEDS_FIXES` if combined with other lenses' findings.
- Minor / Notes → informational only.
