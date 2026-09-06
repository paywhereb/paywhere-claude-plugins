# Method

## Formulas

```
window          = 1st of the month the last remittance debit posted in … today
                  (a remittance on/after day D of month M pays month M−1:
                   before D → last month + this month; on/after D → this month)
collected       = get_sales_tax_collected {date_from: window start}
                    .collected.total    (cash basis, tax inside payments RECEIVED)
collected[j]    = .collected.byItem[j]  (per tax item — one per jurisdiction when the books are set up that way)
shortfall       = max(0, collected − Tax Reserve balance)
true available  = Operating balance − shortfall
                  (the bank's balance is already net of pending card authorizations —
                   report them, never subtract them again)
next remittance = day D of the month after the last remittance debit
                  (D = that debit's day-of-month; unknown when no debit is found — say so)
```

Round to cents in the table, to dollars in prose. The report already pro-rates
a partial payment by the share of the invoice it covered; do not pro-rate
again.

## Descriptor stems (patterns to search, not facts)

Search with `descriptionContains` (case-insensitive, matches `description`
and `statementDescription`); confirm what you find before relying on it.

| Looking for | Stem to try | Where |
|---|---|---|
| Sales-tax remittance | the revenue agency's name, `REVENUE`, `SALES TAX`, then `TAX` | Tax Reserve **debits** |
| Sweep in | the reserve account's name, `TRANSFER` | Tax Reserve **credits** (the mirror debit is on Operating) |

If a stem returns nothing, widen and read the rows rather than concluding
there were no remittances. Exclude interest credits from the sweep history.

## The sweep-day test

1. Take every Tax Reserve credit in `[today − 12 months, today]` that is a
   transfer in. The **sweep weekday** is the weekday most of them post on.
   Fewer than three credits → no cadence; list them and ask once.
2. List every occurrence of that weekday from the earliest credit to the end
   of the last complete week. The current, incomplete week is never "missed".
3. A sweep "belongs" to a date if a credit posted that day or the next
   business day (weekend posts).
4. Missed = dates with no such credit. Name them.
5. For weeks inside the report window, compare the sweep with that week's
   `byWeek[].collected` (Monday–Sunday by payment date): a sweep well under
   it is a **short sweep**, noted separately from a miss.

## Basis note

The books usually post the liability when the invoice is issued; the reserve
follows cash received. `get_sales_tax_collected` is cash basis on purpose —
receipt is what creates the obligation the reserve must cover. Both numbers
are right; they answer different questions. Say which one each figure is.
