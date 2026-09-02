---
name: cash-flow-snapshot
version: 1.0.0
description: >
  The forecast engine: a 13-week direct-method cash forecast built from the
  bank and the books — opening Operating balance (Tax Reserve and Business
  Savings excluded), open invoices timed by each customer's real payment lag,
  seasonality from 12 months of bank inflows, open bills at their due dates,
  payroll from the bank's debit pattern, recurring debits, the sales-tax
  remittance and every dated obligation on Google Calendar. Reports the
  week-by-week table, the minimum-balance week, the reserve to keep, and the
  historically strongest and weakest months; hands levers to what-if and
  writes the same formula-driven Excel model the dashboard uses. Read-only.
  Use when the owner says "13-week cash forecast," "forecast my cash,"
  "30/60/90-day cash flow," "what's my minimum balance," "how much reserve
  should I keep," "strongest and weakest months," "cash crunch," "runway,"
  or "will I run short."
---

# Cash Flow Snapshot (13-week direct method)

Cash forecasting for an owner who wants one number: *how low does it get, and
when.* Everything is built from what actually clears at the bank plus what the
books say is owed and due; nothing is a percentage-of-revenue guess where a
dated fact exists. This skill reads only — it stages no payments and writes
no bookkeeping. Levers ("what if…") live in [`../what-if`](../what-if/SKILL.md)
and in the Excel model this skill writes.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Opening position"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

## Step 1 — Opening position (bank)

- `list_accounts` → identify roles by name/type/`isPrimary`: **Operating**
  (primary checking), **Tax Reserve** (savings named for tax), **Business
  Savings** (the other savings). Never hardcode account numbers.
- `get_account_balance` on each. **Opening balance = Operating only.** State
  in the output that the Tax Reserve (sales tax the business is holding for
  the state) and Business Savings (the owner's cushion) are excluded from
  every week of the forecast. If the reserve is short of what has been
  collected (see [`../tax-reserve-check`](../tax-reserve-check/SKILL.md)),
  the catch-up transfer appears as an Operating outflow in week 1.
- `query_transactions {status: ["pending"]}` → pending card authorizations
  reduce week 1.
- Resolve "today" from the actual current date. Week 1 starts today and ends
  the coming Sunday; weeks 2–13 are Monday–Sunday.

## Step 2 — Expected inflows, by week

1. **Open invoices (books):** `search_invoices` with open balance > 0. Place
   each invoice's open balance in the week of **due date + that customer's
   mean payment lag**. The lag comes from the customer's 12-month history
   (`search_payments` matched to `search_invoices`; method in
   [`../ar-health`](../ar-health/SKILL.md)). Fewer than 3 paid invoices →
   use the population mean and say so. Invoices already past due + lag land
   in week 1 or 2, not "now" — an overdue customer does not pay because the
   forecast wants them to.
2. **Received-but-unbooked credits:** a recent bank credit whose invoice is
   still open in the books is already in the opening balance — drop that
   invoice from inflows (never count it twice).
3. **Recurring agreement billing:** if invoices recur monthly for the same
   customers (same amount on the 1st), project the next 1–3 cycles for weeks
   beyond the open-invoice horizon, timed by the same lag.
4. **Seasonality for the far weeks:** `query_transactions {aggregate: true,
   groupBy: "month", dateFrom: <12 months ago>, direction: "credit"}` on
   Operating gives 12 monthly inflow totals. For weeks not covered by open
   invoices or recurring billing, use the same calendar month's inflow a year
   ago, scaled by the trailing-3-month growth ratio, spread evenly by week.
   Label those weeks "seasonal estimate".

## Step 3 — Scheduled outflows, by week

1. **Open bills (books):** `search_bills` open → place at **due date**, not
   at the date the owner would habitually pay. If the owner's history shows
   habitually-early payment for a vendor, note the bill is "modeled at due
   date; you usually pay it {n} days early" (method in
   [`../ap-timing`](../ap-timing/SKILL.md)).
2. **Payroll (bank):** `query_transactions {direction: "debit",
   descriptionContains: "<payroll processor>", dateFrom: <10 weeks ago>}`.
   Take the last two runs (net + tax lines together), infer the biweekly
   cadence and project each pay Friday in the window. Use the processor name
   the bank rows actually carry.
