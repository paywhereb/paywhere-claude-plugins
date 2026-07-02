# CLAUDE.md — paywhere-claude-plugins

Guidance for Claude Code (and any agent) working in this repo.

## Repo layout

A Claude Code **plugin marketplace**. Each top-level `*/` directory with a
`.claude-plugin/plugin.json` is one plugin; `.claude-plugin/marketplace.json`
at the repo root lists them all. Current plugins:

- `paywhere-smb/` — small-business finance workflows + the `/demo-setup` command.
- `paywhere-eng-workflow/` — shared engineering workflow skills.

## MUST: bump the plugin version on every change (CI-enforced)

`.github/workflows/plugin-version-check.yml` runs on every PR to `main` and
**fails the PR** if either rule is broken. This is the single easiest check to
forget — do it as part of the same change, not as a follow-up.

1. **If you change any file under a plugin's directory (`<plugin>/…`), bump that
   plugin's `version`** in `<plugin>/.claude-plugin/plugin.json`. Docs/skill/prompt
   edits count — *any* file under the plugin dir triggers it. Use semver: patch
   for docs/copy/skill tweaks, minor for new skills/behavior, major for breaking
   changes.
2. **Keep the versions in sync.** The plugin's version in
   `<plugin>/.claude-plugin/plugin.json` **must equal** its entry's `version` in
   `.claude-plugin/marketplace.json`. Update **both** in the same commit.

Notes:
- The check compares against the PR's **base** `plugin.json` version, so the new
  value must differ from what's on `main` — not just be internally consistent.
- Files **outside** any plugin directory (e.g. top-level `demo/`, `.github/`,
  this `CLAUDE.md`) do **not** require a bump. Only per-plugin directories are
  gated. When a change spans a plugin dir *and* top-level files, the plugin bump
  is still required.
- Multiple plugins changed in one PR → bump **each** changed plugin.

### Example

A docs-only edit under `paywhere-smb/` (e.g. a `SKILL.md` or `DATASET.md`):

```
paywhere-smb/.claude-plugin/plugin.json   "version": "0.6.1" -> "0.6.2"
.claude-plugin/marketplace.json           paywhere-smb entry "version": "0.6.1" -> "0.6.2"
```

## Git / PRs

- Branch and PR per the repo conventions (feature branch off `main`, PR into
  `main`). Do not commit directly to `main`.
- Do not edit branch protection or CI permissions here — CI config is reviewed
  like any other change.
