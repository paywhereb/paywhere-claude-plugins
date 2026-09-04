---
name: big-purchase-decision
version: 1.0.7
description: >
  Answers "can I afford this?" for a large purchase (a work van, a truck,
  equipment) from cleared cash rather than book profit, in five tool calls:
  today's balance, twelve months of monthly cash from the bank (the year's
  highs and lows), the last payroll debits (the cushion), and the dealer /
  lender / insurer emails for the price, terms and deadline. Always answers
  SHORT — a verdict, the number behind it, one caveat, under 120 words — and
  offers depth rather than volunteering it; preparing a lender application is
  credit-readiness, invoked explicitly. Read-only, stages nothing. Use when the
  owner says "can I afford the van / a new truck / new equipment," "can I buy
  a van this week for $X," "cash or finance," "when is the safest month to
  buy," "should I buy a second van," or "what if I put $10k down."
---

# Big Purchase Decision

A profitable year on paper does not mean the purchase fits. This skill answers
from the bank: the balance today, where cash actually sat at each month-end
this year, and the payroll that must clear regardless. Five calls, one
reply, under half a minute.

**Answer the question first.** The first two sentences are the verdict for
*this* purchase at *this* price (yes / no / yes if financed) with the one
number that decides it. Everything after is why the verdict holds.

## One shape: short

This skill answers in under ~120 words, whatever it is asked. A long answer to
a short question is a wrong answer — it costs the reader more than it tells
them, and it spends minutes the owner is watching tick by.

**Short verdict** — four lines, then stop:

```
{Yes / No / Yes, if financed} — {the deciding number, one clause}.
{One sentence of why: the monthly figure, netted against what it replaces or against what an average month clears.}
{At most ONE caveat, and only if it changes the answer.}
{One line offering more — deeper analysis, or the lender package — then stop.}
```

A hedge is not a verdict: "Yes, if financed" is one, "it depends whether you
finance" is not. Pick the answer the numbers support and say it plainly.

Do **not** volunteer the cash-vs-finance comparison, the twelve month-ends, a
second unit, the tax reserve or a line of credit. Each is one question away,
and the owner will ask if they want it. If the owner asks several things at
once, answer the one that decides it and offer the rest — still short.

**The lender package is a different job.** "What should I bring to the bank",
"get me ready for the loan application", "how much credit should I ask for" →
name `credit-readiness` and stop. It is invoked explicitly and produces a
markdown package; do not start assembling one here.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1, `TaskUpdate` to `in_progress` when you begin a step and `completed`
when it's done — this drives Cowork's progress display.

## Step 1 — Three reads in one turn, then the thread

The whole answer is a verdict and one number, so read only what the verdict
needs. **Turn one, all three in parallel:**

1. `list_accounts` → Operating (primary checking by role). Spendable cash is
   **Operating only**; the Tax Reserve holds customers' sales tax and Business
   Savings is the owner's cushion. The bank's balance already nets pending
   card authorizations — do not subtract them. Do **not** compute a reserve
   shortfall here; if the reserve looks short, say so in one clause and point
   at tax-reserve-check.
2. `query_transactions {accountNumbers: [Operating], aggregate: true, groupBy:
   "month", dateFrom: <first day of the month 12 months ago>}` → twelve monthly
   nets: the average month's debits (what the new payment is measured against),
   the lowest month-ends, and the deepest drop from any month-end to a later
   one. One call covers all three; do not follow it with per-month queries.
3. `search_threads` in Gmail with the item or seller name (one query, e.g. the
   model name or the dealer). The dealer quote, the lender's term sheet and the
   insurer's quote normally sit in one thread; take the thread id from the hit.

**Turn two:** one `get_thread` on that thread. Capture the all-in price, down
payment, principal, APR, term, quoted monthly payment, and the insurance delta
per month. Ignore appointment dates and deadlines — they are not part of this
answer. If the owner stated a price or a monthly figure themselves, use it and
skip the thread entirely. Anything missing → ask once, label it owner-stated.
**Never fill a price or rate from general knowledge.**

