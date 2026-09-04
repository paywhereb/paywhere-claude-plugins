---
name: quarterly-review
version: 1.0.0
description: >
  Full quarterly business review from the books and the bank: revenue and
  margin trend (booked vs cash actually collected), whether expenses are
  growing faster than revenue (P&L by month, direction and %), customer
  concentration, PROFITABILITY BY CUSTOMER from job costing (sub-customer
  jobs roll up to the parent; billable parts, subcontractor bills and tech
  hours against revenue), referral cost per partner and which referral
  source produces the best-paying customers, three opportunities, three
  risks, and a presentation-ready PDF saved to the working folder. Reads
  only. Use when the owner says "quarterly review," "QBR," "board deck,"
  "which customers are most profitable," "which contracts are most valuable,"
  "are expenses growing faster than revenue," or "best referral sources."
allowed-tools: Read, WebFetch, Bash
---

Run the quarterly business review. Pull financial, customer and cost data for
the quarter, synthesize a narrative, produce a presentation-ready document.
Nothing here moves money or writes to the books.

Parse arguments:
- `--quarter` (default: previous calendar quarter) — `YYYY-QN` (e.g. `2026-Q2`)

Resolve the default quarter from the actual current date.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Financial performance"),
then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

## Step 1 — Financial performance

1. quickbooks `get_profit_and_loss` for the quarter, **by month**: revenue,
   COGS, gross margin, operating expenses, net income. Same for the prior
   quarter and the same quarter a year ago if the books go back that far.
2. Paywhere `query_transactions {direction: "credit", aggregate: true,
   groupBy: "month"}` for the quarter on the operating account — cash
   actually collected — to validate booked revenue and show the collection
   lag.
3. **Expenses growing faster than revenue?** Compare the quarter-over-quarter
   % change in total expenses (and separately COGS, payroll, subscriptions)
   with the % change in revenue; state direction and the gap in points. Name
   the fastest-growing line.
4. Revenue growth %, margin change in points, top 3 revenue categories
   (agreements / repairs / replacements / projects when the books use those
   classes).

## Step 2 — Customer concentration and profitability

1. `get_customer_sales` (or invoices grouped by customer) for the quarter;
   **roll sub-customer jobs up to the parent customer** before ranking.
2. Concentration: any customer above 20% of revenue → flag; any large
   customer whose revenue dropped sharply vs the prior quarter → flag.
3. **Profitability by customer** from job costing: revenue by parent
   customer minus billable parts/equipment bills (`search_bills` with
   CustomerRef), subcontractor bills, and technician hours
   (`search_time_activities` × hourly rate) charged to that customer's jobs.
   Rank top 3 and bottom 3 by margin dollars and margin %. Where the books
   lack costing for a customer, say "revenue only — no direct costs booked".
4. **Referral cost**: the referral source lives in each customer's Notes
   (`search_customers`); referral-fee bills per partner (`search_bills` by
   vendor, memos naming the customer). Show, per partner: referred
   customers, their revenue, fees paid this quarter, margin net of fees, and
   their payment behaviour (mean days late, from `../ar-health`'s method).
   Answer "best referral source" = highest net margin **and** promptest
   payers; call out a fee paid on revenue not yet collected if the memos show
   one.

## Step 3 — Top opportunities

Three specific opportunities from the data: revenue (segment/class to double
down on, open estimates pipeline from `search_estimates`), margin (cost line
to cut or price to raise — e.g. agreement renewals), customer (segment to
target, late-payer terms to tighten).

## Step 4 — Top risks

Three specific risks: revenue (concentration, seasonality, trend), margin
(rising cost line, pricing pressure), operational/cash (a customer's payment
behaviour, vendor dependency, a stress month ahead).

## Step 5 — QBR narrative

500–800 words, plain business English: quarter headline; revenue story
(booked vs collected); margin story; expenses-vs-revenue verdict; customer
story (concentration, profitability, referrals); three opportunities; three
risks; one-paragraph call to action.

## Step 6 — Export

Write `reviews/qbr-{YYYY-QN}.pdf` in the working folder (narrative + key
tables; ASCII tables if no chart tooling is available) and, alongside it,
`reviews/qbr-{YYYY-QN}.md`. Confirm the paths.

## Connector failures

QuickBooks unreachable → stop; the QBR is built from the books. Paywhere
missing → skip cash validation and note "revenue validated from the books
only". Missing job costing → profitability section becomes revenue-only, and
the narrative says so.

## Approval gates

- **Never publish or email the QBR.** Display, then save.
- **Flag incomplete data** in the narrative rather than filling gaps.
- **Never write to QuickBooks.**

## Output

Present the narrative in-line, confirm the file paths, end with the
one-paragraph "what to focus on next quarter".
