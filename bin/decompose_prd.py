#!/usr/bin/env python3
import json, sys, os, re, datetime

args = (sys.argv[1] if len(sys.argv) > 1 else '').strip()
prd_path = args if args else 'docs/PRD.md'

if not os.path.exists(prd_path):
    print(f"PRD not found at '{prd_path}'. Run /lean-spec:brainstorm first.")
    sys.exit(1)

def slugify(heading):
    s = re.sub(r'^[0-9]+(\.[0-9]+)*\s+', '', heading)
    s = re.sub(r'^[0-9]+\)\s+', '', s)
    s = s.lower()
    s = re.sub(r'[^a-z0-9]+', '-', s)
    return s.strip('-')

headings = []
in_features = False
with open(prd_path) as f:
    for line in f:
        line = line.rstrip('\n')
        if line.startswith('## '):
            title = line[3:].strip()
            if re.match(r'^([0-9]+\.\s+)?Features\s*$', title):
                in_features = True
            else:
                if in_features:
                    break
                in_features = False
        elif in_features and line.startswith('### '):
            headings.append(line[4:].strip())

if not headings:
    print(f"No Features section found in {prd_path} (expected '## <N>. Features' with '### <N>.<M> <title>' sub-sections).")
    sys.exit(1)

now = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
created = 0
skipped = 0

for heading in headings:
    if not heading:
        continue
    slug = slugify(heading)
    dir_path = f"features/{slug}"
    if os.path.isdir(dir_path):
        print(f"skip {slug} — exists")
        skipped += 1
        continue
    os.makedirs(dir_path, exist_ok=True)
    wf = {
        "slug": slug, "phase": "specifying",
        "created_at": now, "updated_at": now,
        "history": [{"phase": "specifying", "entered_at": now}],
        "artifacts": {"spec": "spec.md", "notes": "notes.md", "review": "review.md"}
    }
    with open(f"{dir_path}/workflow.json", 'w') as f:
        json.dump(wf, f, indent=2)
    spec = f'''---
slug: {slug}
phase: specifying
handoffs:
  next_command: /lean-spec:submit-implementation {slug}
  blocks_on: []   # list sibling slugs this feature depends on
  consumed_by: [coder, reviewer]
---

# {heading}

> Skeleton from /lean-spec:decompose-prd. Run /lean-spec:update-spec {slug} to complete.

## Scope
(see PRD §{heading})

## Acceptance Criteria
## Out of Scope
## Technical Notes
## Coder Guardrails
'''
    with open(f"{dir_path}/spec.md", 'w') as f:
        f.write(spec)
    print(f"created features/{slug}/")
    created += 1

print()
print(f"Done. {created} skeleton(s) created, {skipped} already existed.")
print("Note: Claude Code native version also auto-generates .lean-spec/rules.yaml and warns about")
print("cross-feature dependencies. This degraded port omits both — check blocks_on manually.")
print("Next: /lean-spec:update-spec <slug> per feature.")
