# Paywhere SMB Plugin

Pre-built small-business workflows that run against your **Paywhere bank
account** + QuickBooks + the rest of your stack. Install it once and you
get 15 building-block skills, 15 ready-to-use workflows, and a router that
understands plain English.

You don't need to memorize anything. Just tell Claude what you need — "I'm
stressed about making payroll," "a customer is angry," "what should I
charge?" — and it figures out the right workflow and walks you through it.
Every workflow pauses before taking action, so nothing happens without
your say-so.

> **Important**: This plugin assists with small business workflows but
> does not provide financial, tax, legal, or HR advice. All outputs should
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
<https://mcp.paywhere.com>) and QuickBooks, and run a demo recipe.

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
server root URL:

```
https://mcp.paywhere.com
```

(Root URL only — claude.ai appends the protocol path itself.)

For QuickBooks / HubSpot / Canva / etc., add each one separately as
its own custom connector. The full URL list lives in
[`.mcp.json`](.mcp.json).

## What you'll need to connect

Run `/smb-onboard` or ask Claude to "set me up."

**Core tools** (connect these first for the best experience):
- **Paywhere** — your bank. Powers cash position, settled bank lines, and
  the reconciliation flow at the heart of month-end close. Connect via
  OAuth at <https://mcp.paywhere.com>.
- **QuickBooks** — your books. Powers the bookkeeping layer (AR, AP,
  P&L, invoice register) that Paywhere reconciles against.
- **HubSpot** — CRM, leads, campaigns, and customer support tickets.

**Marketing & communication:**
- **Canva** — generates on-brand social and email assets
- **Gmail / Outlook** — email drafts, ticket handling, contract review
- **Google Calendar / Outlook Calendar** — meeting prep, call blocking, weekly commitments
- **Slack** — brief delivery and notifications

**Optional** (adds depth when connected):
- **Google Drive / OneDrive** — file storage and templates
- **DocuSign** — contract review from pending envelopes
- **Intercom** — open tickets in customer pulse

You don't need all of these to start. Connect Paywhere + QuickBooks and
you'll immediately see value — the plugin tells you when connecting another
tool would unlock more.

## How it works

Three layers working together:

1. **Skills** — the building blocks. Each skill knows how to do one thing
   really well (forecast cash, score leads, draft an invoice reminder).
   There are 15 of these.

2. **Commands** — the workflows. Commands chain skills together into
   multi-step recipes with checkpoints where you approve before anything
   happens. There are 15 of these.

3. **The Router** — the front door. You talk to Claude in plain English.
   The router listens, figures out which workflow fits, and gets you
   there. You never need to memorize a command name.

## All 15 commands

Commands are workflows that chain skills together. Each one pauses at
checkpoints for your approval before taking action.

### Money & finance

| Command | What it does | Just say... | Skills used | Required | Optional |
|---|---|---|---|---|---|
| `/plan-payroll` | Cash forecast + overdue invoice chase so you know payroll is covered. | "can I make payroll", "cash is tight", "who owes me money" | cash-flow-snapshot, invoice-chase | QuickBooks, Paywhere | Mail |
| `/month-heads-up` | 30-day cash outlook with early risk flags. | "what does next month look like", "cash forecast", "runway" | cash-flow-snapshot | QuickBooks | Paywhere |
| `/close-month` | Month-end close: reconcile Paywhere bank lines vs QuickBooks, flag gaps, write P&L, export close packet. | "close the books", "month-end", "reconcile" | month-end-prep | QuickBooks, Paywhere | — |
| `/price-check` | Margin-by-product table and three pricing scenarios. | "what are my margins", "should I raise prices", "cost per unit" | margin-analyzer | QuickBooks | — |
| `/tax-prep` | Tax prep materials for your accountant (quarterly estimates or year-end 1099s). | "tax stuff", "estimated taxes", "1099s", "accountant needs..." | tax-season-organizer | QuickBooks | Paywhere |

### Sales & marketing

