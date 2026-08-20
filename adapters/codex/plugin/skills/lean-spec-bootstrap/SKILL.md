---
name: lean-spec-bootstrap
description: Install lean-spec's Codex adapter into the current Git project. Run explicitly once after installing the marketplace plugin.
---

# Bootstrap lean-spec for Codex

Run this once from the target Git repository after installing the plugin. Use
the absolute path of this selected skill directory shown by Codex, not the
project working directory:

```text
python3 <this-skill-directory>/scripts/codex_bootstrap.py --project "$PWD"
```

It installs copied project runtime files, Codex hooks and agents, an `AGENTS.md`
block, and the host-neutral lifecycle skills. It is idempotent. Do not use
symlinks for a normal installation.
