# Method — big-purchase-decision

## Month-end balances from one aggregate call

`query_transactions {aggregate: true, groupBy: "month", dateFrom: <12 months
ago>}` returns, per calendar month, `{sumCredits, sumDebits, net}`. Walk
backwards from today's balance:

```
monthEnd[current month]  = balance today            (partial month; label it)
monthEnd[m]              = monthEnd[m+1] − net[m+1]
```

Rank the twelve completed month-ends. Highest three = safest purchase months;
lowest three = risky months. Drawdown = max over pairs (i < j) of
`monthEnd[i] − monthEnd[j]` — the most cash the business gave back inside the
year. Average monthly debits = mean of `sumDebits` over the completed months.

## Cushion

```
payroll run = the last processor debits on one pay date (net + tax)
cushion     = payroll run + average monthly debits ÷ 4.3
```

Actual obligations, not a percentage. Say the two parts.

## The tests

```
afterCash   = Operating − price
afterDown   = Operating − down payment
```

| Verdict | Condition |
|---|---|
| **Yes, in cash** | `afterCash ≥ cushion` and `afterCash − drawdown ≥ cushion` |
| **Yes, if financed** | cash fails, `afterDown ≥ cushion`, and the net monthly impact is a small share of average monthly debits |
| **Not now** | otherwise — name the first high month and the smallest change that makes it fit |

Spendable cash never includes the Tax Reserve or Business Savings. Pending
authorizations are already netted by the bank; report them, never subtract.

## Monthly payment

```
r   = APR / 12
n   = term in months
PMT = P × r / (1 − (1 + r)^−n)
```
`P` = principal after the down payment. Prefer the term sheet's quoted
payment; show the formula only when computing.

## Net monthly cash impact

```
net = PMT + Δinsurance (+ Δfuel/maintenance if quoted) − reimbursement replaced
```
The reimbursement replaced is the mileage the owner pays today to the tech who
would drive the vehicle — owner-stated; if not given, omit it and say the
impact is before that offset.

## Second vehicle

Two payment streams and two insurance deltas. Land them on the three lowest
month-ends: if `lowest month-end − 2 × net × months elapsed ≥ cushion` for all
three, it fits; otherwise defer and name the change that would create room
(faster collections, a line of credit, paying vendors on the due date).
