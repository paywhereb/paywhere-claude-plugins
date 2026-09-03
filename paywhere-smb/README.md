# Paywhere SMB Plugin

Finance workflows for an owner-operated small business, run against your
**bank through the Paywhere connector** plus QuickBooks, Gmail and Google
Calendar. Tell Claude what you need in plain English — "how is my business
doing," "who do I call first," "am I good for payroll Friday," "how much of
my balance is actually mine," "can I afford the van" — and the right skill
runs. Version **1.0.7** covers the three A's:

| | What it is | In this plugin |
|---|---|---|
| **Assistant** | Interactive chat; skills fire from what you ask | `business-pulse`, `cash-bridge`, `ar-health`, `invoice-chase`, `ap-timing`, `pay-bills`, `plan-payroll`, `tax-reserve-check`, `subscription-audit`, `big-purchase-decision`, `credit-readiness`, `cash-flow-snapshot`, `what-if`, briefs and close |
| **Application** | Files Claude builds into your working folder | `build-cash-dashboard` → `dashboard/cash.html` + `models/cash-13w.xlsx` |
| **Agent** | Cowork scheduled tasks that run while you're away | `daily-cash-brief` (weekdays 7:30am), `tax-sweep-agent` (Fridays 4pm) |

**Nothing moves money from chat.** Every payment or transfer is staged as a
proposal and approved by you on the bank's `/confirm` page with a passkey.
Scheduled runs stage too; they never execute. Email is **drafts only** —
the plugin never sends. See
[`skills/_shared/APPROVAL.md`](skills/_shared/APPROVAL.md) and
[`skills/_shared/AUTONOMY.md`](skills/_shared/AUTONOMY.md).

> This plugin assists with small-business finance workflows and does not
> provide financial, tax or legal advice. Review outputs with a qualified
> professional before acting.

## Installation

The plugin system runs in **Claude Code** and **Cowork**. Claude Desktop and
claude.ai chat do not load plugins — they host raw MCP servers only (the
bare Paywhere connector, no skills).

### Cowork — side-load the `.plugin` archive

```bash
git clone https://github.com/paywhereb/paywhere-claude-plugins.git
cd paywhere-claude-plugins
./scripts/package.sh paywhere-smb        # → dist/paywhere-smb-1.0.7.plugin
```

In Cowork, use the "side-load a plugin file" picker and select the `.plugin`
file. Connect the four connectors below, pick a working folder, and start
with "set me up" (or `/demo-setup` on the hosted sandbox — see Demo setup).

### Claude Code — install from the marketplace

```
/plugin marketplace add paywhereb/paywhere-claude-plugins
/plugin install paywhere-smb@paywhere-claude-plugins
```

### Claude Desktop / claude.ai — bare connector only

Settings → Connectors → Add custom connector → your bank's Paywhere MCP URL
(`https://demo.dev.paywhere.com/mcp` on the hosted sandbox) — every Paywhere
tool works, no skills load. Add QuickBooks, Gmail and
Google Calendar the same way if you want them without the plugin.

## Connectors

Wired in [`.mcp.json`](.mcp.json):

| Connector | Role | Notes |
|---|---|---|
| **Paywhere** — `https://demo.dev.paywhere.com/mcp` | Your bank: balances, 12 months of cleared and pending activity, saved payees, ACH / wire / batch payments and transfers (staged for passkey approval), transaction enrichment | Staged moves are approved on the bank's `/confirm` page |
| **quickbooks** — `https://qbo.dev.paywhere.com/mcp` | Your books: invoices, payments, deposits, bills, bill payments, purchases, journal entries, estimates, aging, P&L, balance sheet, customers/vendors/employees | **Read-only**; skills narrate any booking they would make |
| **gmail** — `https://gmailmcp.googleapis.com/mcp/v1` | Reminder drafts; vendor invoices, quotes, payroll summaries, renewal notices as evidence | **Drafts only** — never send/reply/forward |
| **google calendar** — `https://calendarmcp.googleapis.com/mcp/v1` | Dated obligations: payroll Fridays, the 20th remittance, estimates, renewals, appointments | Read; a reminder event only when you ask, no attendees |

