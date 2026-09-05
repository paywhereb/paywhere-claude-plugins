# Method

The bridge is the indirect cash-flow statement for one bank account, built from two balance-sheet snapshots and one P&L. `Δ` below is always `end of M − end of M−1`, read from `get_balance_sheet {end_date: M-end}` and `get_balance_sheet {end_date: (M−1)-end}`.

## Balance-sheet rows → bridge lines

| Bridge line | Balance-sheet rows (QuickBooks names vary; match by section) | Sign on cash |
|---|---|---|
| Receivables | Accounts Receivable (A/R) | −Δ |
| Undeposited funds / other current assets | Undeposited Funds, Payments to deposit, prepaids, employee advances | −Δ |
| Inventory | Inventory Asset | −Δ |
| Equipment / fixed assets | Fixed Assets at cost (vehicles, equipment, leasehold), **excluding** Accumulated Depreciation | −Δ |
| Depreciation | P&L depreciation/amortization expense (equals −Δ Accumulated Depreciation) | + |
| Payables & cards | Accounts Payable (A/P), Credit Cards | +Δ |
| Sales tax & other current liabilities | Sales Tax Payable (one row per agency), payroll liabilities, customer deposits, accrued expenses | +Δ |
| Loans | Long-term liabilities, lines of credit | +Δ |
| Owner distributions | Equity: Owner Draws / Distributions / Owner's Pay & Personal Expenses (any contribution row nets against it) | −Δ (a draw makes the row more negative; show the cash effect) |
| Moved to reserve / savings | Bank rows other than Operating (Tax Reserve, Business Savings): their Δ left Operating as transfers, plus interest earned there | −Δ |
| Change in Operating (books) | the Operating bank row | = Σ of the above |

Retained Earnings and the current-year Net Income equity rows are not lines: they are the P&L already counted.

## Footing

```
net income + depreciation + Σ(signed Δ lines) + residual = Δ Operating (books)
```

Present each line as its effect on cash. If |residual| > 5% of the month's revenue, a section was missed — usually an equity row, a loan, or a bank row not mapped to Operating. If still unexplained, show it as "unexplained".

## Books vs bank

`query_transactions {accountNumbers:[Operating], dateFrom: M-01, dateTo: M-end, aggregate: true, includeTransactions: true, sort: "amount_desc", limit: 20}` returns `aggregate.net` over all posted rows (the bank's change in Operating for the month) and the 20 largest rows. Pending rows are excluded; say so if any exist.

`Δ Operating (books) − aggregate.net` is the books-vs-bank gap. Causes, most to least common: bank fees or interest not yet booked; a deposit in transit dated across the month boundary (merchant settlements land T+1/T+2); a payment entered in the books on a date other than the day it cleared; a duplicate or missing entry. Report the gap as its own line with the likely cause; never fold it into the residual.

## Dating the big lines

The 20 largest rows give the day the draw, tax payment, reserve transfer or equipment purchase cleared. Quote the date next to the line. Payroll and vendor rows are already inside net income and are not bridge lines; skip them unless the owner asks "when".
