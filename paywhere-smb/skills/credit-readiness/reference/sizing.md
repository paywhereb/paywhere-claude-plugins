# Sizing — credit-readiness

```
month_end[m]     = current_operating − Σ net[k] for k after m
deepest_low      = min( intra-month lows of the 3 lowest months, forecast 13w minimum )
gap              = max(0, reserve_to_keep − deepest_low)
loc_size         = ceil(gap × 1.25 / 5000) × 5000
card_float       = avg_monthly_card_eligible_spend × 25 / 30
```

## Bridging test ("would a LOC have helped")

For each historical low `L` on date `d`:
- `draw = reserve_to_keep − L`
- walk forward from `d` summing daily net inflow above the trailing-90-day
  daily average; `days_to_repay` = first day the cumulative excess ≥ draw.
- Report `draw` and `days_to_repay`; a bridge under ~30 days is the classic
  working-capital case. If it never repays within 90 days, say the low was
  structural (pricing, distributions), not timing — a LOC is the wrong tool.

## Card float

Card-eligible spend = Operating debits whose descriptor begins `POS DEBIT`
or `RECURRING DEBIT`, plus vendors known to accept cards (ask if unsure).
Exclude payroll, tax, rent, subcontractors. Float = one billing cycle of that
spend (25 of 30 days). Present as "cash a card would keep in the account for
~25 days", not as a savings.

## Repayment source

Average net inflow of the three strongest months (bank) — the seasonal
surplus that repays a seasonal draw. State it next to the request size.
