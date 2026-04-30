#!/usr/bin/env python3
import json, sys, os, glob

proj = os.getcwd()
features_dir = os.path.join(proj, 'features')

if not os.path.isdir(features_dir):
    print("No features/ directory found. Run /lean-spec:decompose-prd first.")
    sys.exit(1)

print("lean-spec:auto-all (Gemini degraded mode)")
print("No auto-driver available — SlashCommand dispatch not supported in Gemini CLI.")
print()
print("Non-closed features:")
print()

found = False
for wf_path in sorted(glob.glob(os.path.join(features_dir, '*/workflow.json'))):
    with open(wf_path) as f:
        data = json.load(f)
    phase = data.get('phase', '')
    slug = data.get('slug', '')
    if phase != 'closed':
        found = True
        print(f"  {slug}  (phase: {phase})")
        print(f"  → Run: /lean-spec:auto {slug}")
        print()

if not found:
    print("  All features are already closed.")
