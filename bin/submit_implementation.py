#!/usr/bin/env python3
import json, sys, os, datetime

args = sys.argv[1] if len(sys.argv) > 1 else ''
slug = args.split()[0] if args.strip() else ''
if not slug:
    print("Usage: /lean-spec:submit-implementation <slug>")
    sys.exit(1)

wf_path = f"features/{slug}/workflow.json"
if not os.path.exists(wf_path):
    print(f"Feature '{slug}' not found. Run /lean-spec:start-spec {slug} first.")
    sys.exit(1)

with open(wf_path) as f:
    data = json.load(f)

current = data.get('phase', '')
if current != 'specifying':
    print(f"Phase gate: expected 'specifying', got '{current}'")
    sys.exit(1)

if not os.path.exists(f"features/{slug}/spec.md"):
    print(f"spec.md not found. Run /lean-spec:start-spec {slug} (or /lean-spec:update-spec {slug}) first.")
    sys.exit(1)

now = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
data['phase'] = 'implementing'
data['updated_at'] = now
data['history'].append({'phase': 'implementing', 'entered_at': now})

tmp = wf_path + '.tmp'
with open(tmp, 'w') as f:
    json.dump(data, f, indent=2)
os.replace(tmp, wf_path)

with open(wf_path) as f:
    check = json.load(f)
if check.get('phase') != 'implementing':
    print("ERROR: phase did not advance")
    sys.exit(1)
print("phase advanced: specifying → implementing")
