---
name: cash-bridge
version: 1.0.2
description: >
  Reconciles "the books say I made money" with what the Operating balance
  actually did, in either direction: cash down while profitable, or cash up by
  more than profit. A profit-to-cash bridge for one month (the last full month
  by default) built from the accrual P&L and two balance-sheet snapshots —
  receivables change, payables change, inventory and equipment, undeposited
  funds, sales-tax and other liabilities, owner distributions, money moved to
  the reserve and savings, depreciation — with each line's source named, a
  residual, and the bank's own change in Operating as the check. Read-only,
  five calls in one turn. Use when the owner says "QuickBooks says I made
  money last month, why is my cash lower," "why doesn't my bank balance move
  with my profit," "I made X last month, where is it," "my cash went up more
  than I made," "profit vs cash," "where did the profit go," or "bridge profit
  to cash." NOT for "how am I doing" or "what's my balance" — those need no
  skill.
---

# Cash Bridge

Profit is an accounting opinion about a month; the Operating balance is what
cleared. The two differ for listed reasons, and every reason is a line on the
balance sheet or a row at the bank. This skill lists them with amounts from
the source that knows each one. Nothing here proposes or moves money.

Do not assume the owner's premise. Compute the sign: in a slow month cash
falls while the P&L is positive (invoices out, draws and taxes paid); after a
busy one cash rises by more than profit (earlier months' invoices collected).
Say which happened in the first sentence, and if the owner's direction or
figure disagrees with the numbers, say so there too.

## Quick start — five calls, one turn

```
User: "the books say I made money last month, why is my cash lower?"
→ Resolve M = the month asked (default: last full calendar month, from the actual date)
→ In ONE turn, in parallel:
    get_profit_and_loss {start_date: M-01, end_date: M-end, accounting_method: "Accrual"}   (net income, depreciation)
    get_balance_sheet  {end_date: M-end}                                                     (AR, AP, inventory, fixed assets, liabilities, equity, bank accounts)
    get_balance_sheet  {end_date: (M−1)-end}                                                 (the same, a month earlier → every Δ)
    list_accounts                                                                            (Operating by role; reserve and savings names)
    query_transactions {accountNumbers:[Operating], dateFrom: M-01, dateTo: M-end,
                        aggregate: true, includeTransactions: true, sort: "amount_desc", limit: 20}
                                                                                             (net = the bank's change in Operating; the 20 largest rows name the big debits)
→ Bridge: net income → adjustments (each with its source) → change in cash; residual; bank check
→ Reply under 25 lines, the gap first
```

Never rebuild receivables or payables from a year of invoices, payments or
bills: the balance sheet already carries open AR and AP at each date. Never
pull bill payments to price early vendor payments here; if the owner asks
about that habit, point at [`../ap-timing`](../ap-timing/SKILL.md).

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Read"), then `TaskUpdate`
it to `in_progress` when you begin that step and `completed` when it's done.
This is what drives Cowork's visible progress display — it does not happen
unless you do it explicitly.

## Step 1 — Read (one parallel turn)

Pick M first: the last full calendar month unless the owner names one. If
the owner quotes a profit figure, use their month and compare the figure to
the P&L in Step 2. Then issue the five reads above at once. The Operating
account is identified by role from `list_accounts` (the primary checking,
never a hardcoded number); the balance-sheet bank rows are matched to the
bank accounts by name.

Degraded modes: **no QuickBooks** → bank-only. Report the month's net from
the aggregate and the 20 largest rows grouped by what they are (owner draws,
tax payments, transfers to reserve or savings, equipment vendors, payroll);
say net income is unavailable and skip the bridge. **No Paywhere** → books
only. Bridge to the balance sheet's Operating row and label the result "per
the books, not the bank". Never retry in a loop.

## Step 2 — Net income and the adjustments

Net income and depreciation come from the P&L. Every other line is a
difference between the two balance sheets (`Δ = end of M − end of M−1`),
signed by its effect on cash. A line with nothing behind it is $0, not
omitted. Row-to-line mapping, signs and residual causes:
[`reference/method.md`](reference/method.md).

| Line | Source | Effect on cash |
|---|---|---|
| Net income | P&L | + |
| Depreciation / amortization | P&L | + (non-cash) |
| Receivables (ΔAR) | balance sheets | grew → −; shrank → + (earlier months collected) |
| Undeposited funds and other current assets | balance sheets | grew → − |
| Inventory | balance sheets | grew → − |
| Equipment / fixed assets (gross) | balance sheets | bought → − |
| Payables (ΔAP) and credit cards | balance sheets | grew → + |
| Sales tax and other current liabilities | balance sheets | grew → + (collected, not yet remitted) |
| Loans | balance sheets | drawn → +; paid down → − |
| Owner distributions / draws | balance sheets (equity), confirmed by the bank rows | − |
| Moved to Tax Reserve / Savings (Δ of the other bank accounts) | balance sheets, confirmed by the bank rows | − |
| Residual | computed | the table must foot |

The sum equals the books' change in Operating. The bank's change is the
`aggregate.net` of the one `query_transactions` call. The two normally match
within a few dollars; a larger difference is the **books-vs-bank gap** (bank
fees or deposits not yet booked, a transaction dated across the month
boundary) — report it as its own line, not as residual. Use the 20 largest
rows to attach a date to the big lines: the draw, the tax payment, the
reserve transfer, the equipment purchase.

## Step 3 — Reply (under 25 lines)

```
{Month YYYY}: the books show net income of ${ni}; Operating {fell|rose} ${chg} ({open} → {close}).
{One sentence: the gap and its top two drivers, in plain words.}

Net income (books, accrual)                              +${ni}
  Depreciation (non-cash)               P&L              +${dep}
  Receivables {grew|shrank}             balance sheets   {−|+}${dAR}
  Undeposited funds / other assets      balance sheets   {−|+}${}
  Inventory                             balance sheets   {−|+}${}
  Equipment purchased                   balance sheets   −${}
  Payables & cards {grew|shrank}        balance sheets   {+|−}${}
  Sales tax & other liabilities         balance sheets   {+|−}${}
  Owner distributions                   equity · bank {date}   −${}
  Moved to reserve / savings            bank {date}      −${}
  Residual                                               ±${}
= Change in Operating (books)                            ${chg}
Bank: Operating net for the month ${net} ({count} posted rows); books-vs-bank gap ${} {cause or "none"}.

{One closing sentence: structural (draws, taxes — the profit is real but committed) or
 timing (receivables — it arrives later, and swings back). Offer invoice-chase if AR is the driver.}
```

Omit $0 lines from the reply only when the table still foots and the reply
would otherwise exceed 25 lines. If the residual exceeds 5% of revenue, look
for the missing balance-sheet row before presenting; if still unexplained,
label it "unexplained" rather than forcing it to zero.

## What not to do

- Do not stage, propose or move money; nothing here touches the bank beyond
  one read.
- Do not narrate seasons, industries or the owner's habits; name the lines
  and their sources.
- Do not derive month-end bank balances from aggregates across many months —
  the balance sheet gives both month-ends, and the one bank aggregate is the
  check.
- Do not quote a profit figure the owner gave as the books' figure; the P&L is.

## Reference

- [`reference/method.md`](reference/method.md) — balance-sheet rows → bridge lines, signs, residual and books-vs-bank causes
- [`../ap-timing/SKILL.md`](../ap-timing/SKILL.md) — when early vendor payments are the question
- [`../invoice-chase/SKILL.md`](../invoice-chase/SKILL.md) — when receivables are the driver