3. **Recurring debits (bank):** from 12 months of descriptors find debits
   that repeat monthly with a stable stem (rent, utilities, insurance,
   software, subscriptions, loan/lease payments). Project each at its usual
   day of month. Method in
   [`../subscription-audit`](../subscription-audit/SKILL.md).
4. **Sales-tax remittance:** the 20th of each month in the window, amount =
   what the reserve check says is owed for that period (debits the Tax
   Reserve — so it is NOT an Operating outflow — but the Friday sweeps that
   fund it ARE). Model the sweeps: each Friday, sales tax on that week's
   received payments moves Operating → Tax Reserve.
5. **Google Calendar — dated obligations:** `list_events` (and
   `search_events` for "tax", "payroll", "estimate", "insurance", "payment",
   "closing", "due") over the 13 weeks. Events with an amount in the title or
   description become outflows on their date: quarterly owner estimates,
   insurance renewals, permit fees, project subcontractor milestones, a
   dealer appointment with a down payment, a bank meeting. An event without
   an amount is listed as "dated, unquantified — confirm". Calendar is
   read-only here; no invites, no reminders unless asked.
6. **Owner-stated items:** anything the owner names that is in none of the
   systems (a distribution, a purchase) — include, labeled owner-stated.

## Step 4 — Build the table and the three answers

```
Week  Start       Inflow    Outflow   Close     Notes
 1    2026-09-02  $…        $…        $…        payroll Fri; reserve catch-up
 2    2026-09-07  …
 …
13    …
```

- **Minimum balance:** the lowest weekly close, its week, and the two items
  that put it there.
- **Reserve to keep:** the largest **two-consecutive-week outflow total** in
  the window minus the inflows those same two weeks can be relied on for
  (open invoices from prompt payers only). Say that this is the method; the
  owner can pick a different rule. Compare it to the minimum balance: if the
  minimum is below the reserve to keep, that is the headline.
- **Strongest / weakest months:** from the 12 monthly bank aggregates
  (credits − debits per month), name the top two and bottom two calendar
  months with their net, and derive month-end Operating balances (current
  balance minus the net of every later month) so the historical lows have
  dates and amounts.

## Step 5 — Confidence and sources

One short block: which weeks rest on open invoices (firm), recurring billing
(likely), seasonal estimate (soft); whether the calendar was readable; which
customers' lags were defaulted. No confidence bands — the direct method is
auditable line by line instead.

## Step 6 — Levers (hand-off)

List the levers available without running them: collect faster, largest
customer late, revenue ±%, pay-on-due, hire, big purchase (cash / financed),
line of credit. Say "run `what-if` to see each lever's effect on the minimum
balance" — [`../what-if`](../what-if/SKILL.md) applies them to this table.

## Step 7 — Write the model (once per run)

Write `models/cash-13w.xlsx` into the working folder with Cowork's file
tooling, laid out exactly as
[`reference/model-layout.md`](reference/model-layout.md) specifies. The lever
cells are inputs; every forecast cell is a formula that references them, so
the owner can play with the model offline. `build-cash-dashboard` writes the
same file; `daily-cash-brief` refreshes it. Offer once to also produce the
HTML dashboard ([`../build-cash-dashboard`](../build-cash-dashboard/SKILL.md)).

## Degraded modes

| Missing | Effect |
|---|---|
| Paywhere | Stop for the forecast proper — there is no cleared opening balance. Offer a books-only estimate, labeled as such, from the QuickBooks bank register. |
| quickbooks | Bank-only forecast: recurring debits, payroll, seasonality; inflows are all "seasonal estimate"; say AR/AP timing is missing. |
| google calendar | Skip dated obligations; list the categories the owner should check by hand. |
| everything | One-line CSV fallback: accept a transactions export and run Steps 3.3 and 4 on it, clearly labeled. |

## Approval gates

None — read-only. Close with: "Built from cleared bank data and open
items in the books; not accounting advice — check timing assumptions with
your bookkeeper before acting on them."

## Reference files

- [`reference/model-layout.md`](reference/model-layout.md) — sheet-by-sheet
  layout and formulas for `models/cash-13w.xlsx` (shared with
  `build-cash-dashboard`)
- [`reference/gotchas.md`](reference/gotchas.md) — known failure modes
