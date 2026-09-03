# True available cash (short form)

The number an owner can actually spend today. The full method, the missed-Friday detection and the catch-up transfer live in `../../tax-reserve-check/SKILL.md`; this is the pulse-sized version.

```
true available = Operating balance
               − max(0, sales tax collected on RECEIVED payments not yet remitted − Tax Reserve balance)
               (pending card authorizations: already netted out of the bank balance — report, never subtract) (absolute sum)
```

1. **Window** = the months not yet remitted. The remittance on or after the 20th (a `DEPT OF REVENUE` debit from the Tax Reserve) pays the *previous* month, so before the 20th the window is the 1st of last month … today, and on or after the 20th it is the 1st of this month … today. The debit only tells you which month was last paid; the window never starts "the day after the debit" — that reading drops most of a month of collected tax and reports a shortfall of $0 when the reserve is actually short.
2. **Received payments in the window** = `search_payments {dateFrom: window start}` (books). For each payment, find the invoice(s) it applies to and take the invoice's explicit sales-tax line(s), pro-rated by the share of the invoice the payment covered. Sum by state if the liability accounts are per state; the total is what matters here.
3. **Collected, not remitted** = that sum. Optionally cross-check: bank credits in the window (`query_transactions {direction: "credit"}`) should roughly equal the payments' gross less merchant fees.
4. **Shortfall** = collected − Tax Reserve balance, floored at 0. A positive shortfall means Friday sweeps were skipped; list the Fridays with no `TRANSFER TO TAX RESERVE` credit.
5. Business Savings is never part of the formula.

Show the formula with the numbers filled in; never just the result. Round to dollars.