**Four calls, two round trips, and no more.** The payroll-debit read that used
to size a cushion is gone from the default path: the short verdict measures the
new monthly payment against an average month's debits, which call 2 already
gives. Read the payroll debits ONLY if the verdict is genuinely marginal — the
payment is a large share of an average month — and say why you looked.

## Step 2 — Compute (method in `reference/method.md`)

```
spendable          = Operating balance
cushion            = last payroll run + one week of average debits (marginal cases only)
afterCash          = spendable − price
afterDown          = spendable − down payment
payment            = term sheet's figure, or PMT(principal, APR/12, months)
net monthly impact = payment + insurance delta (+ fuel/maintenance if quoted)
                     − mileage reimbursement the vehicle replaces (owner-stated, else omit and say so)
```

- **Yes, in cash** if `afterCash ≥ cushion` AND `afterCash` stays above the
  year's lowest month-end after the year's drawdown is applied — i.e. the
  same fall that happened last year would not take it below the cushion.
- **Yes, if financed** if cash fails but `afterDown ≥ cushion` and the net
  monthly impact is small against the monthly nets (say what share of an
  average month's debits it is).
- **Not now** otherwise: name the first safe month and the smallest change
  that would make it fit.
- **Safest months** = the three highest month-ends; **risky months** = the
  three lowest, each with its balance and the one-line reason if the bank rows
  make it obvious (a January insurance + tax collision, the July payroll
  stack). Buy in a high month; never start a payment stream right before a low.
- **Second vehicle** = two payment streams and two insurance deltas landing
  on the three low months; defer unless the lows would still clear the
  cushion, and name what would change it (collections, a line of credit).

## Step 3 — Reply. Short, always.

This skill has ONE output shape: the short verdict above. There is no long
form here any more (2026-09-04). The owner asked whether a purchase fits; the
answer is a verdict, the number behind it, and a way to go deeper.

```
{Yes / No / Yes, if financed} — {the deciding number, one clause}.
{One sentence of why: the monthly figure netted against what it replaces, or the cash left against the cushion.}
{At most ONE caveat, only if it changes the answer.}
{One line: deeper analysis, or the lender package, is one question away.}
Not financial or tax advice — confirm terms with the lender and your accountant.
```

Under ~120 words. **No tables in the default answer**: no month-end grid, no
cash-vs-finance ledger, no second-unit paragraph, no tax-reserve aside, no
line-of-credit digression. Say once what only the bank supplied — the real
month-ends, the drawdown — in a clause, not a section.

A follow-up question earns the depth it asks for, and nothing more: answer
*that* question, in a few lines, using the figures already computed. Preparing
a lender application is a different job with its own skill — hand it to
`credit-readiness`, which the owner invokes explicitly.

## Follow-ups this skill expects

| Owner says | Do |
|---|---|
| "Cash or finance?" | Two lines, side by side; the cushion decides. Still no tables. |
| "When is the safest month?" | The highest three month-ends, with amounts; avoid the lowest three. |
| "What about a second one?" | Two payment streams against the three lows. |
| "What if I put $10k down?" | Recompute PMT with the new principal; one-time hit and monthly delta. |
| "What should I bring to the bank?" | Hand off to `credit-readiness` — say the name so the owner can invoke it; do not start assembling the package here. |
| "Show me the next 13 weeks" | Build a week-by-week table from open invoices, open bills and the payroll pattern; no skill, and not part of the default answer. |

## Degraded modes

| Missing | Effect |
|---|---|
| gmail | Ask the owner for price, terms, insurance and the deadline; label owner-stated. |
| quickbooks | Nothing changes — this skill does not read the books. |
| Paywhere | Stop — the verdict and the month-ends need cleared cash. |

## Reference

- [`reference/method.md`](reference/method.md) — month-end derivation, PMT, the cash and financed tests, second-vehicle test
