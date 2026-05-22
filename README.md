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
  `pr-to-production`, and `pull-latest` / `squash`. Parameterised per
  repo via `.claude/eng-workflow.json`.

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
    └── skills/              # pull-latest, squash, pr-to-production, tc-reconcile, safe-deps, conventions
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
- `safe-deps`, `tc-reconcile`, `pr-to-production`, `pull-latest`,
  `squash` — the operational skills.
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
