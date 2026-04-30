#!/usr/bin/env python3
import json, sys, os

slug = (sys.argv[1] if len(sys.argv) > 1 else '').strip()
if not slug:
    print("Usage: /lean-spec:visual-check <slug>")
    sys.exit(1)

wf_path = f"features/{slug}/workflow.json"
if not os.path.exists(wf_path):
    print(f"Feature '{slug}' not found.")
    sys.exit(1)

with open(wf_path) as f:
    data = json.load(f)

phase = data.get('phase', '')
if phase not in ('reviewing', 'closed'):
    print(f"Phase gate: visual-check requires 'reviewing' or 'closed', got '{phase}'.")
    print(f"Run /lean-spec:submit-review {slug} first.")
    sys.exit(1)

review_path = f"features/{slug}/review.md"
if not os.path.exists(review_path):
    print(f"review.md not found. Run /lean-spec:submit-review {slug} first.")
    sys.exit(1)

spec_path = f"features/{slug}/spec.md"
print(f"Feature: {slug} | Phase: {phase}")
print()
print("=== spec.md (first 60 lines) ===")
if os.path.exists(spec_path):
    with open(spec_path) as f:
        lines = f.readlines()
    print(''.join(lines[:60]), end='')
else:
    print("(spec.md not found)")
print()
print("=== review.md (current) ===")
with open(review_path) as f:
    print(f.read(), end='')
