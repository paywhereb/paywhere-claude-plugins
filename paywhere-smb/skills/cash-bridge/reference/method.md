# Method

## Month-end balances from aggregates

The bank exposes the current balance and rows, not a balance history. Derive:

```
query_transactions {aggregate: true, groupBy: "month", dateFrom: <M−1 start>, dateTo: <today>} on Operating
→ one {month, sumCredits, sumDebits, net} per month, including the current partial month

closing(current month, today)  = current balance
closing(M)                     = current balance − Σ net(k) for every month k after M (including the current partial month)
closing(M−1)                   = closing(M) − net(M)
operating cash change (M)      = closing(M) − closing(M−1) = net(M)
```

Pending rows are excluded from balances; state that. If the pull is `truncated`, narrow `dateFrom` to two months — the bridge only needs net(M) and the current balance.

## ΔAR and ΔAP

```
openAR(d) = Σ over invoices with txnDate ≤ d: total − Σ payments applied with txnDate ≤ d
ΔAR       = openAR(month end) − openAR(prior month end)

openAP(d) = Σ over bills with txnDate ≤ d: total − Σ bill payments applied with txnDate ≤ d
ΔAP       = openAP(month end) − openAP(prior month end)
```

`get_aged_receivables` / `get_aged_payables` give today's picture only; use them as a sanity check on openAR(today), not for history.

## Early vendor payments

For each `search_bill_payments` row in the month, join its bills; `daysEarly = dueDate − paymentDate`. Sum `amount` where `dueDate > month end` (cash that could still be in the account) and report the count and mean days early. Payments within 3 days of due are "on time".

## Residual

```
residual = net income − Σ(bridge lines, signed) − operating cash change
```

Common causes of a large residual: a transfer between own accounts counted as a bridge line and also inside the bank net; a refund or failed autopay; a customer deposit booked to a liability (cash in, no revenue); merchant settlements crossing the month boundary (T+1/T+2). Look for those before presenting; if still unexplained, show it as "unexplained" rather than forcing it to zero.

## Signs

Present every line as its effect on cash: outflows and cash-not-received negative, add-backs positive. The table must foot: net income + Σ lines + residual = operating cash change.
