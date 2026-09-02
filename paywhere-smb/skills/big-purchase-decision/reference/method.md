# Method — big-purchase-decision

## Monthly payment (when the term sheet gives only rate and term)

```
r   = APR / 12 / 100
n   = term in months
PMT = P × r / (1 − (1 + r)^−n)
```
`P` = principal after the down payment. Show `P`, `r`, `n` and the result;
if the term sheet quotes a payment, use the quoted figure and note any
difference from the computed one (fees, rounding).

## Net monthly cash impact

```
net = PMT + Δinsurance + Δfuel_maintenance − mileage_offset − owner_stated_offsets
```
Mileage offset = the trailing-3-month average reimbursement paid to the tech
who would drive the vehicle (payroll journal reimbursement lines or the
payroll-summary email). If two techs share, use the one the owner names.

## Month scoring (safest purchase month)

For each candidate month `M` in the next 12:

1. Projected Operating balance path: weeks inside the 13-week forecast use
   its closes; months beyond use last year's same-month month-end balance ×
   (1 + trailing-3-month growth ratio) with this year's known one-offs added.
2. Apply the outlay: cash → −price in `M`; financed → −down in `M`, then −net
   each month from `M+1`.
3. `M` is **safe** if the adjusted balance stays ≥ reserve-to-keep for `M`,
   `M+1`, `M+2`. Otherwise **risky**, with the worst shortfall.
4. Prefer safe months that precede the historically strongest quarter and
   avoid months that contain a historical low or a known collision (annual
   insurance, quarterly estimate, large remittance) — name the reason.

## Second-vehicle test

Repeat month scoring with two payment streams and two insurance deltas but a
single mileage offset per vehicle. Report the earliest safe month, if any,
and the three conditions that would create one, each quantified with
`what-if`: collections faster by N days, pay-on-due, LOC of $X.

## Historical-lows check

For each of the lowest three month-ends in the trailing 12 months, subtract
the financed net monthly impact (times the months elapsed since a hypothetical
purchase at the strongest month) and report whether the low would have gone
below the reserve to keep. This is the "would the payment have hurt last
January" answer.
