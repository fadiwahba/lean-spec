#!/usr/bin/env python3
import json, sys, os, datetime, re

args = sys.argv[1] if len(sys.argv) > 1 else ''
parts = args.split(None, 1)
slug = parts[0] if parts else ''
brief = parts[1] if len(parts) > 1 else ''

if not slug:
    print("Usage: /lean-spec:start-spec <slug> [brief or @path/to/PRD.md]")
    sys.exit(1)

if not re.match(r'^[a-z0-9][a-z0-9-]*$', slug):
    print(f"Invalid slug '{slug}': lowercase letters, digits, and hyphens only")
    sys.exit(1)

if os.path.isdir(f"features/{slug}"):
    print(f"Feature '{slug}' already exists. Use /lean-spec:update-spec {slug} to revise.")
    sys.exit(1)

os.makedirs(f"features/{slug}", exist_ok=True)
now = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')

wf = {
    "slug": slug,
    "phase": "specifying",
    "created_at": now,
    "updated_at": now,
    "history": [{"phase": "specifying", "entered_at": now}],
    "artifacts": {"spec": "spec.md", "notes": "notes.md", "review": "review.md"}
}
with open(f"features/{slug}/workflow.json", 'w') as f:
    json.dump(wf, f, indent=2)

print(f"Created features/{slug}/ (phase=specifying) — brief: {brief}")
