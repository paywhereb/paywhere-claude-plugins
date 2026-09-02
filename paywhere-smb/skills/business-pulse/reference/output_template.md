# Output template

```
Business Pulse — {date}

TL;DR: {one sentence: true available cash, direction, the #1 issue}

CASH (bank, cleared)                                🟢/🟡/🔴
  Operating          ${amount}   (Δ ${x} vs 7 days ago)
  Tax Reserve        ${amount}   holds ${collected} of sales tax owed → short ${shortfall} / funded
  Business Savings   ${amount}   (not counted)
  Pending authorizations  −${amount}  ({n} items)
  TRUE AVAILABLE     ${amount}   = Operating − reserve shortfall − pending

MONEY IN vs OUT (12 months, bank)                   🟢/🟡/🔴
  Avg monthly in ${x} · avg monthly out ${y} · trailing-3-month net ${z}
  Strongest: {Mon, Mon} · Weakest: {Mon, Mon}

REVENUE (books)                                     🟢/🟡/🔴
  {Last month} ${x} (Δ {±y}% vs prior; Δ {±z}% vs a year ago) · MTD ${m}

RECEIVABLES                                         🟢/🟡/🔴
  Open ${x} · overdue ${y} · largest: {customer} ${amt}, {n} days late ({pattern})

PAYABLES                                            🟢/🟡/🔴
  Open ${x} · due in 7 days ${y} · early-pay temptation: {vendor} ${amt} not due for {n} days

THIS WEEK (calendar)
  {Fri} payroll ≈ ${x} (headroom after: ${y}) · {date} sales-tax remittance ${z} · {other}

#1 ISSUE
  {one paragraph: the item, the dollars, the evidence from two sources, the next step and the skill}

Sources: Paywhere ✓ · quickbooks ✓ · calendar ✓ · gmail ✗ (unavailable)
```

Omit any section whose source was unavailable. Keep it to one screen.
