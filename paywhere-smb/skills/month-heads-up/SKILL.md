---
name: month-heads-up
version: 1.0.0
description: >
  The next-30-days (or 60) cash outlook: weekly balances from the 13-week
  direct-method forecast with the Tax Reserve excluded from spendable cash,
  the tightest week, dated obligations pulled from the calendar (payroll
  Fridays, the 20th sales-tax remittance, quarterly estimates, insurance
  renewals) and the books (bills due), and two specific things to watch —
  which invoice to chase, which bill to hold to its due date. Reads only.
  Use when the owner says "what does next month look like," "next 30 days,"
  "month-end heads up," "runway," or "how does the month end."
allowed-tools: Read, WebFetch, Bash
---

Run the month-end heads-up. Give the owner a clear "here is what the next 30
days look like" with specific things to watch. Nothing here moves money.

Parse arguments:
- `--horizon` (default: `30`) — forecast window in days (`30` or `60`)

Resolve "today" from the actual current date.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Current cash position"),
then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

## Step 1 — Current cash position

1. Paywhere `list_accounts` → `get_account_balance` per account. Identify the
   operating account (primary checking), the Tax Reserve (savings named for
   tax) and Business Savings by name/type/`isPrimary`, never by number.
2. **Spendable cash = Operating − reserve shortfall − pending authorizations**
   (method: [`../business-pulse/reference/true-available.md`](../business-pulse/reference/true-available.md)).
   The Tax Reserve and Business Savings are shown but excluded.
3. quickbooks open AR (`get_aged_receivables`) as the incoming pool, with
   each customer's payment-lag pattern (see `../ar-health`).

## Step 2 — Upcoming obligations (books + calendar + bank)

1. **Books**: `search_bills` (open) due inside the horizon; recurring
   vendors from the last 3 months of `search_purchases` / `search_bill_payments`.
2. **Calendar**: `list_events` for the horizon — payroll Fridays, the 20th
   sales-tax remittance (KS + MO, amount from `tax-reserve-check`),
   quarterly owner estimate dates, insurance renewals, project milestones.
3. **Bank**: recurring debits the books may lack — the payroll processor's
   last two runs (net + tax) for the next-run estimate, subscriptions,
   auto-debits (see `../subscription-audit`).
4. Flag any obligation that would push spendable cash below the comfort
   buffer (default: one average week of outflow, from the bank's 12-month
   aggregate).

## Step 3 — Cash-flow forecast

Run the 13-week direct-method engine in
[`../cash-flow-snapshot/SKILL.md`](../cash-flow-snapshot/SKILL.md) and take the
weeks inside the horizon: expected inflows (open AR shifted by each
customer's lag), scheduled outflows (step 2), weekly closing balance with the
Tax Reserve excluded. Identify the tightest week and whether any week goes
negative.

## Step 4 — Two things to watch

No more than two, each specific and actionable:
- Which invoice(s) to chase now — the one whose arrival lifts the tightest
  week the most (→ `invoice-chase`, drafts only).
- Which bill to **hold to its due date** rather than pay early, and what that
  buys the tightest week (→ `ap-timing`); or which discretionary expense to
  defer.

```
Month-End Heads Up — {current date}
Horizon: next {X} days

Spendable today: ${amount}  (Operating ${a} − reserve shortfall ${b} − pending ${c}; Tax Reserve ${r} and Savings ${s} excluded)
Projected end-of-period: ${amount}
Tightest week: {date range} — projected ${amount}   {⚠ negative / ok}

Dated obligations: {Fri} payroll ≈ ${p} · {20th} sales-tax remittance ${t} · {other}

TWO THINGS TO WATCH
1. {invoice} — {why} — suggested action: {chase → invoice-chase}
2. {bill} — {why} — suggested action: {hold to {date} → ap-timing}
```

## Connector failures

QuickBooks unreachable → stop; the forecast needs the books for AR/AP. Paywhere
missing → forecast from books only, labelled "no real-time balance — book
cash as proxy; reserve exclusion not applied". Calendar missing → dated
obligations from books and bank only; say so.

## Approval gates

- **Never initiate payments, transfers or emails.** Surface actions only.
- **Never count the Tax Reserve or Business Savings as spendable.**
- **Never project revenue not in the books or the bank.**

## Output

Present the brief and offer to run `invoice-chase` (drafts) or `ap-timing`
for the two watches.
