# Paywhere Claude Plugins

Public marketplace of Claude Code / Claude Desktop plugins maintained by
[Paywhere](https://paywhere.com).

Today this marketplace ships two plugins:

- **[`paywhere-smb`](paywhere-smb/)** — Pre-built small-business workflows
  (cash forecasting, month-end close, weekly briefs, growth campaigns,
  invoice chase, tax prep) running against your Paywhere bank account,
  QuickBooks, HubSpot, and the rest of your stack.
- **[`paywhere-eng-workflow`](paywhere-eng-workflow/)** — Shared
  engineering workflow for Paywhere repos: `/start`, `/finish`,
  `/create`, `/review`, plus `safe-deps`, `tc-reconcile`,
  `pr-to-production`, `tf-drift`, `pull-latest`, `squash`, and
  `prune-merged-branches`. Parameterised per repo via
  `.claude/eng-workflow.json`.

## Installation

The plugin system runs in **Claude Code** and **Cowork**. Claude
Desktop and claude.ai chat don't support plugins; they only support
raw MCP servers via Custom Connectors.

### Claude Code

```
/plugin marketplace add paywhereb/paywhere-claude-plugins
/plugin install paywhere-smb@paywhere-claude-plugins
/plugin install paywhere-eng-workflow@paywhere-claude-plugins
```

### Cowork (side-load)

Build a `.plugin` archive and side-load it through Cowork's plugin
file picker:

```bash
git clone https://github.com/paywhereb/paywhere-claude-plugins.git
cd paywhere-claude-plugins
./scripts/package.sh paywhere-smb
# → dist/paywhere-smb-<version>.plugin
```

### Claude Desktop / claude.ai

No plugin support. You can still add the bare Paywhere MCP server
(`https://mcp.paywhere.com`) via Settings → Connectors → Add custom
connector — see
[`paywhere-smb/README.md`](paywhere-smb/README.md#claude-desktop--claudeai-mcp-server-only--no-skills-no-slash-commands)
for the full Desktop / claude.ai path.

After install (Claude Code or Cowork), ask Claude to "set me up" —
the `smb-onboard` skill will walk you through Paywhere + QuickBooks
OAuth and run a demo recipe.

## Editing plugins locally

Claude Code's marketplace install path is a security boundary: when
you `/plugin install`, it copies the plugin into a per-version cache
under `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`,
and the running session reads from there — not from the marketplace
clone. That's good for ordinary users, but means a stock install
doesn't see your in-progress edits.

There are three ways around this, in order of robustness.

### Option 1 (recommended): `claude --plugin-dir`

The official dev mode. Launch Claude Code with a flag pointing at
your working copy, and Claude Code reads commands and skills directly
from disk — no cache, no copy.

```bash
claude --plugin-dir /path/to/paywhere-claude-plugins/paywhere-eng-workflow
```

Then edits to files under `paywhere-eng-workflow/` are picked up on
the next skill or command invocation. Use `/reload-plugins` to refresh
hooks, MCP servers, and LSP servers mid-session; skills and commands
re-read on every use without a reload.

For everyday use, alias it. In `~/.bashrc` or `~/.zshrc`:

```bash
alias claude-dev='claude --plugin-dir /path/to/paywhere-claude-plugins/paywhere-eng-workflow'
```

You can pass multiple `--plugin-dir` flags to load several
in-development plugins at once. Stock plugin behavior is still
available via plain `claude`.

**Trade-offs.** The flag is per-session — every `claude` launch needs
it (or the alias). `--plugin-dir` plugins don't appear under
`/plugin` Installed; they're loaded ephemerally.

### Option 2: cache-subdir symlinks

If you want a "real" install (the plugin appears under `/plugin`,
shares state with other users on the same machine, etc.) but still
need live edits, symlink the cache subdirectories to your working
copy:

```bash
# In Claude Code:
/plugin marketplace add paywhereb/paywhere-claude-plugins
/plugin install paywhere-eng-workflow@paywhere-claude-plugins

# Then, from a shell, swap the cache copies for symlinks. Adjust
# the version to whatever the install created.
CACHE=~/.claude/plugins/cache/paywhere-claude-plugins/paywhere-eng-workflow/0.1.0
SRC=/path/to/paywhere-claude-plugins/paywhere-eng-workflow
rm -rf "$CACHE"/commands "$CACHE"/skills "$CACHE"/.claude-plugin "$CACHE"/README.md
ln -s "$SRC"/commands       "$CACHE"/commands
ln -s "$SRC"/skills         "$CACHE"/skills
ln -s "$SRC"/.claude-plugin "$CACHE"/.claude-plugin
ln -s "$SRC"/README.md      "$CACHE"/README.md

# Then in Claude Code:
/reload-plugins
```

Leave `$CACHE/.in_use/` alone — that's Claude Code's own bookkeeping.

**Trade-offs.** Unsupported by docs and fragile:

- Running `/plugin install` or `/plugin marketplace update` again
  may overwrite the symlinks with fresh copies — you'd have to redo
  the swap.
- Bumping the plugin version in `plugin.json` creates a new cache
  dir at a different path (`.../<new-version>/`); the symlinks at
  the old path no longer apply.
- Future Claude Code releases could change the cache layout. The
  docs explicitly say "Plugins are copied to a cache" as a security
  property, so don't expect the cache to become symlink-aware.

You may also want to symlink the marketplace clone itself
(`~/.claude/plugins/marketplaces/paywhere-claude-plugins` →
your working copy) so `marketplace.json` reflects whatever plugins
your local checkout declares before they're merged.

### Option 3: regular marketplace install + reinstall loop

If the live-edit trade-offs of options 1 and 2 don't appeal — or
you want to test the install path itself the way a teammate would —
just use the documented install + update flow. **The marketplace
does not need to be public** for this; Claude Code authenticates to
private git via your existing credentials, and pure local paths
skip git entirely.

Possible marketplace sources:

```
# Private GitHub (uses your gh/ssh credentials)
/plugin marketplace add paywhereb/paywhere-claude-plugins

# Any git URL, including private GitLab / Bitbucket / self-hosted
/plugin marketplace add git@gitlab.com:org/plugins.git

# Pure local checkout (no network at all)
/plugin marketplace add /path/to/paywhere-claude-plugins
```

The iteration loop:

1. Edit files in your working copy.
2. Commit them (for git-source marketplaces, you'll also need to
   push). For pure local-path marketplaces, the commit is enough.
3. In Claude Code:

   ```
   /plugin marketplace update paywhere-claude-plugins
   /plugin install paywhere-eng-workflow@paywhere-claude-plugins
   /reload-plugins
   ```

That refreshes the marketplace catalog, copies the latest plugin
content into the cache, and activates it. Slower than options 1 and
2 (3 commands per change instead of 1 edit), but uses only
documented features and survives every Claude Code upgrade.

Note that local development marketplaces have auto-update disabled by
default, so you do need the explicit `/plugin marketplace update`
between cycles.

### Which to use when

| Situation | Pick |
| --- | --- |
| Iterating on commands or skills, want edits live | Option 1 (`--plugin-dir`) |
| Need the plugin to behave like a fully-installed plugin (appear under `/plugin`, share state) and still live-edit | Option 2 (cache symlinks) |
| Testing what a teammate's install will look like, or you don't trust the symlink hack on your machine | Option 3 (regular install + reinstall loop) |

## Repository layout

```
paywhere-claude-plugins/
├── .claude-plugin/
│   └── marketplace.json     # marketplace manifest
├── README.md                # you are here
├── demo/
│   └── seed.md              # demo / sales-asset sandbox seeding notes
├── paywhere-smb/            # the SMB plugin
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── .mcp.json            # Paywhere + QuickBooks + HubSpot + Canva + Slack + Mail + Calendar + Drive
│   ├── README.md
│   └── skills/              # 15 building-block + 15 workflow skills
└── paywhere-eng-workflow/   # the engineering workflow plugin
    ├── .claude-plugin/
    │   └── plugin.json
    ├── README.md
    ├── commands/            # start, finish, create, review, eng-init
    └── skills/              # pull-latest, squash, pr-to-production, tc-reconcile, tf-drift, safe-deps, conventions
```

## What's inside the SMB plugin

Three layers:

1. **Skills** — atomic building blocks (forecast cash, score leads, draft an invoice reminder).
2. **Commands** — multi-step workflows that chain skills together with approval gates.
3. **The Router** — front-door skill that parses plain English requests and routes to the right command.

Every workflow pauses before taking action — nothing moves money or
sends to customers without explicit owner approval.

See [`paywhere-smb/README.md`](paywhere-smb/README.md) for the full
catalog of commands and skills.

## What's inside the eng-workflow plugin

A shared Linear-ticket-driven dev workflow that any Paywhere repo can
opt into:

- `/start <ticket>` — branch off the default branch for an existing
  Linear ticket; reopens the ticket if it's closed.
- `/finish` — commit, push, open a PR, comment on Linear, transition to
  In Review. Refuses to run if the current branch isn't associated with
  a ticket.
- `/create` — bootstrap a Linear ticket from the working diff.
- `/review` — review the current implementation against the ticket and
  the shared conventions.
- `safe-deps`, `tc-reconcile`, `pr-to-production`, `tf-drift`,
  `pull-latest`, `squash` — the operational skills.
- `tf-drift` — explain the latest Terraform drift sweep in plain English,
  attribute the change via CloudTrail, and drive the gated revert (or draft
  a codify PR) **without** bypassing the human approval gate. Gated on
  `guards.tfDrift.enabled`. Designed for **no-CLI ops**: side-load the plugin
  into **Cowork / claude.ai** (`./scripts/package.sh paywhere-eng-workflow`)
  and triage drift from a GUI chat — no terminal or Terraform fluency needed.
- `/eng-init` — write `.claude/eng-workflow.json` for a fresh repo.

Each host repo configures the plugin via a per-repo
`.claude/eng-workflow.json` (Linear team + labels, default branch,
branch pattern, optional guards). See
[`paywhere-eng-workflow/README.md`](paywhere-eng-workflow/README.md) for
the config schema and field reference.

## Demo

See [`demo/seed.md`](demo/seed.md) for instructions on standing up a
QuickBooks Online sandbox company + a seeded Paywhere mock-dev
environment for end-to-end demos of `/close-month`, `/plan-payroll`, and
`/monday-brief`.

## Provenance

`paywhere-smb` was forked from Anthropic's open-source
[`anthropics/knowledge-work-plugins/small-business`](https://github.com/anthropics/knowledge-work-plugins/tree/main/small-business)
plugin, with the payment-processor connectors (Stripe, PayPal, Square)
removed and replaced with Paywhere as a single banking + payment-rail
source. The bookkeeping and CRM layers (QuickBooks, HubSpot, etc.)
remain intact.

## License

The fork inherits the upstream license. See `paywhere-smb/` and the
upstream repo for terms.
