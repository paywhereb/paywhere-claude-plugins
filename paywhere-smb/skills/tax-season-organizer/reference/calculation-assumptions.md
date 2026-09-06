# Tax Calculation Assumptions

The math behind the quarterly estimate, and the assumptions every output
must surface so the accountant can adjust. **No figure here is tied to a
calendar year.** Let `Y` be the tax year the owner names (default: the
current year for an estimate, the previous year for a January 1099 ask).
Look up the published figures for `Y` — brackets, the Social Security wage
base, the AGI threshold for the 110% safe harbor — and state them and their
source in the Assumptions section. If you cannot confirm a figure for `Y`,
say so and use the owner's or the accountant's number.

---

## Self-employment (SE) tax

Applies to sole proprietors, single-member LLCs and partners on earned
income. It does **not** apply to an S-corp owner's W-2 wages (those carry
payroll withholding) and not to K-1 distributions.

```
SE tax base      = net profit × 92.35%
Social Security  = min(SE tax base, wage base for Y) × 12.4%
Medicare         = SE tax base × 2.9%
SE tax           = Social Security + Medicare      (15.3% below the wage base)
Deductible half  = SE tax ÷ 2                      ← reduces taxable income
```

Worked shape (figures illustrative, below the wage base):

```
Net profit:      $80,000
SE tax base:     $80,000 × 92.35% = $73,880
SE tax:          $73,880 × 15.3%  = $11,304
Deductible half: $11,304 ÷ 2      = $5,652
```

---

## Federal income tax estimate

### Entity types and how they are taxed

| Entity | How income is taxed | SE tax applies? |
|---|---|---|
| Sole proprietor / single-member LLC | Schedule C → personal return | Yes |
| Partnership / multi-member LLC | Schedule K-1 → personal return | Yes (on earned income) |
| S-corporation | W-2 wages + K-1 distributions → personal return | On wages only, via payroll |
| C-corporation | Separate corporate return | No (payroll taxes instead) |

Default assumption: **sole proprietor** unless the owner says otherwise.
Always state it.

### Rate

Federal brackets are progressive (the rates run 10% through 37%; the dollar
thresholds are indexed every year and depend on filing status). For a
**rough estimate** apply one effective rate to adjusted net income: **22%**
by default for most owner-operators, or the rate the owner gives. Name the
rate and the year's bracket table you checked it against.

```
Adjusted net = net profit − (SE tax ÷ 2)
Federal estimate = Adjusted net × assumed rate
```

The QBI deduction (up to 20% of qualified business income) is significant
for many small businesses — it is **not** applied in the base estimate; say
so and let the accountant apply it.

---

## Estimated-tax due dates (relative to the tax year Y)

| Quarter | Period covered | Payment due |
|---|---|---|
| Q1 | Jan 1 – Mar 31, Y | April 15, Y |
| Q2 | Apr 1 – May 31, Y | June 15, Y |
| Q3 | Jun 1 – Aug 31, Y | September 15, Y |
| Q4 | Sep 1 – Dec 31, Y | January 15, Y+1 |

A due date that falls on a weekend or federal holiday moves to the next
business day — resolve it for `Y` and print the resolved date.

**Quarters remaining** = the due dates in the table not yet passed as of
today. **Annualization** = YTD net profit ÷ months elapsed × 12 (state it;
seasonal businesses distort it).

---

## Safe harbor rule

To avoid an underpayment penalty, total estimated payments must be at least
the lesser of:

- **100%** of the prior year's (Y−1) tax — **110%** if Y−1 AGI exceeded the
  threshold in force for that year;
- **90%** of the current year's tax.

Always note this; the accountant confirms the prior-year figure.

---

## What the estimate does NOT include

List these exclusions in every output:

- State and local income taxes
- QBI deduction (Section 199A)
- Home office deduction
- Vehicle deductions
- Depreciation / Section 179
- Retirement contributions (SEP-IRA, Solo 401k)
- Self-employed health insurance deduction
- Prior-year net operating loss carryforward

Each can move the number materially. Flag them so the accountant applies them.
