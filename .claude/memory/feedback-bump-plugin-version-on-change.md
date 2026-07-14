---
name: feedback-bump-plugin-version-on-change
description: Always bump the plugin version when changing a plugin in this repo (manifest + marketplace, kept in sync).
metadata:
  type: feedback
---

Whenever you change a plugin in this repo (skills, commands, demo scripts, datasets, or any file under the plugin's directory), **bump that plugin's version** in the same change.

**Why:** installed plugins (Claude Code marketplace, Cowork side-load) only pick up changes when the version advances — a merge without a version bump ships stale behavior to users. See [[feedback-plugin-install-paths]] for how each client installs.

**How to apply:**
- Bump the plugin version in **both** places, kept identical: `<plugin>/.claude-plugin/plugin.json` and the matching entry in `.claude-plugin/marketplace.json` (e.g. `paywhere-smb` is in both).
- Also bump the changed skill's own `version:` frontmatter in its `SKILL.md`.
- Semver: **default to a patch bump** (x.y.Z+1). Only bump **minor** (x.Y+1.0)
  when the change is a significant new addition (a new skill, command, or a
  workflow-changing step in an existing skill) **or** it breaks compatibility
  with older `paywhere-mcp`/`paywhere-qbo-mcp` versions (the plugin now
  assumes a tool/capability — e.g. `list_saved_payees` — that doesn't exist
  on an older deployed MCP server). Everything else (reference/fixture
  files, docs, copy-only fixes, small tweaks) is a patch bump.
- Examples: ENG-339 demo-setup + reconciliation changes bumped `paywhere-smb`
  0.4.0 → 0.5.0 (new skill behavior) and `demo-setup` SKILL 0.1.0 → 0.2.0.
  `TEST-PAYMENTS.md` (a reference fixture file, no new skill/command, no new
  MCP dependency) bumped `paywhere-smb` 0.7.1 → 0.7.2 (patch).
