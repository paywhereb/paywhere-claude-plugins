# Connector Query Guide

The exact calls per mode, what to capture, and the paste-in fallback when a
connector is missing. All reads; nothing here writes to the books or moves
money.

---

## Quarterly mode — 3 calls in one turn

**QuickBooks:** `get_profit_and_loss` from January 1 of the tax year through
the last day of the most recently completed quarter. Capture:

- `Total Income` (gross revenue)
- `Total Expenses`
- `Net Ordinary Income` (= income − expenses; the basis for the estimate)

If the report lists several income or expense groups, use the totals. If the
report states its basis, note it: cash basis is what most estimates use; on
accrual, say the accountant should confirm.

**Paywhere:** `list_accounts` (Operating by role — primary checking), then
`query_transactions {accountNumbers: [Operating], direction: "debit",
descriptionContains: "IRS", dateFrom: <Jan 1 of the tax year>}`. Estimated
payments made through the federal system carry `IRS`, `EFTPS` or
`USATAXPYMT` in the descriptor; one retry with a second stem is allowed if
the first returns nothing (say it is the fourth call). Sum the debits found
as "payments made"; list each with its date.

---

## Year-end mode — 5 calls in one turn, optional 6th

**QuickBooks:**

- `search_vendors` — capture vendor name, the `is1099` flag, and whether a
  tax id is on file (that is the W-9 evidence).
- `search_bill_payments` for the tax year — total per vendor.
- `search_purchases` for the tax year — checks, expenses and card purchases
  booked directly to a vendor; total per vendor.

Sum both per vendor. Keep services (subcontractors, consulting, design,
legal, accounting, marketing, staffing, rent); drop goods and shipping.
Many owners never set `is1099` — do not filter on it; use it as a hint and
let the accountant classify.

**Paywhere (cross-check):**

- `query_transactions {direction: "debit", dateFrom: <Jan 1>, dateTo: <Jun 30>}`
- `query_transactions {direction: "debit", dateFrom: <Jul 1>, dateTo: <Dec 31>}`

A full year rarely fits one result; two halves do (if a half still comes
back truncated, note it in the deliverable rather than adding calls). Keep
rows whose type is ACH or wire; drop card purchases, payroll-processor
debits (they produce W-2s), and transfers between the owner's own accounts.
The counterparty is the descriptor stem (`ACH DEBIT <PAYEE>`,
`WIRE OUT <PAYEE>`). `get_transaction_detail` on at most one row whose
descriptor cannot be read.

Cross-reference each counterparty against the vendor list:

- **Matches a vendor** → confirms the record; compare the totals.
- **No vendor** → "possible contractor payment not in the books" — the
  accountant reviews it.

---

## Paste-in fallback (connector unavailable)

If a connector is missing, ask the owner for the numbers rather than adding
calls:

1. QuickBooks missing, quarterly mode: total income, total expenses, net
   ordinary income for the period (from a P&L run in the books).
2. QuickBooks missing, year-end mode: a Transaction List by Vendor export
   for the tax year, pasted or uploaded.
3. Paywhere missing: the estimated-tax payments made this year (quarterly
   mode), or the year's ACH/wire debits exported from the bank's website
   (year-end mode).

When reading a pasted export, look for these columns (names vary):

- P&L: `Description`, `Amount`, `Type` (Income / Expense)
- Vendor list: `Vendor`, `Amount`, `Date`, `Account`
- Bank export: `postDate`, `amount`, `description`, `type`

If the columns do not match, ask the owner to point at the payee-name and
amount columns.