No Google Drive. Files are written into the Cowork working folder.

## Skills

Say it in your own words; the router (`smb-router`) picks one skill and asks
before running it. Trigger phrases are examples.

### Know where I stand

| Skill | What it does | Just say… | Needs |
|---|---|---|---|
| **business-pulse** | One page: three balances, **true available cash** (Operating − reserve shortfall − pending), 12 months in vs out, revenue trend, AR/AP, this week's obligations, the #1 issue. Doubles as the Monday brief. | "how is my business doing", "snapshot", "Monday brief", "catch me up" | any (degrades) |
| **cash-bridge** | Profit → cash: ΔAR, distributions, owner taxes, reserve sweeps, equipment, early vendor payments, reconciled to what actually cleared. | "QuickBooks says I made money, why is my cash lower", "why doesn't my bank balance move with my profit", "where did the profit go" | Paywhere + QBO |
| **ar-health** | Aging, payment-behavior profiles from 12 months of lags, DSO trend, cash-impact ranking, received-but-unbooked detection. | "who owes me money", "who pays late", "what's my DSO" | Paywhere + QBO |
| **ap-timing** | Bills due, per-vendor early-payment history, pay-when-due recommendations (hold / pay now / defer) and the effect on the minimum balance. | "what's due this week", "am I paying anyone early" | Paywhere + QBO |
| **tax-reserve-check** | Sales tax collected on received payments vs the Tax Reserve vs the 20th; missed Friday sweeps; true available; proposes the catch-up transfer. | "how much of my balance is actually mine", "what do I owe on the 20th" | Paywhere + QBO |
| **subscription-audit** | Recurring debits from 12 months of descriptors; flags zero-attribution, orphaned, duplicate, price creep; answers "what's this debit". | "what's this $__ debit", "what subscriptions am I paying" | Paywhere (+ QBO, Gmail) |

### Act (one passkey approval on the bank)

| Skill | What it does | Just say… | Needs |
|---|---|---|---|
| **pay-bills** | Bills due within 7 days + overdue, holds habitually-early vendors, saved payees by name, ONE mixed-rail batch (ACH + wire) staged → `/confirm` link. | "pay the bills due this week", "pay my bills" | Paywhere + QBO |
| **plan-payroll** | Reserve-aware headroom through Friday + 7 days; settlement detection; collect / hold / top-up options; "check again". | "am I good for payroll Friday" | Paywhere + QBO |
| **invoice-chase** | Ranked by cash impact × lateness, tone by profile, excludes received-but-unbooked; Gmail **drafts** you send. | "who do I call first", "chase overdue invoices" | QBO + Paywhere (+ Gmail) |

### Decide

| Skill | What it does | Just say… | Needs |
|---|---|---|---|
| **cash-flow-snapshot** | 13-week direct-method forecast (reserve excluded), minimum-balance week, reserve to keep, strongest/weakest months; reads the calendar for dated obligations. | "13-week forecast", "minimum balance", "runway" | Paywhere + QBO (+ Calendar) |
| **what-if** | Levers over the forecast: revenue −10%, biggest customer +30 days, hire, lose an agreement, collect faster, stop paying early, van, LOC; best combination. | "what if revenue drops 10%…" | Paywhere + QBO |
| **big-purchase-decision** | The van: quotes from Gmail, appointment from Calendar, historical lows, forecast, mileage offset → cash vs finance, safest month, second-vehicle verdict. | "can I afford to buy a van this week for $58,500", "can I afford a $X purchase", "should I pay cash or finance", "when is the safest month to buy" | Paywhere + QBO + Gmail + Calendar |
| **credit-readiness** | Working-capital gap, months short, LOC/card sizing, "would a LOC have helped"; writes the bank package (PDF + xlsx). | "what should I bring to the bank", "how much credit" | Paywhere + QBO |
| **month-heads-up** | Next 30 days from the 13-week engine; two things to watch. | "what does next month look like" | Paywhere + QBO |

