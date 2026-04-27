# M2 Greenfield v2 — Cloud Agent Runbook

**Purpose:** Run the M2 semi-auto greenfield experiment on the remaining 3 features
(stats-bar, group-completed-toggle, task-list) using lean-spec v0.3.1 patches that
fix the critical headless-driver bugs from the v1 run. Drive headlessly (act as the
human gatekeeper), capture all dispatches, and write a REPORT.md comparing v1 vs v2.

**Lean-spec repo:** `https://github.com/fadiwahba/lean-spec` (branch: `lean-spec-v3`)
**Todo-demo repo:** `https://github.com/fadiwahba/todo-demo` (branch: `experiment-m2-greenfield`)

---

## Step 0 — Environment bootstrap

```bash
# Working directory
WORKDIR="$HOME/cloud-experiment"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Clone lean-spec v0.3.1
git clone --branch lean-spec-v3 https://github.com/fadiwahba/lean-spec.git lean-spec
LEAN_SPEC_DIR="$WORKDIR/lean-spec"

# Clone todo-demo on the experiment-m2-greenfield branch (has 2 closed features + 3 skeletons)
git clone --branch experiment-m2-greenfield https://github.com/fadiwahba/todo-demo.git todo-demo
TODO_DIR="$WORKDIR/todo-demo"

# Create v2 experiment branch
cd "$TODO_DIR"
git checkout -b experiment-m2-greenfield-v2

# Ensure uv is available (needed for portable PyYAML in rules.sh)
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.cargo/bin:$PATH"  # uv installs here
fi

# Verify uv is working
uv --version || pip install uv

# Install Node deps
cd "$TODO_DIR"
npm install 2>&1 | tail -5
```

---

## Step 1 — Fix the known page.tsx regression before any new work

The v1 add-task-input cycle-2 fix removed page-header content from page.tsx. Before
driving new features, restore the page-header content so the baseline is clean.

Check `app/page.tsx` — if the title "Tasks" and subtitle are missing, restore them
to match the closed `features/page-header/spec.md` Visual ACs (V1–V8). The content
should be rendered by `app/components/PageHeader.tsx` which was shipped by page-header.

Commit the fix if any: `git commit -m "fix: restore page-header regression from v1 experiment"`

---

## Step 2 — Verify environment + dev server

```bash
cd "$TODO_DIR"
# Start dev server in background
PORT=3456 npm run dev &
DEV_PID=$!
sleep 8  # wait for server to be ready

# Quick smoke test
curl -s http://localhost:3456 | grep -q "Tasks" && echo "DEV SERVER OK" || echo "DEV SERVER PROBLEM"
```

---

## Step 3 — Drive remaining 3 features

For EACH of the 3 skeleton features (`stats-bar`, `group-completed-toggle`, `task-list`)
in the order listed, run the full lifecycle:

### 3a — fill-spec (replaces update-spec with inline brief)

The skeleton features already have `features/<slug>/workflow.json` (phase=specifying)
and `features/<slug>/spec.md` (skeleton). Run:

```bash
DISPATCH_DIR="$TODO_DIR/experiments/m2-greenfield-v2/dispatches"
mkdir -p "$DISPATCH_DIR"

# For each slug in: stats-bar group-completed-toggle task-list
SLUG="stats-bar"  # repeat for each

# Inline brief derived from the skeleton's PRD reference + spec.md context
BRIEF="Fill out the skeleton spec for $SLUG based on docs/PRD.md §4.X. 
The binding visual contract is docs/ux-design.jpg. Port 3456. 
Apply the same Visual ACs pattern as features/page-header/spec.md (V1–V8 numbered table)."

DISPATCH_N="01-update-spec-$SLUG"
claude \
  --plugin-dir "$LEAN_SPEC_DIR" \
  --print "/lean-spec:update-spec $SLUG $BRIEF" \
  --output-format json \
  --dangerously-skip-permissions \
  > "$DISPATCH_DIR/$DISPATCH_N.json" 2>&1
```

### 3b — submit-implementation

```bash
DISPATCH_N="02-submit-impl-$SLUG"
claude \
  --plugin-dir "$LEAN_SPEC_DIR" \
  --print "/lean-spec:submit-implementation $SLUG" \
  --output-format json \
  --dangerously-skip-permissions \
  > "$DISPATCH_DIR/$DISPATCH_N.json" 2>&1
```

### 3c — submit-review

```bash
DISPATCH_N="03-submit-review-$SLUG"
claude \
  --plugin-dir "$LEAN_SPEC_DIR" \
  --print "/lean-spec:submit-review $SLUG" \
  --output-format json \
  --dangerously-skip-permissions \
  > "$DISPATCH_DIR/$DISPATCH_N.json" 2>&1
```

