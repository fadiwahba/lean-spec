#!/usr/bin/env python3
import json, sys, os, glob

proj = os.getcwd()
features_dir = os.path.join(proj, 'features')

if not os.path.isdir(features_dir):
    print("No features/ directory found. Run /lean-spec:decompose-prd first.")
    sys.exit(1)

slugs = []
for wf_path in sorted(glob.glob(os.path.join(features_dir, '*/workflow.json'))):
    with open(wf_path) as f:
        data = json.load(f)
    if data.get('phase') == 'specifying':
        slugs.append(data.get('slug', ''))

if not slugs:
    print("No features in specifying phase.")
    sys.exit(0)

print("Features to spec:")
for s in slugs:
    print(s)
print()
print("PRD contents:")
prd = os.path.join(proj, 'docs', 'PRD.md')
if os.path.exists(prd):
    with open(prd) as f:
        print(f.read(), end='')
else:
    print("(docs/PRD.md not found)")
