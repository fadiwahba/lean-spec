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

def next_cmd(slug, phase, review_path):
    if phase == 'specifying':
        return f"/lean-spec:submit-implementation {slug}"
    elif phase == 'implementing':
        return f"/lean-spec:submit-review {slug}"
    elif phase == 'reviewing':
        v = get_verdict(review_path)
        if v == 'APPROVE':     return f"/lean-spec:close-spec {slug}"
        if v == 'NEEDS_FIXES': return f"/lean-spec:submit-fixes {slug}"
        if v == 'BLOCKED':     return "# BLOCKED — human intervention required"
        return "# Reviewer's verdict unclear. Inspect review.md."
    elif phase == 'closed':
        return "# No next step — feature is closed."
    return f"# Unknown phase '{phase}'."

proj = os.getcwd()
features_dir = os.path.join(proj, 'features')

if slug:
    wf_path = os.path.join(features_dir, slug, 'workflow.json')
    if not os.path.exists(wf_path):
        print(f"Feature '{slug}' not found.")
        sys.exit(1)
    with open(wf_path) as f:
        data = json.load(f)
    print(f"Slug:    {data.get('slug', slug)}")
    print(f"Phase:   {data.get('phase', '')}")
    print(f"Updated: {data.get('updated_at', '')}")
    print()
    print("History:")
    for h in data.get('history', []):
        print(f"  - {h.get('phase', '')}  (entered {h.get('entered_at', '')})")
    print()
    phase = data.get('phase', '')
    review_path = os.path.join(features_dir, slug, 'review.md')
    print(f"Next: {next_cmd(slug, phase, review_path)}")
else:
    wfs = sorted(glob.glob(os.path.join(features_dir, '*/workflow.json')))
    if not wfs:
        print("No features found. Run /lean-spec:start-spec <slug> to begin.")
        sys.exit(0)
    for wf_path in wfs:
        with open(wf_path) as f:
            data = json.load(f)
        s = data.get('slug', '')
        p = data.get('phase', '')
        u = data.get('updated_at', '')
        print(f"{s}  [{p}]  last updated: {u}")
