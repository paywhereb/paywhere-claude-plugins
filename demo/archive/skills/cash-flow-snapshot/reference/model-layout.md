# `models/cash-13w.xlsx` — layout (single source of truth)

Written by `cash-flow-snapshot`, `build-cash-dashboard` and refreshed by
`daily-cash-brief` — always this shape so the owner's saved copies stay
comparable. Write it with Cowork's own file tooling; the point is the
formulas, not the library. Every cell in `Forecast` that depends on a lever is
a **formula**, never a pasted value. Currency cells formatted `$#,##0`; dates
`yyyy-mm-dd`.

## Sheet 1 — `Inputs` (the levers; yellow fill on B2:B12)

| Cell | Label (col A) | Value (col B) | Notes |
|---|---|---|---|
| B2 | Generated at | timestamp | text |
| B3 | Opening Operating balance | number | from the bank; Tax Reserve and Savings excluded |
| B4 | Pending authorizations | number | subtracted in week 1 |
| B5 | Reserve to keep | number | from the forecast's 2-week rule; editable |
| B6 | Collections speed (days, − = faster) | 0 | shifts every AR inflow by this many days |
| B7 | Pay on due date (1 = yes, 0 = pay early as usual) | 1 | 0 pulls habitually-early bills forward by their vendor's mean days early |
| B8 | Revenue change % (seasonal weeks only) | 0 | e.g. −10 |
| B9 | New hire monthly cost | 0 | spread biweekly on pay Fridays |
| B10 | Big purchase — monthly payment | 0 | from big-purchase-decision (0 if cash) |
| B11 | Big purchase — cash outlay | 0 | one-time |
| B12 | Big purchase — start week (1–13) | 1 | |
| B13 | Line of credit limit | 0 | floors Close at −(limit) → shows draws |

## Sheet 2 — `Lines` (every dated item, one row each)

Columns: `A Date` · `B Week` (formula: week index 1–13 from Date) · `C Type`
(`AR`, `Recurring billing`, `Seasonal`, `Bill`, `Payroll`, `Recurring debit`,
`Tax sweep`, `Calendar`, `Owner-stated`) · `D Counterparty` · `E Amount`
(inflow +, outflow −) · `F Source` (`bank`, `books`, `calendar`, `owner`) ·
`G Lag days` (AR rows: the customer's mean lag) · `H Habitually early days`
(Bill rows) · `I Adjusted date` (formula: AR rows = Date + Inputs!B6; Bill
rows = IF(Inputs!B7=1, Date, Date − H); others = Date) · `J Adjusted week`
(formula from I) · `K Adjusted amount` (formula: Seasonal rows = E ×
(1 + Inputs!B8/100); others = E).

## Sheet 3 — `Forecast` (13 rows + header, all formulas)

| Col | Header | Formula (row r, week w = r−1) |
|---|---|---|
| A | Week | 1…13 |
| B | Week start | date |
| C | Inflow | `SUMIFS(Lines!K:K, Lines!J:J, A r, Lines!K:K, ">0")` |
| D | Outflow | `SUMIFS(Lines!K:K, Lines!J:J, A r, Lines!K:K, "<0")` (negative) |
| E | Hire | `−Inputs!B9 × 12 / 26` on pay-Friday weeks (a `Payroll` row exists in Lines for that week), else 0 |
| F | Purchase | `IF(A r = Inputs!B12, −Inputs!B11, 0) + IF(A r >= Inputs!B12, −Inputs!B10, 0)` |
| G | Net | `C + D + E + F` |
| H | Close (no LOC) | row 2: `Inputs!B3 − Inputs!B4 + G`; then `H(r−1) + G` |
| I | LOC draw | `MAX(0, −H)` capped at `Inputs!B13` |
| J | Close | `H + I` |
| K | Below reserve? | `IF(J < Inputs!B5, "⚠", "")` |

Below the table: `Minimum close` = `MIN(J2:J14)`, `Minimum week` =
`INDEX(A2:A14, MATCH(MIN(J2:J14), J2:J14, 0))`, `Reserve to keep` =
`Inputs!B5`, `Gap` = minimum − reserve.

## Sheet 4 — `Levers` (a static summary, values not formulas)

One row per lever from `what-if`: `Lever` · `Δ minimum close` · `New minimum
week` · `Note`. Regenerated each run; the owner changes `Inputs` to try
combinations live.

## Sheet 5 — `History` (12 months, bank)

`Month` · `Inflow` · `Outflow` · `Net` · `Operating month-end` (derived:
current balance minus the net of every later month) · `Note` (strongest /
weakest flag). Values from `query_transactions groupBy month`.

## Sheet 6 — `Sources`

Which connectors answered, the query windows used, customers whose lag was
defaulted, calendar events without amounts. Plain text rows.
