# Method

## Formulas

```
window            = (last remittance debit date + 1 day) … today
tax collected(p)  = Σ over invoices i applied by payment p:
                      taxLines(i) × applied(p, i) ÷ total(i)
collected[j]      = Σ tax collected(p) for tax items posting to liability account j
collected total   = Σ_j collected[j]
shortfall         = max(0, collected total − Tax Reserve balance)
true available    = Operating balance − shortfall − |pending authorizations|
```

Round to cents in the table, to dollars in prose. Pro-rate only when a payment is partial; a payment that covers the whole invoice takes the whole tax line.

## Descriptor stems (patterns to search, not facts)

These are the kinds of statement descriptors a mock-bank world carries. Search with `descriptionContains` (case-insensitive, matches `description` and `statementDescription`); confirm what you find before relying on it.

| Looking for | Stem to try | Where |
|---|---|---|
| Sales-tax remittance | `DEPT OF REVENUE`, `DEPARTMENT OF REVENUE`, `SALES TAX` | Tax Reserve debits |
| Friday sweep in | `TAX RESERVE`, `TRANSFER TO TAX RESERVE` | Tax Reserve credits (the mirror debit is on Operating) |
| Owner estimated tax | `IRS`, `USATAXPYMT`, `EFTPS` | Operating debits |
| Local business tax | the city / revenue division name | Operating debits |

If a stem returns nothing, widen (`TAX`) and read the rows rather than concluding there were no remittances.

## The Friday test

1. List every Friday F in `[window start − 7 days, today]`.
2. A sweep "belongs" to F if a Tax Reserve credit with the sweep stem posted on F (or the following Monday, for a weekend post).
3. Missed = Fridays with no such credit. Name them.
4. For each sweep, week tax = Σ tax collected(p) for payments dated Mon…Sun of that week. `|sweep − week tax| ≤ $5` → matches received. If instead it matches the tax on invoices *issued* that week → note "swept on invoiced amounts".
5. The current (incomplete) week has no Friday yet — exclude it from "missed".

## Basis note

Books usually post the liability when the invoice is issued; the reserve follows cash received. Both numbers are right; they answer different questions. Say which one each figure is.
