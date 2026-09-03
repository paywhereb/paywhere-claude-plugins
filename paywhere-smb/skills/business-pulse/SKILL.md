---
name: business-pulse
version: 1.0.1
description: >
  One-page pulse for an owner-operated business: the three bank balances,
  TRUE AVAILABLE CASH (operating minus the sales-tax reserve shortfall minus
  pending card authorizations), 12-month money in vs money out from the bank,
  revenue trend from the books, open AR/AP, this week's dated obligations
  from the calendar, and the single most important issue right now (a late
  customer, a bill about to be paid early, an under-funded tax reserve, thin
  payroll headroom). Reads only; proposes nothing. Degrades to whatever is
  connected. Use when the owner says "how is my business doing," "how's the
  business doing," "how are we doing," "give me a snapshot," "Monday brief,"
  "weekly check-in," "catch me up," "what am I missing," or "what's coming
  in vs going out."
---

# Business Pulse

One prompt, one page. Pull live data from every connected source, lead with
the bank facts only the bank knows (what cleared, what is pending, what sits
in the tax reserve), and end with one thing to act on. Do the work; never ask
the owner to help find the data. Nothing here moves money or writes to the
books.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Pull in parallel"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

## Step 1 — Pull in parallel

Fire every call in one batch (see `reference/data_sources.md` for the exact
mapping). Resolve "today" from the actual current date.

- **Paywhere (bank)** — `list_accounts` (identify operating = primary
  checking, tax reserve = the savings account named for tax, savings = the
  other savings account — by name/type/`isPrimary`, never by number);
  `get_account_balance` per account; `query_transactions {aggregate: true,
  groupBy: "month", dateFrom: <12 months ago>}` for money in vs out;
  `query_transactions {status: ["pending"]}` for pending authorizations;
  `query_transactions {direction: "debit", descriptionContains: "DEPT OF
  REVENUE", limit: 3}` for the last sales-tax remittance date.
- **quickbooks** — `get_profit_and_loss` (trailing 3 months, by month),
  `get_aged_receivables`, `search_invoices` (open), `get_aged_payables`,
  `search_bills` (open), `search_payments` for the months not yet remitted
  (the 20th remittance pays the previous month: before the 20th that is last
  month + this month, on/after the 20th this month — see
  [`../tax-reserve-check/reference/method.md`](../tax-reserve-check/reference/method.md)).
- **google calendar** — `list_events` for the next 14 days (payroll, the
  20th remittance, estimates, dealer/bank appointments).
- **gmail** — `search_threads` for urgent/unread customer threads (7 days).

A connector that errors removes its section; note it in the appendix and
keep going. Never retry in a loop, never ask the owner to reconnect
mid-pulse.

## Step 2 — Compute

1. **Balances** — one line per account with the account's role.
2. **True available cash** — the headline. See `reference/true-available.md`.
   ```
   Operating balance
   − sales-tax reserve shortfall   (tax collected on RECEIVED payments not yet remitted − Tax Reserve balance, floor 0)
   − pending card authorizations
   = true available
   ```
   Business Savings is reported but never counted as available. If
   QuickBooks is down, show the reserve balance and say the shortfall could
   not be computed (the sweep history from the bank still tells you whether
   recent Fridays were skipped).
3. **Money in vs money out** — the 12 monthly aggregates from the bank:
   average monthly inflow and outflow, the best and worst months (name them),
   and the trailing-3-month net. Label it "cash actually cleared", distinct
   from booked revenue.
4. **Revenue trend** — last full month vs prior month and vs the same month
   a year ago if the books have it; MTD run-rate.
5. **AR** — open total, overdue total, the largest overdue invoice (customer,
   amount, days past due, and how that customer usually pays if the payment
   history shows a pattern — see `../ar-health`).
6. **AP** — open total, due within 7 days, and any open bill not yet due
   whose vendor the owner habitually pays early (see `../ap-timing`).
7. **Payroll headroom** — if a payroll debit pattern exists in the bank
   (`GUSTO` or the processor name), estimate the next run from the last two
   and show true available − next payroll.

Assign 🟢/🟡/🔴 per section with `reference/thresholds.md`.

## Step 3 — Pick the #1 issue

Rank candidates by dollars at risk this week; present exactly one, with a
next step and the skill that does it:

| Candidate | Signal | Next step |
|---|---|---|
| Late customer | Largest overdue invoice from a routinely-late payer, no matching bank credit | "Chase it" → `invoice-chase` |
| Bill about to be paid early | Open bill due > 10 days out from a vendor with an early-payment history | "Hold it to the due date" → `ap-timing` / `pay-bills` |
| Reserve short | Reserve shortfall > 0, especially with the 20th inside 10 days | "Stage the catch-up transfer" → `tax-reserve-check` |
| Payroll thin | true available − next payroll < one week of average outflow | `plan-payroll` |
| Unknown recurring debit | A recurring debit with no matching vendor/bill | `subscription-audit` |

Cross-source synthesis is the value: a late invoice + no bank credit + an
urgent email from the same customer is one item, not three.

## Step 4 — Compose

Use `reference/output_template.md`. Numbers lead; every number carries a
delta where a prior period exists; names and dollars, never adjectives.
Include only sections with real data.

## Step 5 — Offer once

After the pulse, offer once to save it as `briefs/pulse-YYYY-MM-DD.md` in the
working folder. Do not ask again. If the owner wants this every morning
unattended, point them to `daily-cash-brief` (the scheduled version, which
also stages the day's proposals for approval).

### "Monday brief" / "weekly check-in"

Same pulse; expand the #1 issue into the **top 3 things this week**, ranked,
and save the dated file without asking.

## Scope variants

- **"Just cash"** → balances, true available, money in/out, payroll headroom.
- **"Revenue only"** → revenue trend + best/worst months.
- **"Anything urgent?"** → #1 issue + risks only.
- **"Quick snapshot before a call"** → TL;DR + #1 issue.

## What not to do

- Do not ask permission before pulling data.
- Do not invent or estimate a number a source did not return — say "n/a".
- Do not count Business Savings or the Tax Reserve as spendable.
- Do not stage or propose anything from here — hand off to the named skill.
- Do not surface connector errors mid-pulse; appendix only.

## Reference files

- `reference/data_sources.md` — tool → metric mapping and fallbacks
- `reference/true-available.md` — the reserve-shortfall method in short form
- `reference/thresholds.md` — 🟢/🟡/🔴 cutoffs
- `reference/output_template.md` — the page layout
- `reference/gotchas.md` — known failure modes
