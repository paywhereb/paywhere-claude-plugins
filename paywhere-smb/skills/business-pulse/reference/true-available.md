# True available cash (short form)

The number an owner can actually spend today. The full method, the missed-Friday detection and the catch-up transfer live in `../../tax-reserve-check/SKILL.md`; this is the pulse-sized version.

```
true available = Operating balance
               − max(0, sales tax collected on RECEIVED payments not yet remitted − Tax Reserve balance)
               (pending card authorizations: already netted out of the bank balance — report, never subtract) (absolute sum)
```

1. **Window start** = the day after the most recent `DEPT OF REVENUE` debit from the Tax Reserve (bank). If none in 60 days, use the 21st of the previous month.
2. **Received payments in the window** = `search_payments {dateFrom: window start}` (books). For each payment, find the invoice(s) it applies to and take the invoice's explicit sales-tax line(s), pro-rated by the share of the invoice the payment covered. Sum by state if the liability accounts are per state; the total is what matters here.
3. **Collected, not remitted** = that sum. Optionally cross-check: bank credits in the window (`query_transactions {direction: "credit"}`) should roughly equal the payments' gross less merchant fees.
4. **Shortfall** = collected − Tax Reserve balance, floored at 0. A positive shortfall means Friday sweeps were skipped; list the Fridays with no `TRANSFER TO TAX RESERVE` credit.
5. Business Savings is never part of the formula.

Show the formula with the numbers filled in; never just the result. Round to dollars.
