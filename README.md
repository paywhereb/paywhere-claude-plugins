# Paywhere Claude Plugins

Public marketplace of Claude Code / Claude Desktop plugins maintained by
[Paywhere](https://paywhere.com).

Today this marketplace ships one plugin:

- **[`paywhere-smb`](paywhere-smb/)** — Pre-built small-business workflows
  (cash forecasting, month-end close, weekly briefs, growth campaigns,
  invoice chase, tax prep) running against your Paywhere bank account,
  QuickBooks, HubSpot, and the rest of your stack.

## Installation

The plugin system runs in **Claude Code** and **Cowork**. Claude
Desktop and claude.ai chat don't support plugins; they only support
raw MCP servers via Custom Connectors.

### Claude Code

```
/plugin marketplace add paywhereb/paywhere-claude-plugins
/plugin install paywhere-smb@paywhere-claude-plugins
```

### Cowork (side-load)

Build a `.plugin` archive and side-load it through Cowork's plugin
file picker:

```bash
git clone https://github.com/paywhereb/paywhere-claude-plugins.git
cd paywhere-claude-plugins
./scripts/package.sh
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
└── paywhere-smb/            # the SMB plugin
    ├── .claude-plugin/
    │   └── plugin.json
    ├── .mcp.json            # Paywhere + QuickBooks + HubSpot + Canva + Slack + Mail + Calendar + Drive
    ├── README.md
    └── skills/              # 15 building-block + 15 workflow skills
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
