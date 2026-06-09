---
name: monday-brief
description: Generates a one-page Monday morning briefing — cash, sales/revenue trend, watch-list, top three to-dos. Accepts an optional save-to argument.
allowed-tools: Read, WebFetch, Bash
---

Run the Monday Morning Briefing. Pull from every connector that's live, gracefully degrade when one isn't, and deliver a one-page brief the owner can read in under two minutes.

Parse arguments:
- `--save-to` (default `files`) — `files` (Google Drive / OneDrive), `desktop` (local), or `both`

## Step 1 — Run business-pulse

Trigger the `business-pulse` skill workflow. It pulls in this order, scoping to whatever is connected:

1. **Cash** — Paywhere balances across accounts + last 7 days of net inflow/outflow; supplement with QuickBooks cash account if available
2. **Revenue & sales trend** — QuickBooks MTD revenue vs. prior month, plus Paywhere 7-day inflow vs. prior 7
3. **Watch-list** — unread Gmail flagged "needs reply," overdue QuickBooks invoices, pending Paywhere wires/ACH past expected clearing window
4. **The 3 things** — the three highest-leverage actions for today, ranked

If a connector is missing, note it in the brief ("Paywhere not connected — cash section uses QuickBooks only") rather than failing.

## Step 2 — Format the one-page brief

Layout (markdown, fits on one screen):

```
# Monday Brief — {Mon DD, YYYY}

## Cash
{$X balance · {+/-}$Y net last 7 days · runway note}

## Revenue (this month vs prior)
{$X MTD · {+/-}Z% vs prior month · Paywhere inflow last 7d: {$X}}

## Watch-list
- {Overdue invoice / pending wire / flagged email — amount, who, why}
- ...

## Three things that need you today
1. {Highest-leverage action with one-line why}
2. {...}
3. {...}
```

## Step 3 — Save

1. Save the brief to the chosen `--save-to` location:
   - `files` — Google Drive or OneDrive root, filename `monday-brief-YYYY-MM-DD.md`
   - `desktop` — `~/Desktop/monday-brief-YYYY-MM-DD.md`
   - `both` — both locations
2. Show the full brief in chat regardless of save target.

## Approval gates

- **Saving the file is auto.** No approval needed — it's the owner's own drive.
- **Never act on a watch-list item automatically.** The brief surfaces what needs attention; the owner decides what to do.

## Cadence note

This command is designed to run weekly. The owner may schedule it via Cowork's task scheduler — when run on Monday at 7am ET, the output goes straight to their drive.
