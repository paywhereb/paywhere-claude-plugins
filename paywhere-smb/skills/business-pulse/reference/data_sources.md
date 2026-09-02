# Data sources

Fire everything in one parallel batch. Resolve dates from the actual current date.

## Bank (Paywhere) — the facts only the bank knows

| Metric | Tool | Notes |
|---|---|---|
| Accounts and roles | `list_accounts` | Operating = primary checking; Tax Reserve = savings whose name mentions tax/reserve; Business Savings = the other savings. Never hardcode numbers. |
| Balances | `get_account_balance` per account | Report each; only Operating feeds "true available". |
| 12-month money in / out | `query_transactions {aggregate: true, groupBy: "month", dateFrom: <today − 12 months>}` | One aggregate per month per account; sum across accounts for the business, or filter to Operating. 3 accounts × 12 months is inside the 4,000-row scan cap. |
| Pending authorizations | `query_transactions {status: ["pending"]}` | Sum absolute amounts; list descriptors. |
| Last sales-tax remittance | `query_transactions {direction: "debit", descriptionContains: "DEPT OF REVENUE", limit: 3}` | The most recent date is the start of the "collected, not yet remitted" window. |
| Friday sweeps | `query_transactions {descriptionContains: "TAX RESERVE", dateFrom: <8 weeks ago>}` | Credits into the reserve; a missing Friday is a skipped sweep. |
| Payroll pattern | `query_transactions {direction: "debit", descriptionContains: "GUSTO", dateFrom: <8 weeks ago>}` | Two most recent runs → next run estimate (net + tax lines). Use the processor name the bank rows actually carry. |
| Enrichment on an odd row | `get_transaction_detail` | May be `null`; do not depend on it. |

## Books (quickbooks, read-only)

| Metric | Tool |
|---|---|
| Revenue trend | `get_profit_and_loss` (trailing 3 months, by month; a year-ago month if asked) |
| Open AR / aging | `get_aged_receivables`, `search_invoices` (open balance > 0) |
| Payments received since last remittance | `search_payments {dateFrom}` — needed for the reserve shortfall |
| Open AP | `get_aged_payables`, `search_bills` (open) |
| Vendor early-pay history | `search_bill_payments` + `search_bills` (12 months) — only if the #1-issue candidate needs it; otherwise leave to `ap-timing` |

## Calendar (google calendar, read)

`list_events` next 14 days. Relevant: payroll Friday, the 20th remittance, quarterly estimate dates, insurance renewals, dealer/bank appointments, project milestones. Read only; no invites from this skill.

## Mail (gmail, read)

`search_threads` — `is:unread newer_than:7d` plus customer-name queries for the overdue customers found in AR. Read only; drafts belong to `invoice-chase`.

## Fallbacks

| Missing | Effect |
|---|---|
| Paywhere | No true-available, no in/out, no pending; say so up top and run a books-only pulse. |
| quickbooks | Bank-only pulse: balances, in/out, pending, sweep history; AR/AP "n/a — QuickBooks unavailable". |
| google calendar | Skip the obligations overlay; note it. |
| gmail | Skip the watch list; note it. |
