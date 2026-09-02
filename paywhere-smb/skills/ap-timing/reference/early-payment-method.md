# Early-payment method

## Pairing bills with payments

From `search_bills` (12 months, paid and open) and `search_bill_payments` (12 months): each bill payment lists the bills it applies to. For each applied bill:

```
days early = bill.DueDate − billPayment.TxnDate
```

Positive = paid before due; 0 = on the due date; negative = late. Partial payments: use the payment that closed the bill. Bills with no terms (`Due on receipt`) have due date = bill date; treat days early as 0 and exclude them from the habit (subcontractors paid on receipt are behaving correctly).

## Per-vendor statistics

| Stat | Definition |
|---|---|
| bills observed | applied bills in the window |
| mean days early | mean of days early over those bills |
| dollars paid early | sum of bill totals paid ≥ 5 days early |
| months | calendar months in which a bill was paid ≥ 5 days early |
| seasonal? | the habit appears in some months and not others |

**Habitually paid early** = mean days early ≥ 7 over ≥ 3 bills. Report the seasonality when present; a habit that switches off in the busiest months is a cash-management tell, not noise.

## Bank corroboration

`query_transactions {direction: "debit", descriptionContains: "<stem>", dateFrom: <12 months ago>}` with the vendor's statement stem (the constant part of `ACH DEBIT <VENDOR> …` / `WIRE OUT <VENDOR>`). Debit dates should equal payment dates ±1 business day. If a payment has no debit, or a debit has no payment (an unrecorded payment), trust the bank and flag it for month-end.

## Cost of the habit

```
cash out early (window) = Σ bill total × days early ÷ 30      (dollar-months of float given away)
```

Report plainly as "about $X left the account an average of N days before it had to, across K bills". Do not price it with an interest rate unless the owner asks; if they do, use the rate they name.

## Hold rule

`HOLD` when: open bill, days until due > 7, vendor habitually paid early. Hold length = days until due − 0 (pay on the due date; ACH takes 1–3 business days, so stage 2 business days before the due date). Cash kept in the window = the bill total.
