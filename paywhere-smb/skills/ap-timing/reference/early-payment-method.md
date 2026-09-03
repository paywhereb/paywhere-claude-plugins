# Early-payment method

## Pairing bills with payments

From `search_bills` (12 months, paid and open) and `search_bill_payments` (12 months): each bill payment lists the bills it applies to. For each applied bill:

```
days early = bill.DueDate − billPayment.TxnDate
```

Positive = paid before due; 0 = on the due date; negative = late. Partial payments: use the payment that closed the bill. Bills with no terms (`Due on receipt`) have due date = bill date; treat days early as 0 and exclude them from the habit (subcontractors paid on receipt are behaving correctly).

## Per-vendor statistics

Compute these for **every vendor with paid bills in the window**, not only vendors with an open bill today: the year's `search_bills` and `search_bill_payments` are two calls and already cover everyone, and "am I paying anyone early?" is a question about the year. A supplier paid early all winter with nothing open in September still belongs in the answer.

| Stat | Definition |
|---|---|
| bills observed | applied bills paid **≥ 5 days early** in the window (the early-paid bills only) |
| mean days early | mean of days early over those early-paid bills. Bills paid on time or late are **not** averaged in — a seasonal habit averaged over the on-time summer bills reads as "no pattern" |
| dollars paid early | sum of those early-paid bills' totals |
| months | calendar months (by payment date) in which a bill was paid ≥ 5 days early |
| seasonal? | the habit appears in some months and not others |

**Habitually paid early** = ≥ 3 bills paid ≥ 5 days early in the window. Report the seasonality when present; a habit that switches off in the busiest months is a cash-management tell, not noise. State the basis in one clause ("5 bills paid early, 16 days early on average, $18k") so the owner knows the average is over the early bills.

## Bank corroboration

`query_transactions {direction: "debit", descriptionContains: "<stem>", dateFrom: <12 months ago>}` with the vendor's statement stem (the constant part of `ACH DEBIT <VENDOR> …` / `WIRE OUT <VENDOR>`). Debit dates should equal payment dates ±1 business day. If a payment has no debit, or a debit has no payment (an unrecorded payment), trust the bank and flag it for month-end.

## Cost of the habit

```
cash out early (window) = Σ bill total × days early ÷ 30      (dollar-months of float given away)
```

Report plainly as "about $X left the account an average of N days before it had to, across K bills". Do not price it with an interest rate unless the owner asks; if they do, use the rate they name.

## Hold rule

`HOLD` when: open bill, days until due > 7, vendor habitually paid early. Hold length = days until due − 0 (pay on the due date; ACH takes 1–3 business days, so stage 2 business days before the due date). Cash kept in the window = the bill total.
