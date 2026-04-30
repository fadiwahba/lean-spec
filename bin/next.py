#!/usr/bin/env python3
import json, sys, os, glob

slug = (sys.argv[1] if len(sys.argv) > 1 else '').strip()

def get_verdict(review_path):
    if not os.path.exists(review_path):
        return None
    with open(review_path) as f:
        for line in f:
            if line.startswith('verdict:'):
                return line.split(':', 1)[1].strip().replace(' ', '')
    return None

proj = os.getcwd()

if slug:
    wf_path = os.path.join(proj, 'features', slug, 'workflow.json')
    if not os.path.exists(wf_path):
        print(f"Feature '{slug}' not found.")
        sys.exit(1)
else:
    best_wf = None
    best_time = ''
    for wf_path in glob.glob(os.path.join(proj, 'features/*/workflow.json')):
        with open(wf_path) as f:
            data = json.load(f)
        phase = data.get('phase', '')
        updated = data.get('updated_at', '')
        if phase == 'closed' or not phase:
            continue
        if not best_time or updated > best_time:
            best_wf = wf_path
            best_time = updated
    if not best_wf:
        print("No in-progress features. Run /lean-spec:start-spec <slug> to begin.")
        sys.exit(0)
    wf_path = best_wf

with open(wf_path) as f:
    data = json.load(f)

slug = data.get('slug', '')
phase = data.get('phase', '')
print(f"Feature: {slug}")
print(f"Phase:   {phase}")
print()

review_path = os.path.join(proj, 'features', slug, 'review.md')
verdict = get_verdict(review_path)

if phase == 'specifying':
    print(f"Next: /lean-spec:submit-implementation {slug}")
elif phase == 'implementing':
    print(f"Next: /lean-spec:submit-review {slug}")
elif phase == 'reviewing':
    if verdict == 'APPROVE':
        print(f"Next: /lean-spec:close-spec {slug}")
    elif verdict == 'NEEDS_FIXES':
        print(f"Next: /lean-spec:submit-fixes {slug}")
    elif verdict == 'BLOCKED':
        print(f"Next: # BLOCKED — human intervention required")
    else:
        print(f"Next: /lean-spec:spec-status {slug}  # verdict unclear")
elif phase == 'closed':
    print("No next step — feature is closed.")
