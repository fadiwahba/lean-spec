#!/usr/bin/env python3
import json, sys, os

args = sys.argv[1] if len(sys.argv) > 1 else ''
parts = args.split(None, 1)
slug = parts[0] if parts else ''
brief = parts[1] if len(parts) > 1 else ''

if not slug:
    print("Usage: /lean-spec:update-spec <slug> [what to change]")
    sys.exit(1)

wf_path = f"features/{slug}/workflow.json"
if not os.path.exists(wf_path):
    print(f"Feature '{slug}' not found. Run /lean-spec:start-spec {slug} first.")
    sys.exit(1)

with open(wf_path) as f:
    data = json.load(f)

phase = data.get('phase', '')
if phase != 'specifying':
    print(f"/lean-spec:update-spec only works in 'specifying' phase. Current: '{phase}'.")
    print("(Once implementation has started, the spec is frozen. Close + re-open if you need a new direction.)")
    sys.exit(1)

spec_path = f"features/{slug}/spec.md"
print("Existing spec:")
print("---")
if os.path.exists(spec_path):
    with open(spec_path) as f:
        print(f.read(), end='')
else:
    print("(spec.md missing)")
print("---")
print()
print(f"Change request: {brief}")
