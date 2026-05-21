---
name: feedback-plugin-install-paths
description: Verified install paths for the paywhere-smb plugin per client (Claude Code, Cowork, Claude Desktop, claude.ai). Includes prior mistakes to not repeat.
metadata:
  node_type: memory
  type: feedback
  originSessionId: a274a9a6-8258-4ab4-9a08-c012f16a865b
---

The Anthropic plugin system (a folder with `.claude-plugin/plugin.json`, `.mcp.json`, and `skills/`) runs in two clients: **Claude Code** and **Cowork**. Claude Desktop and claude.ai chat do not load plugins at all — they only host raw MCP servers as Custom Connectors.

**Verified install paths (Brett tested or confirmed via Cowork's own messaging):**

- ✅ **Claude Code** — install via marketplace slash commands inside a session:
  ```
  /plugin marketplace add paywhereb/paywhere-claude-plugins
  /plugin install paywhere-smb@paywhere-claude-plugins
  ```
  Brett confirmed this end-to-end against the live `paywhereb/paywhere-claude-plugins` repo.

- ✅ **Cowork** — side-load a `.plugin` file via Cowork's plugin-file picker. Cowork's in-app messaging: "Side-load a .plugin file. Any plugin packaged as a .plugin file can be installed directly, whether you built it, a teammate shared it, or it came from somewhere outside the marketplace." The `.plugin` file is a zip archive of the plugin directory contents (the same format Claude Code accepts via `--plugin-dir <archive.zip>` and `--plugin-url <url>`, available since v2.1.128 / week of 2026-05-04). The build script `scripts/package.sh` produces both `.plugin` and `.zip` artifacts under `dist/`.

- ❌ **Claude Desktop** — no plugin system at all. Settings → Connectors → Add custom connector only supports raw MCP servers. Brett confirmed Desktop has no `/plugin` slash command.

- ❌ **claude.ai chat (web)** — same as Desktop. The bare Paywhere MCP server can still be added via Custom Connectors (paste `https://mcp.paywhere.com`), but the packaged skills and slash commands won't load.

**Reference docs:**

- Claude Code plugin reference: <https://code.claude.com/docs/en/plugins-reference>
- Plugin creation guide (covers `--plugin-dir`, `--plugin-url`, zip archives): <https://code.claude.com/docs/en/plugins>
- Anthropic curated catalog (where curated plugins land): <https://claude.com/plugins/>
- Week 19 release notes that introduced `.zip` archive loading: <https://code.claude.com/docs/en/whats-new/2026-w19>

**Mistakes to not repeat:**

- I (Claude) once treated Brett's hedged "appears to work only in Claude Code?" as a confirmation. It was a question, not a test result. Always wait for an actual test result before writing install docs.
- I (Claude) once invented a `/plugin marketplace add` path for Cowork without checking. Cowork's plugin-file picker is real; its slash-command surface is not (at least, not what we found). Don't infer Cowork's UX from Claude Code's.
- When the user says "I checked and X" — that's confirmation of X. When the user says "appears to" or ends with "?" — that's a question, not a finding.

**Packaging:** `./scripts/package.sh` (in repo root) takes the version from `paywhere-smb/.claude-plugin/plugin.json` and writes `dist/paywhere-smb-<version>.plugin` and `dist/paywhere-smb-<version>.zip`. The `dist/` directory is gitignored — artifacts are built locally or attached to GitHub releases, not tracked in git.