| Command | What it does | Just say... | Skills used | Required | Optional |
|---|---|---|---|---|---|
| `/call-list` | Top 5 leads to call today with talking points and calendar blocks. | "who should I call", "any hot leads", "pipeline" | lead-triage | HubSpot | Mail, Google Calendar |
| `/run-campaign` | End-to-end campaign: sales analysis → content brief → Canva assets → HubSpot send. | "run a campaign", "sales are down", "I need more customers" | content-strategy, canva-creator, lead-triage | HubSpot, Canva | QuickBooks |
| `/sales-brief` | Top and bottom sellers with a 2-week content brief. | "what's selling", "what should I promote" | content-strategy | QuickBooks | HubSpot |

### Customers & operations

| Command | What it does | Just say... | Skills used | Required | Optional |
|---|---|---|---|---|---|
| `/customer-pulse-check` | Customer feedback themes with response templates. | "what are customers saying", "complaints", "reviews" | customer-pulse, ticket-deflector | HubSpot or Intercom or Gmail | — |
| `/handle-complaint` | End-to-end complaint resolution: pull context, draft response, suggest operational fix. | "a customer is upset", "handle this complaint", "angry email" | ticket-deflector, customer-pulse | -- (works with pasted text) | Gmail, HubSpot, Paywhere |
| `/crm-cleanup` | HubSpot hygiene: stale deals, duplicates, missing fields — fixes what you approve. | "clean up the CRM", "HubSpot is a mess", "stale deals" | crm-maintenance | HubSpot | -- |
| `/review-contract` | Plain-English contract review with red flags and severity ratings. | "review this contract", "NDA", "should I sign this" | contract-review | -- (works with file upload) | DocuSign |

### Business intelligence

| Command | What it does | Just say... | Skills used | Required | Optional |
|---|---|---|---|---|---|
| `/monday-brief` | Monday morning briefing: cash, sales, pipeline, week ahead, top 3 to-dos. | "Monday brief", "what's on my plate", "start of week" | business-pulse | -- (degrades gracefully) | QuickBooks, Paywhere, HubSpot, Calendar, Gmail, Slack |
| `/friday-brief` | Friday end-of-week pulse: revenue vs last week, wins, and things to watch. | "end of week", "how'd we do", "Friday recap" | business-pulse | QuickBooks or Paywhere or HubSpot | -- |
| `/quarterly-review` | Full QBR narrative: revenue, margin, customer health, opportunities, risks. | "quarterly review", "board deck", "QBR" | business-pulse | QuickBooks | Paywhere, HubSpot |

## All 15 skills

Skills are the atomic building blocks. Each one does one thing well.

### Money & finance

| Skill | What it does | Just say... | Required | Optional |
|---|---|---|---|---|
| **cash-flow-snapshot** | 30/60/90-day cash forecast with confidence bands and named risk flags. Chat summary + XLSX. | "forecast my cash flow", "will I make payroll", "runway", "cash crunch" | QuickBooks, Paywhere | CSV upload |
| **invoice-chase** | Drafts overdue-invoice reminders matched to each customer's payment history and tone. Cross-references Paywhere credits so customers who already paid don't get chased. | "who owes me money", "overdue invoices", "follow up on unpaid" | QuickBooks, Paywhere | Gmail |
| **margin-analyzer** | Unit economics by product or service with inflation benchmarks and three pricing scenarios. | "what are my margins", "should I raise prices", "costs eating into profit", "what to charge" | QuickBooks | CSV upload |
| **month-end-prep** | Month-end close: reconciles QB transaction register against Paywhere bank lines, flags gaps, writes P&L narrative, exports close packet. | "close the month", "reconcile", "P&L", "why revenue changed" | QuickBooks, Paywhere | — |
| **tax-season-organizer** | Quarterly estimated tax calc or year-end 1099-NEC prep with accountant handoff packet. | "quarterly taxes", "estimated tax payment", "1099s", "1099-NEC", "year-end tax prep" | QuickBooks | Paywhere |

### Sales & marketing

