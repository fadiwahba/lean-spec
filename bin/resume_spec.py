#!/usr/bin/env python3
import json, sys, os

slug = (sys.argv[1] if len(sys.argv) > 1 else '').strip()
if not slug:
    print("Usage: /lean-spec:resume-spec <slug>")
    sys.exit(1)

proj = os.getcwd()
wf_path = os.path.join(proj, 'features', slug, 'workflow.json')
if not os.path.exists(wf_path):
    print(f"Feature '{slug}' not found. /lean-spec:spec-status for available features.")
    sys.exit(1)

print("=== workflow.json ===")
with open(wf_path) as f:
    data = json.load(f)
print(json.dumps(data, indent=2))

for fname in ('spec.md', 'notes.md', 'review.md'):
    fpath = os.path.join(proj, 'features', slug, fname)
    if os.path.exists(fpath):
        print()
        print(f"=== {fname} ===")
        with open(fpath) as f:
            print(f.read(), end='')
