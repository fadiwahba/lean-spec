#!/usr/bin/env python3
import json, sys, os

home = os.path.expanduser('~')
lean_home = os.path.join(home, '.lean-spec')
tfile = os.path.join(lean_home, 'telemetry.jsonl')
marker = os.path.join(lean_home, 'telemetry')

if not os.path.exists(marker) and os.environ.get('LEAN_SPEC_TELEMETRY', '0') != '1':
    print("Telemetry is disabled.")
    print()
    print("Enable (persistent):  mkdir -p ~/.lean-spec && echo on > ~/.lean-spec/telemetry")
    print("Enable (session):     export LEAN_SPEC_TELEMETRY=1")
    print()
    print("Gemini CLI note: the Stop hook is unavailable, so records are written by")
    print("each host command at phase-advance time rather than on session end.")
    sys.exit(0)

if not os.path.exists(tfile):
    print("No telemetry data yet (log is empty).")
    sys.exit(0)

args_str = (sys.argv[1] if len(sys.argv) > 1 else '').strip()
parts = args_str.split()
slug_filter = ''
project_filter = ''
i = 0
while i < len(parts):
    if parts[i] == '--project' and i + 1 < len(parts):
        project_filter = parts[i + 1]
        i += 2
    elif not parts[i].startswith('--'):
        slug_filter = parts[i]
        i += 1
    else:
        i += 1

rows = []
with open(tfile) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if slug_filter and rec.get('slug') != slug_filter:
            continue
        if project_filter and rec.get('project', '') != project_filter:
            continue
        slug = rec.get('slug', '')
        prev = rec.get('prev_phase') or ''
        phase = rec.get('phase', '')
        elapsed = rec.get('elapsed_prev_ms')
        elapsed_str = f"{elapsed}ms" if elapsed is not None else "?ms"
        transition = f"{prev} to {phase}" if prev and phase else phase
        project = rec.get('project') or '-'
        rows.append((slug, transition, elapsed_str, project))

if not rows:
    print("No telemetry records found.")
    sys.exit(0)

col1 = max(len(r[0]) for r in rows)
col2 = max(len(r[1]) for r in rows)
col3 = max(len(r[2]) for r in rows)
for r in rows:
    print(f"{r[0]:<{col1}}  {r[1]:<{col2}}  {r[2]:<{col3}}  {r[3]}")
