---
name: big-purchase-decision
version: 1.0.6
description: >
  Answers "can I afford this?" for a large purchase (a work van, a truck,
  equipment) from cleared cash rather than book profit, in five tool calls:
  today's balance, twelve months of monthly cash from the bank (the year's
  highs and lows), the last payroll debits (the cushion), and the dealer /
  lender / insurer emails for the price, terms and deadline. A single narrow
  question ("can I carry the payment?") gets a short verdict in under 120
  words; only a multi-part ask gets the full package — cash vs finance, the
  safest months to buy, the risky months, whether a second vehicle fits —
  and "what to bring the bank" hands off to credit-readiness. Read-only, stages nothing. Use when the
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

## Answer the question that was asked — two shapes

Read what the owner actually asked before deciding how much to write. A long
answer to a short question is a wrong answer: it costs the reader more than it
tells them, and it spends minutes the owner is watching tick by.

| The owner asked | Shape | Reads |
|---|---|---|
| **ONE narrow question** — "can I afford it", "can I carry the monthly payment", "is $X a month doable" | **Short verdict** (below), under ~120 words. No tables, no month-by-month, no second-unit digression, no bank-meeting aside. | The seller thread (search + `get_thread`) for price and terms, `list_accounts`, and the monthly-nets call only if the share is worth stating |
| **SEVERAL questions at once**, or an explicit ask for the analysis — "cash or finance, when should I buy, and what about a second one" | **Full package** — Steps 1–3 below | All five |

**Short verdict** — four lines, then stop:

```
{Yes / No / Yes, if financed} — {the deciding number, one clause}.
{One sentence of why: the monthly figure, netted against what it replaces or against what an average month clears.}
{At most ONE caveat, and only if it changes the answer.}
{One line offering the full picture — cash vs finance, safest months, a second unit — then stop.}
```

A hedge is not a verdict: "Yes, if financed" is one, "it depends whether you
finance" is not. Pick the answer the numbers support and say it plainly. Do
**not** volunteer the cash-vs-finance comparison, the twelve month-ends, the
tax reserve or the line of credit in the short shape — each is one question
away, and the owner will ask if they want it.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1, `TaskUpdate` to `in_progress` when you begin a step and `completed`
when it's done — this drives Cowork's progress display.

## Step 1 — Read everything in ONE turn (four calls, in parallel)

1. `list_accounts` → Operating (primary checking by role). Spendable cash is
   **Operating only**; the Tax Reserve holds customers' sales tax and Business
   Savings is the owner's cushion. The bank's balance already nets pending
   card authorizations — do not subtract them. Do **not** compute a reserve
   shortfall here; if the reserve looks short, say so in one clause and point
   at tax-reserve-check.
2. `query_transactions {accountNumbers: [Operating], aggregate: true, groupBy:
   "month", dateFrom: <first day of the month 12 months ago>}` → twelve monthly
   nets. **Month-end balance** for each month = today's balance minus the net
   of every later month (walk backwards from today). Rank the twelve
   month-ends: the **three highest** are the safest purchase months, the
   **three lowest** are the risky months. Also note the deepest drop from any
   month-end to a later one (the year's drawdown) and the average monthly
   debits.
3. `query_transactions {accountNumbers: [Operating], direction: "debit",
   descriptionContains: "<the payroll processor's name as it appears on the statement>", limit: 6}` →
   the last payroll run (net + tax debits on the same day). **Cushion** = one
   payroll run + one week of average debits (from call 2). Not a percentage.
4. `search_threads` in Gmail with the item or seller name (one query, e.g. the
   model name or the dealer). The dealer quote, the lender's term sheet and the insurer's
   quote normally sit in one thread; take the thread id from the hit.

Then one `get_thread` on that thread (the fifth call). Capture: all-in price
(vehicle + upfit + wrap + fees), down payment, principal, APR, term, quoted
monthly payment, the insurance delta per month, and **the deadline** — the
dealer names the appointment date and how long the quote is good; the lender
names the meeting. No calendar call: the dates are in the mail. If the owner's
stated price differs from the quote, use the owner's for the verdict and show
the quote's beside it. Anything missing → ask once, label it owner-stated.
**Never fill a price or rate from general knowledge.**

## Step 2 — Compute (method in `reference/method.md`)

```
spendable          = Operating balance
cushion            = last payroll run + one week of average debits
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

## Step 3 — Reply, FULL PACKAGE ONLY (under ~25 lines)

This is the multi-part answer. If the owner asked one narrow question, the short
verdict above is the whole reply — do not fall through to this template.

```
{Yes / No / Yes, if financed} — {one sentence with the deciding number}.
{One sentence: deadline from the dealer's email, and what to say at the appointment.}

Purchase decision — {date}
Quote ${price} all-in ({seller}, good through {date}) · Finance ${down} down, ${principal} at {apr}% / {n} mo → ${pmt}/mo ({lender}) · Insurance +${x}/mo
Net monthly cash impact: ${net}

Cash today:   ${spendable} − ${price} = ${afterCash}  vs cushion ${cushion} (payroll + a week)  → {clears / does not}
Financed:     ${spendable} − ${down}  = ${afterDown}  → {clears}; ${net}/mo is {p}% of an average month's debits

| Month-ends (12 mo) | |
| Highest | {Mon} ${a} · {Mon} ${b} · {Mon} ${c}  ← safest to buy |
| Lowest  | {Mon} ${d} · {Mon} ${e} · {Mon} ${f}  ← a second payment stream would land here |

Second unit: {defer / fits} — {one clause}.
Recommendation: {one or two sentences}.
Want the package for the bank meeting on {date}? (credit-readiness)
Not financial or tax advice — confirm terms with the lender and your accountant.
```

Say once what only the bank supplied: the real month-ends and the drawdown,
which the P&L cannot show.

## Follow-ups this skill expects

| Owner says | Do |
|---|---|
| "Cash or finance?" | The two lines above, side by side; the cushion decides. |
| "When is the safest month?" | The highest three month-ends, with amounts; avoid the lowest three. |
| "What about a second one?" | Two payment streams against the three lows. |
| "What if I put $10k down?" | Recompute PMT with the new principal; one-time hit and monthly delta. |
| "What should I bring to the bank?" | Hand off to `credit-readiness`. |
| "Show me the next 13 weeks" | Build a week-by-week table from open invoices, open bills and the payroll pattern; no skill, and not part of the default answer. |

## Degraded modes

| Missing | Effect |
|---|---|
| gmail | Ask the owner for price, terms, insurance and the deadline; label owner-stated. |
| quickbooks | Nothing changes — this skill does not read the books. |
| Paywhere | Stop — the verdict and the month-ends need cleared cash. |

## Reference

- [`reference/method.md`](reference/method.md) — month-end derivation, PMT, the cash and financed tests, second-vehicle test
