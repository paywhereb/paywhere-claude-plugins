# Profiles, factors and DSO

## Payment lag

Per paid invoice: `lag = payment txn date − invoice due date` (days; negative = paid early). Use the payment that closed the invoice; for installments use the weighted mean of the applied amounts. Minimum 3 paid invoices in the trailing 12 months to classify.

## Profile rules (derived from the lag distribution)

| Profile | Rule |
|---|---|
| **prompt** | mean lag ≤ 5 and no invoice > 15 days late |
| **routinely late** | mean lag 8–25 and ≥ 60% of invoices late by 5+ days |
| **occasionally very late** | mean lag ≤ 15 but ≥ 1 in 4 invoices 30–60+ days late |
| **delinquent then cured** | a run of ≥ 3 consecutive invoices 60+ days late that were later paid (often after a payment plan), with subsequent invoices paid within 30 days |
| **retainage** | invoices flagged as retainage (memo / doc number) with lag ≈ contract holdback (90–120 days) — a contract term, not delinquency |
| insufficient history | fewer than 3 paid invoices |

Show the evidence with the label: `routinely late (11 invoices, mean +14, max +21)`.

## Factors for cash impact

```
cash impact = open balance × lateness factor × profile factor
lateness factor: current 0.5 · 1–30 days 1.0 · 31–60 1.5 · 61–90 2.0 · 90+ 2.5
profile factor:  prompt 1.0 · routinely late 1.1 · occasionally very late 1.3 · delinquent then cured 1.5 · retainage 0.6 · insufficient 1.0
```

The factors only order the list; report dollars, days and profile — not the score — to the owner.

## DSO

```
DSO(m) = open AR at end of month m ÷ (revenue(m, m−1, m−2) ÷ 90)
```

Open AR at a past month end = open invoices dated on/before that month end whose payment date is after it (or none). Revenue from `get_profit_and_loss` by month. Direction = sign of the slope over the last 3 points; name the months that moved it. Typical drivers to look for: a delinquent customer, a retainage holdback, a policy change (deposits on large jobs appear as deposit invoices), seasonality (peak-season invoices inflate open AR before they age).

## Bank descriptors that settle an invoice

| Rail | Descriptor stem | Match |
|---|---|---|
| Direct ACH | `ACH CR <customer or AP-system name>` | amount = open balance ±$0.50, name fragment |
| Check | `MOBILE CHECK DEPOSIT <check#>` | amount; the check number is the evidence line |
| Wire | `WIRE IN <sender>` (+ a separate `WIRE FEE` debit) | amount, sender |
| Card / pay-by-link | `INTUIT PYMT SOLN DEPOSIT` | grouped and net of fees — match only via the books' Deposit, not by amount |
