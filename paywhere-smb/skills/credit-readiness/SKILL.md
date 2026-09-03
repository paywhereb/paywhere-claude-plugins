---
name: credit-readiness
version: 1.0.2
description: >
  Sizes the working-capital need and packages it for the bank: the deepest
  troughs across 12 months of cleared bank balances and the 13-week forecast,
  the months the business ran short and why (receivable timing, early vendor
  payments, tax and insurance collisions, seasonal stocking), whether a line
  of credit would have bridged each low and for how many days, a card-float
  estimate from card-eligible spend, a sized request, and a one-page PDF plus
  a workbook written to the working folder. Grounded in cleared cash, not
  book balances. Read-only. Use when the owner says "what should I bring to
  the bank," "would a line of credit have helped," "how much credit do I
  need," "would a card help," "when am I most likely short," "what's my
  working capital gap," or "prepare a package for the bank."
---

# Credit Readiness

The request is built from what cleared, when it cleared and how low it
went — the facts a lender otherwise reconstructs
from statements. Nothing here moves money or writes to the books.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Twelve months of cleared
cash"), then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

## Step 1 — Twelve months of cleared cash (bank)

- `list_accounts` → Operating (primary checking); Tax Reserve and Business
  Savings are reported for context but excluded from the gap math.
- `query_transactions {aggregate: true, groupBy: "month", dateFrom: <12
  months ago>}` → monthly inflow, outflow, net. Month-end balance = current
  balance − net of every later month.
- For the three lowest month-ends, pull that month's rows
  (`query_transactions {dateFrom, dateTo}` on Operating) to find the intra-
  month low and the debits/credits around it. Resolve dates from today.

## Step 2 — Why each low happened (books + bank)

For each low, name the mechanism with figures, using the sibling methods:

| Mechanism | Evidence | Method |
|---|---|---|
| Receivable timing | Large invoices open past due in that month; the credit landed weeks later | [`../ar-health`](../ar-health/SKILL.md) |
| Early vendor payments | Bill paid N days before due in that month | [`../ap-timing`](../ap-timing/SKILL.md) |
| Collisions | Payroll + remittance + annual insurance + quarterly estimate inside 10 days | bank debits + Calendar (`search_events`) |
| Seasonal stocking / equipment | Parts and equipment debits far above the monthly norm | [`../cash-bridge`](../cash-bridge/SKILL.md) |

## Step 3 — Forward view

Run or reuse [`../cash-flow-snapshot`](../cash-flow-snapshot/SKILL.md) for the
13-week minimum and the reserve to keep; note weeks below the reserve.

## Step 4 — Size it (method in `reference/sizing.md`)

- **Working-capital gap** = reserve to keep − the deepest balance observed
  (historical intra-month low or forecast minimum, whichever is lower), floor 0.
- **Months short** = every month whose low fell below the reserve to keep; name
  them and their mechanism.
- **LOC size** = gap × 1.25, rounded up to the nearest $5,000. For each low,
  "would a LOC have helped": the draw needed and how many days until inflows
  would have repaid it (the next receipts above the normal run-rate).
- **Card float** = average monthly card-eligible spend (debits whose
  descriptor stems are `POS DEBIT` / `RECURRING DEBIT` and vendors that
  accept cards) × 25/30 → the cash a business card would defer by a cycle.
- **Repayment source** = the strongest months' average net inflow.

## Step 5 — Write the package (working folder, Cowork file tooling)

**`bank/credit-readiness-YYYY-MM-DD.pdf`** — one page:
1. Business summary (legal name, owner, what it does, employees — from the
   books' company info and the owner; no invented facts).
2. 12-month cleared cash: table of month · inflow · outflow · net · month-end.
3. Lows and causes: date · low balance · mechanism · what would have bridged it.
4. Request: LOC size and purpose (seasonal working capital, vendor timing),
   optional card with the float estimate.
5. Repayment source and the 13-week minimum with the reserve to keep.
6. Footer: "Prepared from cleared bank transactions via the bank's connector
   and open items in QuickBooks; not financial advice."

**`bank/credit-readiness-YYYY-MM-DD.xlsx`** — sheets:
- `Summary` — gap, LOC size, card float, months short, 13-week minimum,
  repayment source (values with the formula text beside each).
- `Monthly cash` — `Month · Inflow · Outflow · Net · Month-end` (12 rows;
  `Month-end` as a formula: next row's month-end − next row's net, last row =
  current balance).
- `Lows` — `Date · Balance · Mechanism · Evidence · Draw needed · Days to
  repay`.
- `Forecast 13w` — the 13 rows from the forecast (week · inflow · outflow ·
  close · below-reserve flag).
- `Request` — `Product · Size · Purpose · Repayment source · Notes`.

Tell the owner the two file paths. Do not email or share the files; the
owner brings them to the meeting (Calendar `search_events` for the bank
appointment date, read-only).

## Step 6 — Say what the bank supplied

One sentence: the lows, the timing and the request size come from cleared
transactions, not the P&L — the same data the lender would ask for, already
assembled.

Close with: "Not financial advice — a lender will apply its own underwriting."

## Degraded modes

| Missing | Effect |
|---|---|
| Paywhere | Stop — there is no cleared-cash basis for a credit request. |
| quickbooks | Lows and sizing from the bank only; mechanisms limited to what descriptors show; say so in the PDF. |
| google calendar | No meeting date; ask. |

## Reference

- [`reference/sizing.md`](reference/sizing.md) — gap, LOC and float formulas, bridging test
