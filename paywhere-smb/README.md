# Paywhere SMB Plugin

Pre-built small-business **finance** workflows that run against your
**Paywhere bank account** + QuickBooks. Install it once and you get a set
of ready-to-use workflows — cash-flow forecasting, month-end close, payroll
planning, invoice chasing, and commission payouts across ACH, Wire, and
Stablecoin — plus a router that understands plain English.

You don't need to memorize anything. Just tell Claude what you need — "I'm
stressed about making payroll," "close the books," "pay my reps for last
week" — and it figures out the right workflow and walks you through it.
Every workflow pauses before taking action, so nothing happens without
your say-so.

> **Important**: This plugin assists with small business finance workflows
> but does not provide financial, tax, or legal advice. All outputs should
> be reviewed by you (and where appropriate, a qualified professional)
> before use.

## Installation

The Anthropic plugin system runs in two clients:
[Claude Code](https://claude.com/product/claude-code) and
[Cowork](https://claude.com/product/cowork). Claude Desktop and
claude.ai chat do **not** support plugins — they only support raw MCP
servers via the Custom Connectors UI.

### Claude Code — install from the marketplace

From inside a Claude Code session:

```
/plugin marketplace add paywhereb/paywhere-claude-plugins
/plugin install paywhere-smb@paywhere-claude-plugins
```

Once installed, ask Claude to "set me up" — it'll run the `smb-onboard`
skill, walk you through connecting Paywhere (OAuth at
<https://demo.paywhere.com/mcp>) and QuickBooks, and run a demo recipe.

### Cowork — side-load the `.plugin` archive

Cowork supports side-loading a plugin from a packaged `.plugin` file
(any plugin packaged as a `.plugin` file can be installed directly
without going through the curated marketplace).

1. Clone this repo and build the artifact:

   ```bash
   git clone https://github.com/paywhereb/paywhere-claude-plugins.git
   cd paywhere-claude-plugins
   ./scripts/package.sh paywhere-smb
   ```

   This writes `dist/paywhere-smb-<version>.plugin`.

2. In Cowork, use the "side-load a plugin file" flow and select the
   `.plugin` file you just built.

> The `.plugin` file is a zip archive of the plugin folder contents,
> matching the same layout Claude Code accepts via
> `claude --plugin-dir <archive.zip>`. The script also emits a
> `.zip` copy with identical contents under `dist/`.

### Claude Desktop / claude.ai (MCP server only — no skills, no slash commands)

> Claude Desktop and claude.ai do **not** support the plugin system.
> They have no `/plugin` slash command, and the packaged skills
> (`cash-flow-snapshot`, `month-end-prep`, etc.) and command shortcuts
> (`/close-month`, `/plan-payroll`, …) won't load.

You *can* still connect the bare **Paywhere MCP server** as a custom
connector. You'll lose the packaged workflow scaffolding, but Claude
can call every Paywhere tool (`list_accounts`, `get_account_balance`,
`get_account_transactions`, ACH/wire/stablecoin flows, etc.) when you
ask it to.

**claude.ai:** Settings → Connectors → Add custom connector. Paste the
server URL:

```
https://demo.paywhere.com/mcp
```

For QuickBooks, Gmail, and Google Drive, add each one separately as its
own custom connector. The full URL list lives in [`.mcp.json`](.mcp.json).

## What you'll need to connect

Run `/smb-onboard` or ask Claude to "set me up."

**Core tools** (connect these first for the best experience):
- **Paywhere** — your bank. Powers cash position, settled bank lines, the
  reconciliation flow at the heart of month-end close, and the three
  payment rails (ACH, Wire, Stablecoin) used by commission payouts. Connect
  via OAuth at <https://demo.paywhere.com/mcp>.
- **QuickBooks** — your books. Powers the bookkeeping layer (AR, AP, P&L,
  invoice register, customer payments) that Paywhere reconciles against, and
  the Bill / Bill-Payment records that commission payouts write back.

**Supporting tools:**
- **Gmail / Outlook** — invoice-reminder and payroll mail drafts; the real-data
  read path for worker hour reports in `/pay-and-bill`.
- **Google Drive** — worker hour-report notes (demo path for
  `/pay-and-bill`); stores close packets and QBR exports.

**Demo environments only:**
- **paywhere-mock** — the Paywhere Demo Seeder at
  <https://demo.paywhere.com/mock-mcp>. Powers the `/demo-setup-*` commands
  (reset + seed the sandbox). Same sign-in as the Paywhere connector but
  authorized separately. Only exists on demo deployments — skip it when
  running against real accounts.

You don't need all of these to start. Connect Paywhere + QuickBooks and
you'll immediately see value — the plugin tells you when connecting another
tool would unlock more.

## How it works

Three layers working together:

1. **Skills** — the building blocks. Each skill knows how to do one thing
   really well (forecast cash, reconcile a month, draft an invoice
   reminder, pay one commission).

2. **Commands** — the workflows. Commands chain skills together into
   multi-step recipes with checkpoints where you approve before anything
   happens.

3. **The Router** — the front door. You talk to Claude in plain English.
   The router listens, figures out which workflow fits, and gets you
   there. You never need to memorize a command name.

## Commands

Commands are workflows that chain skills together. Each one pauses at
checkpoints for your approval before taking action.

### Money & finance

| Command | What it does | Just say... | Skills used | Required | Optional |
|---|---|---|---|---|---|
| `/plan-payroll` | Payroll readiness: with Paywhere connected, real-time balance + settlement detection (never chases a customer who paid this morning), shortfall projection, reminder drafts; without it, a QuickBooks-only forecast. | "can I make payroll", "am I good for payroll", "cash is tight", "who owes me money" | plan-payroll, cash-flow-snapshot, invoice-chase | QuickBooks | Paywhere, Gmail |
| `/pay-bills` | AP catch-up: pulls QuickBooks AP aging, selects overdue bills, one approval, pays the whole batch across mixed rails, books the bill payments back, verifies settlement. | "pay my bills", "what's overdue", "AP aging" | pay-bills | QuickBooks | Paywhere (without it: analysis + drafted list only) |
| `/pay-and-bill` | Hours-to-cash: aggregates worker hour reports, invoices each client, pays the workers in one batch, books the bills, reconciles. | "bill clients for hours", "pay my contractors" | pay-and-bill | QuickBooks, Paywhere | Gmail, Google Drive |
| `/month-heads-up` | 30-day cash outlook with early risk flags. | "what does next month look like", "cash forecast", "runway" | cash-flow-snapshot | QuickBooks | Paywhere |
| `/close-month` | Month-end close: reconcile Paywhere bank lines vs QuickBooks, flag gaps, write P&L, export close packet. | "close the books", "month-end", "reconcile" | month-end-prep | QuickBooks, Paywhere | Google Drive |
| `/price-check` | Margin-by-product table and three pricing scenarios. | "what are my margins", "should I raise prices", "cost per unit" | (self-contained) | QuickBooks | — |
| `/tax-prep` | Tax prep materials for your accountant (quarterly estimates or year-end 1099s). | "tax stuff", "estimated taxes", "1099s", "accountant needs..." | tax-season-organizer | QuickBooks | Paywhere |

### Commissions

| Command | What it does | Just say... | Skills used | Required | Optional |
|---|---|---|---|---|---|
| `/pay-commissions` | Pays commissions on payments you actually received, across ACH/Wire/Stablecoin: applies the commission policy (client → rate → payee → rail), matches Paywhere credits to QBO payments, dedupes against the booked markers, and — after you approve — disburses the whole batch (`make_batch_payment`) and books a Bill + Bill Payment per commission. | "pay commissions", "pay my reps", "run commissions for last week" | pay-commissions | QuickBooks, Paywhere | — |

### Demo setup (sales/sandbox only)

`/demo-setup` stands up the **entire** repeatable demo environment in two
server-side calls (bank + books) against the hosted sandbox connectors. It needs
the **paywhere-mock** seeder connector and is not meant for real accounts. See
[`../demo/seed.md`](../demo/seed.md) and [`../demo/demo-script.md`](../demo/demo-script.md).

| Command | What it does | Skills used | Required |
|---|---|---|---|
| `/demo-setup` | Builds the whole demo world (Meridian Staffing & Advisory LLC, scaled ~0.30×): `seed_demo_world` resets the mock bank + seeds ~6 months of date-relative history + pre-configures recipients + writes enrichment, then `seed_demo_books` mirrors the QBO books on the same dates. Readies every Phase-1 and Phase-2 beat in one run. | demo-setup | paywhere-mock, Paywhere, QuickBooks |

### Weekly & quarterly briefs

| Command | What it does | Just say... | Skills used | Required | Optional |
|---|---|---|---|---|---|
| `/friday-brief` | Friday end-of-week pulse: revenue vs last week, top sellers, wins and watches. | "end of week", "how'd we do", "Friday recap" | business-pulse | QuickBooks or Paywhere | -- |
| `/quarterly-review` | Full QBR narrative: revenue, margin, customer concentration, opportunities, risks. | "quarterly review", "board deck", "QBR" | business-pulse | QuickBooks | Paywhere |

> The **Monday / weekly check-in** brief is handled directly by the
> `business-pulse` skill (below) — just say "Monday brief", "weekly
> check-in", or "what's on my plate". It produces the one-page snapshot and
> can save a dated file to your drive.

## Building-block skills

Skills are the atomic building blocks. Each one does one thing well; the
commands above compose them.

| Skill | What it does | Just say... | Required | Optional |
|---|---|---|---|---|
| **cash-flow-snapshot** | 30/60/90-day cash forecast with confidence bands and named risk flags. Chat summary + XLSX. | "forecast my cash flow", "will I make payroll", "runway", "cash crunch" | QuickBooks, Paywhere | CSV upload |
| **invoice-chase** | Drafts overdue-invoice reminders matched to each customer's payment history and tone. Cross-references Paywhere credits so customers who already paid don't get chased. | "who owes me money", "overdue invoices", "follow up on unpaid" | QuickBooks, Paywhere | Gmail |
| **month-end-prep** | Month-end close: reconciles the QB transaction register against Paywhere bank lines, flags gaps, writes a P&L narrative, exports a close packet. | "close the month", "reconcile", "P&L", "why revenue changed" | QuickBooks, Paywhere | Google Drive |
| **tax-season-organizer** | Quarterly estimated tax calc or year-end 1099-NEC prep with accountant handoff packet. | "quarterly taxes", "estimated tax payment", "1099s", "1099-NEC", "year-end tax prep" | QuickBooks | Paywhere |
| **pay-commissions** | Pays sales commissions across ACH/Wire/Stablecoin from the commission policy (client → rate → payee → rail), matching Paywhere credits to QBO customer payments, deduping against booked markers, batch-disbursing after one approval, and booking a Bill + Bill Payment per commission. | "pay commissions", "pay my reps", "run commissions" | QuickBooks, Paywhere | — |
| **pay-bills** | AP batch bill-pay: QBO AP aging → overdue-bill selection → one approval → mixed-rail batch payment (saved payees) → bill payments written back → settlement verified against the bank. | "pay my bills", "AP aging", "what's overdue" | QuickBooks | Paywhere |
| **pay-and-bill** | Hours-to-cash loop: read last week's hours from QBO time-activities → invoice each client → pay workers in one batch → book worker bills → reconcile. | "bill clients for hours", "pay my contractors" | QuickBooks, Paywhere | — |
| **plan-payroll** | Payroll readiness with real-time bank data when Paywhere is connected (settlement detection, shortfall projection, reminder drafts); QBO-only forecast otherwise. | "can I make payroll", "am I good for payroll" | QuickBooks | Paywhere, Gmail |
| **demo-setup** | Repeatable sandbox setup in two server-side calls: builds the whole mock-bank world + mirrored QBO books with deterministic, date-relative demo data (identical Monday through Friday). Sales/demo use only. | "set up the demo", "reset the demo" | paywhere-mock, Paywhere, QuickBooks | — |
| **business-pulse** | One-page financial snapshot: cash, revenue trend, pending money movement, watch-list, and the single most important thing needing attention today. Doubles as the Monday / weekly check-in (top-3 actions + dated file save). | "how's the business doing", "snapshot", "weekly summary", "Monday brief", "weekly check-in", "catch me up" | -- (degrades gracefully) | QuickBooks, Paywhere, Gmail |
| **smb-onboard** | Walks you through connecting tools, runs a demo recipe, captures your business context, and sets a weekly check-in cadence. | "set me up", "setup", "get started", "help me get set up", "I'm new to this", "what can you do" | -- | All connectors |

## Trying it out

The skills read **live data** from your connected accounts and never assume
specific records — point them at your real books or at a sandbox. To explore
end-to-end before going live, [`demo/seed.md`](../demo/seed.md) walks through
standing up an example scenario (a QuickBooks sandbox via the hosted fork at
`qbo-demo.paywhere.com` paired with the hosted Paywhere demo MCP at
`demo.paywhere.com`). What each flow surfaces depends entirely on the data
present — the figures vary, the behavior is the same:

- **`/close-month`** — reconciles the month's Paywhere bank lines against the
  QBO register, flags any gaps (e.g. bank-side credits not in QB, or fee
  deltas), writes a P&L narrative, and exports the close packet.
- **`/plan-payroll`** — pulls QBO AR/AP and Paywhere balances, runs the
  30/60/90 forecast, flags any upcoming payroll or cash crunch, and stages a
  ranked invoice-chase batch as Gmail drafts.
- **`/demo-setup` → `/pay-commissions "last week"`** — the seed includes the
  qualifying inbound bank credits, QBO customer-payment history, the
  server-side commission policy, and pre-configured/verified payees; the flow
  then matches Paywhere credits to QBO payments, shows the commission table,
  gates on your approval, disburses across ACH / Wire / Stablecoin (stablecoin
  previewed to surface the 1% fee), and books a marker Bill + Bill Payment. A
  second run reports everything "already paid" — dedupe from the QBO marker.
- **`/demo-setup` → `/pay-bills`** — overdue AP scenario (overdue + due-this-week
  open bills with saved payees): aging table, one approval,
  mixed-rail batch payment, bill payments booked back, settlement verified
  against the bank.
- **`business-pulse`** ("Monday brief" / "weekly check-in") — cross-connector
  synthesis: QBO revenue trend, Paywhere balances + 7-day inflow, and any
  payment pending past its expected clearing window.

## Customizing

These workflows are generic starting points. They become much more useful
when you customize them for how your business actually works:

- **Add business context** — Drop your industry, products, customers, and
  processes into skill files so Claude understands your world.
- **Adjust thresholds** — Tune the alert thresholds in `business-pulse`
  and `cash-flow-snapshot` to match your scale.
- **Set your commission policy** — Who gets commission, at what rate, and on
  which rail is the commission policy `/pay-commissions` applies (client → rate
  → payee → rail). On real books, capture it where your team keeps comp rules
  and tell the skill; in the demo it is server-seeded (see
  [`DATASET.md`](DATASET.md)).
