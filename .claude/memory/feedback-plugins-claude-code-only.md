---
name: feedback-plugins-claude-code-only
description: "Claude Code's /plugin marketplace command does not work in Claude Desktop — keep this distinction clear in install docs"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a274a9a6-8258-4ab4-9a08-c012f16a865b
---

The Claude Code plugin system (`/plugin marketplace add ...`, `/plugin install ...`, skills, slash commands, agents) is a **Claude Code-only** feature. Claude Desktop and claude.ai do not support it — they only support raw MCP connectors via the Custom Connectors UI.

**Why:** Brett tested the install path I documented for `paywhereb/paywhere-claude-plugins` and confirmed the slash commands work only in Claude Code, not Claude Desktop. I had originally claimed (per the plan) it worked in both, and that was wrong.

**How to apply:** When writing install instructions for any Claude plugin, document two paths:
- **Claude Code**: `/plugin marketplace add <org>/<repo>` → `/plugin install <plugin>@<repo>` — gets the full plugin (skills + slash commands + MCP servers).
- **Claude Desktop / claude.ai**: only the bare MCP server(s) can be added, via Settings → Connectors → Add custom connector with the server root URL. Skills and slash commands are NOT available.

Do not write "works in Claude Desktop and Claude Code" for a plugin install. The `/plugin` system specifically does not.