| Skill | What it does | Just say... | Required | Optional |
|---|---|---|---|---|
| **lead-triage** | Scores HubSpot leads by engagement, fit, and urgency to produce a ranked call list with talking points. | "prioritize leads", "who to call first", "pipeline" | HubSpot | Gmail, Google Calendar |
| **content-strategy** | Analyzes QuickBooks sales data to find top performers and slow movers, produces a prioritized 30-day content brief. | "what should I post", "content plan", "what's selling", "what to promote" | QuickBooks | HubSpot |
| **canva-creator** | Takes a content brief and executes the full campaign: posting calendar, Canva assets, caption copy, HubSpot staging. | "make the content", "generate the posts", "create the assets", "turn this into a campaign" | Canva, HubSpot | -- |

### Customers & operations

| Skill | What it does | Just say... | Required | Optional |
|---|---|---|---|---|
| **customer-pulse** | Aggregates HubSpot tickets, Intercom conversations, Gmail sentiment, and reviews into a themes report with a "do these three things this week" list. | "how are customers feeling", "what people are saying", "review analysis" | -- (degrades gracefully) | HubSpot, Intercom, Gmail |
| **ticket-deflector** | Reads a customer email or ticket, cross-references Paywhere credits to confirm payment status, drafts a tone-matched reply. Can stage a Paywhere refund for owner approval. | "draft a response", "answer this customer", "where's my order", "I want a refund" | Paywhere, HubSpot, Mail | Intercom |
| **crm-maintenance** | Keeps HubSpot current: creates/updates contacts and deals, logs calls and notes, flags stale records. | "update the CRM", "log a call", "clean up HubSpot", "add context to a deal" | HubSpot | Gmail, Google Calendar |
| **contract-review** | Plain-English contract review with risk flags, severity ratings, and a marked-up redline DOCX. | "review this contract", "what am I signing", "flag any concerns", "check the payment terms" | -- (works with file upload) | Gmail, DocuSign |

### Hiring

| Skill | What it does | Just say... | Required | Optional |
|---|---|---|---|---|
| **job-post-builder** | Builds a complete hiring packet: job post, structured interview guide with scoring rubric, and offer letter template. | "help me hire", "write a job post", "job description", "open role", "interview questions", "draft an offer letter" | -- (works standalone) | DocuSign, Google Drive |

### Business intelligence & onboarding

| Skill | What it does | Just say... | Required | Optional |
|---|---|---|---|---|
| **business-pulse** | One-page business snapshot: cash, sales, pipeline, commitments, watch-list, and the single most important thing needing attention today. | "how's the business doing", "snapshot", "weekly summary", "catch me up" | -- (degrades gracefully) | QuickBooks, Paywhere, HubSpot, Google Calendar, Gmail, Slack |
| **smb-onboard** | Walks you through connecting tools, runs a demo recipe, captures your business context, and sets a weekly check-in cadence. | "set me up", "setup", "get started", "help me get set up", "I'm new to this", "what can you do" | -- | All connectors |

## Demo

The three flows below run end-to-end against a seeded QuickBooks sandbox
company paired with a seeded Paywhere mock-dev environment. See
[`demo/seed.md`](../demo/seed.md) in the marketplace root for setup notes.

- **`/close-month`** — reconciles a month of Paywhere bank lines against
  the QBO register, flags two seeded discrepancies (one missing-in-QB
  interest credit, one $1.20 wire fee delta), produces a P&L narrative,
  and exports the close packet.
- **`/plan-payroll`** — pulls QBO AR/AP and Paywhere balances, runs the
  30/60/90 forecast, surfaces an April-15 payroll crunch, and stages a
  ranked invoice-chase batch as Gmail drafts.
- **`/monday-brief`** — cross-connector synthesis: QBO revenue trend,
  Paywhere balances + 7-day inflow, a $2,000+ wire pending past its
  same-day clearing window, HubSpot pipeline movement, calendar
  commitments.

## Customizing

These workflows are generic starting points. They become much more useful
when you customize them for how your business actually works:

- **Add business context** — Drop your industry, products, customers, and
  processes into skill files so Claude understands your world.
- **Adjust thresholds** — Tune the alert thresholds in `business-pulse`
  and `cash-flow-snapshot` to match your scale.
- **Swap connectors** — Point skills at the tools you actually use.