### Build

| Skill | What it does | Just say… |
|---|---|---|
| **build-cash-dashboard** | `dashboard/cash.html` (single offline file: balances, true available, 13-week chart, aging, next-30-days, reserve gauge, subscriptions) and `models/cash-13w.xlsx` with formula-driven levers; optional collections tracker. Regenerated by the daily brief. | "build me a cash dashboard", "build a 13-week model in Excel" |

### Run for me (Cowork scheduled tasks)

| Skill | Schedule / prompt | What it stages |
|---|---|---|
| **daily-cash-brief** | `Every weekday at 7:30am` — "Run my morning cash brief" | `briefs/YYYY-MM-DD.md`, regenerates the dashboard, ONE batch (reserve top-up + due bills) with the `/confirm` link |
| **tax-sweep-agent** | `Every Friday at 4:00pm` — "Run the Friday tax sweep" | `sweeps/YYYY-MM-DD.md`, the Operating → Tax Reserve transfer staged for approval |

Both stamp `sessionType: "scheduled"`, dedupe on the output file, degrade
gracefully, and never execute or send.

### Books and briefs

| Skill | Just say… |
|---|---|
| **close-month** → **month-end-prep** | "close the books", "reconcile" — now with gross-to-net settlement matching, unposted fee detection, unrecorded card purchases |
| **friday-brief** | "Friday recap", "how'd we do this week" |
| **quarterly-review** | "QBR", "most profitable customers", "are expenses growing faster than revenue" |
| **tax-prep** → **tax-season-organizer** | "estimated taxes", "1099s" (owner income tax; sales tax lives in `tax-reserve-check`) |
| **smb-onboard** / **smb-router** / **conventions** | "set me up" / "what can you do" / "how do approvals work" |

### Demo setup (hosted sandbox only)

The hosted sandbox (`demo.dev.paywhere.com`) carries seeder tools that build a
per-presenter bank world for Nick's HVAC, a Kansas City owner-operator; the
shared QuickBooks sandbox, mailbox and calendar are seeded to match. The demo
persona lives in server data ([`DATASET.md`](DATASET.md)); no skill hardcodes
it.

| Skill | What it does |
|---|---|
| **demo-setup** | Builds your own Nick's HVAC bank world (async seed, polled), reads it back through the connector, reports the answer-key summary. See [`../demo/SCENARIOS.md`](../demo/SCENARIOS.md) and [`../demo/presenter-kit.md`](../demo/presenter-kit.md). |
| **demo-inject** | Ready prompts for live moments: "Westport just paid", an emergency-call settlement, a failed autopay. |

To try it: create a Cowork project, paste
[`../demo/cowork-project-prompt.md`](../demo/cowork-project-prompt.md) as its
instructions, connect the sandbox connectors, run `/demo-setup` (≈ 5 minutes),
then walk [`../demo/SCENARIOS.md`](../demo/SCENARIOS.md). The same skills run
on real accounts; what they surface depends entirely on the data present.

### Frozen (D9)

`pay-and-bill` and `pay-commissions` belong to the retired Meridian Staffing
world. They remain for reference, are not maintained, and predate the
propose-only approval path.

## How it works

1. **Skills** do one thing each and read live data — they never assume a
   record, a name or an amount.
2. **Conventions** are written once in `skills/_shared/` and repeated inline
   where they matter: propose → `/confirm` → passkey; scheduled runs propose
   and never execute; drafts only.
3. **The router** turns plain English into one skill and one confirmation.

## Customizing

Adjust thresholds in `business-pulse/reference/thresholds.md`, hold rules in
`ap-timing/reference/early-payment-method.md`, the profile cutoffs in
`ar-health/reference/profiles.md`, and the model layout in
`cash-flow-snapshot/reference/model-layout.md`. Bump the plugin version on
any change (plugin.json + marketplace.json + the skill's `version:`).
