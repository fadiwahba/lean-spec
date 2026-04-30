#!/usr/bin/env python3
import json, sys, os, datetime, glob

args_raw = sys.argv[1] if len(sys.argv) > 1 else ''
parts = args_raw.split()
slug = next((p for p in parts if not p.startswith('--')), '')
visual = '--visual' in parts
extras = [p for p in parts if not p.startswith('--') and p != slug]

if not slug:
    print("Usage: /lean-spec:submit-review <slug> [--visual]")
    sys.exit(1)

wf_path = f"features/{slug}/workflow.json"
if not os.path.exists(wf_path):
    print(f"Feature '{slug}' not found.")
    sys.exit(1)

with open(wf_path) as f:
    data = json.load(f)

current = data.get('phase', '')
if current != 'implementing':
    print(f"Phase gate: expected 'implementing', got '{current}'")
    sys.exit(1)

if not os.path.exists(f"features/{slug}/notes.md"):
    print(f"notes.md not found. Run /lean-spec:submit-implementation {slug} first.")
    sys.exit(1)

review_dir = f"features/{slug}"
review_path = f"{review_dir}/review.md"
if os.path.exists(review_path):
    existing = glob.glob(f"{review_dir}/review-cycle-*.md")
    next_num = len(existing) + 1
    os.rename(review_path, f"{review_dir}/review-cycle-{next_num}.md")

now = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
data['phase'] = 'reviewing'
data['updated_at'] = now
data['history'].append({'phase': 'reviewing', 'entered_at': now})

tmp = wf_path + '.tmp'
with open(tmp, 'w') as f:
    json.dump(data, f, indent=2)
os.replace(tmp, wf_path)
extras_str = ' '.join(extras) if extras else 'none'
print(f"phase advanced: implementing → reviewing (visual: {'yes' if visual else 'no'}, extras: {extras_str})")