### 3d — Evaluate verdict

Parse the dispatch JSON:
```bash
VERDICT=$(jq -r '.result' "$DISPATCH_DIR/$DISPATCH_N.json" | grep -oE 'APPROVE|NEEDS_FIXES' | head -1)
echo "Verdict for $SLUG: $VERDICT"
```

- If `APPROVE`: proceed to close-spec (3e)
- If `NEEDS_FIXES`: run submit-fixes then submit-review again (max 3 cycles)

### 3e — close-spec (on APPROVE)

```bash
DISPATCH_N="04-close-spec-$SLUG"
claude \
  --plugin-dir "$LEAN_SPEC_DIR" \
  --print "/lean-spec:close-spec $SLUG" \
  --output-format json \
  --dangerously-skip-permissions \
  > "$DISPATCH_DIR/$DISPATCH_N.json" 2>&1
```

**KEY v0.3.1 validation point:** close-spec should now run the bash directly without
hallucinating CLI dependencies. If it fails, capture the error and note in the report.

Also check stderr of each dispatch for `lean-spec block:` messages (new in v0.3.1):
```bash
jq -r '.stderr // ""' "$DISPATCH_DIR/$DISPATCH_N.json" | grep "lean-spec block" || echo "no blocks"
```

---

## Step 4 — Generate experiment report

```bash
cd "$TODO_DIR"
"$LEAN_SPEC_DIR/scripts/experiment-report.sh" \
  "'$DISPATCH_DIR/*.json'" \
  > "experiments/m2-greenfield-v2/dispatches/summary.txt" 2>&1

cat "experiments/m2-greenfield-v2/dispatches/summary.txt"
```

---

## Step 5 — Write REPORT.md

Write `experiments/m2-greenfield-v2/REPORT.md` comparing v1 vs v2:

- Did update-spec with inline brief succeed WITHOUT the "ask user" trap? (v0.3.1 patch #1)
- Did close-spec run the bash WITHOUT CLI hallucination? (v0.3.1 patch #2)
- Were block reasons visible in stderr on any blocked dispatch? (v0.3.1 patch #3)
- Did uv handle PyYAML without manual pip install? (v0.3.1 patch #4)
- Cost per feature in v2 vs v1 ($4.50 avg in v1)
- Driver intervention required (v1 was HIGH; target is LOW for v2)

Use this table as the template:

```markdown
## v1 vs v2 comparison

| Metric | v1 ($11.15, 2 features) | v2 (this run) |
|---|---|---|
| update-spec headless bug | ❌ BLOCKS NEEDED | ✅ / ❌ |
| close-spec CLI hallucination | ❌ BLOCKS NEEDED | ✅ / ❌ |
| stderr block visibility | ❌ silent | ✅ / ❌ |
| uv PyYAML portability | ❌ env-specific | ✅ / ❌ |
| Cost per shipped feature | ~$4.50 | $X.XX |
| Driver intervention | HIGH | LOW / MED / HIGH |
| Features driven | 2/5 | X/5 |
```

---

## Step 6 — Commit and push

```bash
cd "$TODO_DIR"
git add -A
git commit -m "experiment-m2-greenfield-v2: complete run — lean-spec v0.3.1 patches validated"
git push origin experiment-m2-greenfield-v2
```

---

## Known issues / gotchas

1. **Page.tsx regression**: fix before starting Step 3 (see Step 1).
2. **Dev server must be running** for the reviewer's Playwright checks. Keep it alive across all features.
3. **rules.yaml enforcement is already configured** in `.lean-spec/rules.yaml` from v1. Do NOT change it — the tight rules are deliberate for maximum enforcement signal.
4. **Port is 3456** — all references in ACs, notes, review must use 3456, never 3000.
5. **Slug order matters for the reviewer's regression check**: drive stats-bar first, then group-completed-toggle, then task-list (simpler → more complex per PRD §4).
6. **If any dispatch is blocked by rules.yaml** (exit code 2, empty result): decode the block reason from stderr (`jq -r '.stderr'`), fix the artifact manually, and re-dispatch. This is the expected headless flow — the v0.3.1 patch makes the reason visible.
7. **If uv is unavailable and PyYAML is missing**: `pip3 install pyyaml` as fallback, then retry.
8. **Playwright MCP**: the reviewer agent uses Playwright to verify the UI. If MCP is unavailable in the cloud environment, the reviewer will note it and do a code-only review instead.
