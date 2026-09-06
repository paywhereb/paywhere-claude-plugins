# True available cash (short form)

The number an owner can actually spend today. The full method, the missed-sweep
detection and the catch-up transfer live in [`../SKILL.md`](../SKILL.md)
(tax-reserve-check); this is the one-paragraph version other skills link to as
`../tax-reserve-check/reference/true-available.md`.

```
true available = Operating balance
               − max(0, sales tax collected on RECEIVED payments not yet remitted − Tax Reserve balance)
```

1. **Window** = the months not yet remitted. A remittance debit from the Tax
   Reserve on or after day D of month M pays month M−1, so the window starts
   on the **1st of the month the last remittance debit posted in** and runs
   to today (before D: the 1st of last month … today; on or after D: the 1st
   of this month … today). The debit only tells you which month was last
   paid; the window never starts "the day after the debit" — that reading
   drops most of a month of collected tax and reports a shortfall of $0 when
   the reserve is actually short.
2. **Collected, not remitted** = `get_sales_tax_collected {date_from: <window
   start>}` → `collected.total` (cash basis: tax inside payments *received*
   in the window, pro-rated by the share applied; `collected.byItem` is the
   split per tax item). One call; never rebuild it from payments and
   invoices.
3. **Shortfall** = collected − Tax Reserve balance, floored at 0. A positive
   shortfall means sweeps into the reserve were skipped or short; the reserve's
   12-month credit history names the weeks.
4. **Pending card authorizations** are already netted out of the bank's
   balance — report them if the payload shows them, never subtract them.
5. **Business Savings** is never part of the formula.

Show the formula with the numbers filled in; never just the result. Round to
dollars in prose, cents in tables.
