# Paywhere SMB Plugin

Finance workflows for an owner-operated small business, run against your
**bank through the Paywhere connector** plus QuickBooks, Gmail and Google
Calendar. Tell Claude what you need in plain English — "how is my business
doing," "who do I call first," "am I good for payroll Friday," "how much of
my balance is actually mine," "can I afford the van" — and the right skill
runs. Version **1.0.13**:

| | What it is | In this plugin |
|---|---|---|
| **Assistant** | Interactive chat; skills fire from what you ask — each one runs in six tool calls or fewer and answers in about half a minute | `pay-bills`, `ap-timing`, `sweep-to-savings`, `plan-payroll`, `tax-reserve-check`, `cash-bridge`, `big-purchase-decision`, `credit-readiness`, `tax-season-organizer` |
| **Agent** | Cowork scheduled tasks that run while you're away | `daily-cash-brief` (weekdays 7:30am), `tax-sweep-agent` (Fridays 4pm) |

Plain questions need no skill: "show my balances", "what's in Operating",
"when is the next payroll", "who owes me money" are answered straight from the
connectors. Anything Claude can work out from the data — a what-if, a
forecast, a summary — it does without a skill; skills exist for procedures
worth encoding (moving money behind one approval, a reconciliation method, a
scheduled agent's contract).

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
./scripts/package.sh paywhere-smb        # → dist/paywhere-smb-1.0.13.plugin
                                         #   and dist/paywhere-smb-1.0.13-poc.plugin (Paywhere → PoC stack)
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

Say it in your own words; Cowork picks the skill from its description.
Trigger phrases are examples. Every interactive skill reads in one parallel
turn and stays within six tool calls.

### Act (one passkey approval on the bank)

| Skill | What it does | Just say… | Needs |
|---|---|---|---|
| **pay-bills** | Open bills only: overdue + due within 7 days selected, not-yet-due left for their due date, saved payees by name, a dry run, one table, then ONE mixed-rail batch (ACH + wire) staged → `/confirm` link. | "pay the bills due this week" | Paywhere + QBO |
| **plan-payroll** | Headroom = Operating − next payroll (from the bank's processor debits) − bills due by payday − reserve shortfall; stages a savings → operating top-up when short. | "am I good for payroll Friday" | Paywhere + QBO |
| **tax-reserve-check** | Sales tax collected on received payments (one `get_sales_tax_collected` call) vs the Tax Reserve; the sweeps that were missed; true available cash; stages the catch-up transfer. | "how much of my balance is actually mine", "is the tax reserve short" | Paywhere + QBO |
| **sweep-to-savings** | Safe-to-sweep = Operating − committed outflows through the next pay cycle − a buffer set by your own worst recent week − anything earmarked; stages ONE transfer to savings. | "how much can I move to savings", "how much spare cash do I have" | Paywhere + QBO |

### Know

| Skill | What it does | Just say… | Needs |
|---|---|---|---|
| **ap-timing** | Which vendors you habitually pay early and what to hold to its due date (one `get_vendor_payment_timing` call). | "am I paying anyone early", "what should I hold" | QBO |
| **cash-bridge** | Profit → cash for a month: net income, ΔAR, ΔAP, owner draws, reserve sweeps, equipment, reconciled to what cleared. | "QuickBooks says I made money, why is my cash lower" | Paywhere + QBO |
| **big-purchase-decision** | Can I afford it, cash or financed, safest months, a second unit — from today's balance, twelve month-ends from the bank, the payroll cushion and the seller's / lender's emails. Verdict first. | "can I afford the van / a new truck / this equipment" | Paywhere + Gmail |
| **credit-readiness** | Working-capital gap from twelve month-ends, the troughs and why, a sized line-of-credit request, the lender's document checklist — one markdown package in `bank/`. | "what should I bring to the bank", "how much credit do I need" | Paywhere + QBO + Gmail |
| **tax-season-organizer** | Owner income-tax prep: estimated payments, 1099 candidates, what the CPA needs, as markdown (sales tax lives in `tax-reserve-check`). | "estimated taxes", "1099s" | Paywhere + QBO |

### Run for me (Cowork scheduled tasks)

| Skill | Schedule / prompt | What it stages |
|---|---|---|
| **daily-cash-brief** | `Every weekday at 7:30am` — "Run my morning cash brief" | `briefs/YYYY-MM-DD.md` and ONE batch (reserve top-up + due bills) with the `/confirm` link |
| **tax-sweep-agent** | `Every Friday at 4:00pm` — "Run the Friday tax sweep" | `sweeps/YYYY-MM-DD.md`, the Operating → Tax Reserve transfer staged for approval |

Both stamp `sessionType: "scheduled"`, dedupe on the output file, degrade
gracefully, and never execute or send.

### Getting started

| Skill | Just say… |
|---|---|
| **smb-onboard** | "set me up", "what can you do", "how do approvals work" |

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

### Archived in 1.0.13

Nine skills left the package after an audit against three rules: a skill must
work as-is for any small business, it must encode a procedure Claude cannot
improvise from the data, and a live-demo skill must finish in six tool calls
and about thirty seconds. Archived (in
[`demo/archive/skills/`](../demo/archive/skills/), with the audit): `what-if`,
`business-pulse`, `ar-health`, `cash-flow-snapshot`, `build-cash-dashboard`,
`quarterly-review`, `smb-router`, `month-end-prep`, `subscription-audit`.
A dashboard returns only as a live artifact that calls the connectors;
`subscription-audit` returns when the bank query can group by counterparty.
Six older skills were removed in 1.0.8 and are in git history.

## How it works

1. **Skills** do one thing each and read live data — they never assume a
   record, a name or an amount.
2. **Conventions** are written once in `skills/_shared/` and repeated inline
   where they matter: propose → `/confirm` → passkey; scheduled runs propose
   and never execute; drafts only.
3. **Cowork routes** from the skill descriptions; plain questions stay plain.

## Customizing

Hold rules live in `ap-timing/SKILL.md` (the tool's definitions: paid early
= 5+ days before the due date; habitual = 3+ such bills), the reserve method
in `tax-reserve-check/reference/`, and the payroll cushion in
`plan-payroll/SKILL.md`. Bump the plugin version on any change (plugin.json +
marketplace.json + the skill's `version:`).
