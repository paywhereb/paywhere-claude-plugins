---
name: friday-brief
version: 1.0.0
description: >
  The Friday end-of-week pulse: cash actually collected this week vs last
  (bank), booked revenue vs prior week (books), top and bottom services or
  customers, wins, and watches — including this week's merchant settlements
  that do not match the books gross-to-net, fee lines the bookkeeper did not
  post, debit-card purchases not yet recorded, and whether this week's
  sales-tax sweep is staged. Reads only; saves the brief to the working
  folder. Accepts an optional lookback of 7 or 14 days. Use when the owner
  says "end of week," "how'd we do this week," "Friday recap," or "Friday
  brief."
allowed-tools: Read, WebFetch, Bash
---

Run the Friday wins-and-watches briefing. Pull the numbers, surface what
matters, give the owner a clean end-of-week picture. Nothing here moves
money or writes to the books; the sweep and any drafts are other skills.

Parse arguments:
- `--lookback` (default: `7d`) — `7d` for one week or `14d` for a two-week rolling comparison

Resolve "this week" from the actual current date (Monday through today).

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Revenue pulse"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

## Step 1 — Revenue pulse

Using the `business-pulse` skill's data map:

1. **Cash in** — Paywhere `query_transactions {direction: "credit", dateFrom:
   <lookback start>}` on the operating account; the same window one period
   earlier for the delta. Label it "collected", distinct from booked.
2. **Booked revenue** — quickbooks `get_profit_and_loss` for the window vs the
   prior window (or `search_invoices` by date when the window is sub-month).
3. Top 3 revenue sources (service line, customer or job class) by contribution.

## Step 2 — Sales breakdown

1. Top 5 services/customers by revenue this period.
2. Bottom 3 (moved less than expected vs the prior period).
3. Anything with a >20% swing.

## Step 3 — Bank-vs-books checks for the week (the watches the bank supplies)

Run the three `month-end-prep` checks scoped to this week (method in
[`../month-end-prep/SKILL.md`](../month-end-prep/SKILL.md)):

- **Gross-to-net settlement matching** — each merchant settlement in the bank
  (`INTUIT PYMT SOLN DEPOSIT`, net) vs the QBO deposit it should match
  (gross − fee line). Unmatched or short → a watch with the difference.
- **Unposted fee lines** — a QBO deposit whose net equals the bank credit
  plus a fee-sized gap, with no negative "Merchant Fees" line → name it.
- **Unrecorded card purchases** — `POS DEBIT` rows this week with no QBO
  purchase (amount ± $0.50, ± 3 days) → count and total.

Plus the **tax line**: sales tax inside this week's received payments (the
[`../tax-sweep-agent`](../tax-sweep-agent/SKILL.md) method) and whether a
`TRANSFER TO TAX RESERVE` credit or a staged sweep exists for this week. If
neither, the watch is "Friday sweep not staged — run the tax sweep".

## Step 4 — Wins and watches summary

```
Friday Brief — {date}

Collected this week: ${amount} ({+/-}X% vs last week)   ·   Booked: ${amount} ({+/-}Y%)

WINS
• {win 1}
• {win 2}
• {win 3}

WATCHES
• {settlement/fee/unrecorded-card item} — {recommended action: e.g. "have the bookkeeper post the fee line"}
• {tax sweep this week ${x} — staged / not staged → run the tax sweep}
• {other watch} — {recommended action}
```

Save the brief as `briefs/friday-YYYY-MM-DD.md` in the working folder and say
where it went.

## Connector failures

Run with whatever is connected. QuickBooks missing → collected-cash only,
skip the bank-vs-books checks and say so. Paywhere missing → booked revenue
only, no checks. Neither → stop: "No revenue sources connected."

## Approval gates

- **Never send or post this brief.** Display it, save the file.
- **Never stage or move anything from here.** The sweep is `tax-sweep-agent`
  / `tax-reserve-check`; drafts are `invoice-chase`.
- **Never write to QuickBooks** — the fee-line and purchase fixes are narrated.
