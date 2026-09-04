# Worked Example: Quarterly Estimated Tax

**Scenario:** Sarah runs a freelance graphic design business as a sole
proprietor. In late April of tax year `Y` she asks: "How much should I pay
in estimated taxes for Q2?"

Figures are illustrative. `Y` is the tax year; the wage base, bracket table
and due dates are the ones published for `Y`, looked up at run time and
named in the output.

---

## Step 1: Read the books and the bank in one turn (3 calls)

- `get_profit_and_loss` Jan 1 → Mar 31, `Y`:
  gross income $48,000 · operating expenses $12,500 · **net ordinary income
  $35,500**
- `list_accounts` → Operating
- `query_transactions {accountNumbers: [Operating], direction: "debit",
  descriptionContains: "IRS", dateFrom: "Y-01-01"}` → one debit, April 12,
  `IRS USATAXPYMT`, **$2,000** (the Q1 estimate)

> "I see one estimated payment at the bank — $2,000 on April 12. Anything
> else paid outside this account?" — Sarah: "No, that's it."

---

## Step 2: Calculate

```
YTD net profit (Q1):        $35,500
Annualized net profit:      $35,500 × 4 = $142,000  ← Q1 × 4, stated as an assumption

Self-employment tax:
  SE base:   $142,000 × 92.35%  = $131,137
  SE tax:    $131,137 × 15.3%   = $20,064   (below the wage base for Y — full rate applies)
  Deductible half:              = $10,032

Federal income tax:
  Adjusted net: $142,000 − $10,032 = $131,968
  Rate: 22% assumed effective rate (checked against Y's bracket table)
  Federal tax:  $131,968 × 22%     = $29,033

Total estimated annual liability:
  SE tax + federal = $20,064 + $29,033 = $49,097

Quarterly breakdown:
  Annual liability:       $49,097
  Payments made (bank):  −$2,000
  Remaining:              $47,097 ÷ 3 remaining due dates = $15,699
  Q2 payment due June 15, Y (or the next business day): ~$15,700
```

---

## Step 3: The file — `tax/estimate-Y-Q2.md`

```
## Estimated tax summary — Q2 Y
Prepared April 24, Y · For review by your accountant — not tax advice

**YTD net profit (Jan 1 – Mar 31):** $35,500
**Estimated annual net profit:** $142,000 (annualized from Q1 actual)
**Entity assumed:** sole proprietor (confirm with accountant)

### Self-employment tax
$142,000 × 92.35% × 15.3% = $20,064 (below Y's Social Security wage base)
Deductible SE half: $10,032

### Federal income tax estimate
Adjusted net income: $131,968
Assumed rate: 22% (confirm with accountant — household income affects this)
Federal income tax estimate: $29,033

### Total estimated annual liability
$20,064 + $29,033 = **$49,097**

### Q2 payment
Annual liability:              $49,097
Less payments made (bank):    −$2,000  (IRS USATAXPYMT, April 12)
Remaining:                     $47,097 ÷ 3 = **~$15,700 due June 15, Y**

### Safe harbor note
Total Y payments should reach 100% of your Y−1 tax (110% if Y−1 AGI exceeded
that year's threshold). Ask your accountant for the Y−1 figure.

### Assumptions — review with your accountant
- Tax year: Y; wage base, brackets and due dates from Y's published figures
- Federal rate: 22% effective (may differ)
- Entity: sole proprietor (assumed)
- Annualization: Q1 × 4 — income may be seasonal
- State taxes: not included
- QBI deduction (up to 20%): not applied — could reduce federal tax significantly
- Retirement contributions, home office, vehicle: not applied
- Payments made: from the bank's IRS debits; paid from Operating, not the sales-tax reserve
```

## Step 4: Reply (chat)

> Q2 estimate ≈ **$15,700**, due June 15, Y. Written to `tax/estimate-Y-Q2.md`.
> The two assumptions most likely to move it: the 22% rate and Q1 × 4
> annualization — your accountant may also apply the QBI deduction. Paying
> it is a payment you approve on the bank's page, from Operating; the
> sales-tax reserve is not touched.
