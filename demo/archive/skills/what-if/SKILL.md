---
name: what-if
version: 1.0.0
description: >
  Lever table over the 13-week cash forecast: applies one scenario at a time
  (revenue down 10%, the largest customer pays 30 days late, hire a tech,
  lose a service agreement, collect 15 days faster, stop paying vendors
  early, buy the van cash or financed, a line of credit) and reports each
  lever's change to the minimum balance and the new low week, then the best
  combination. Same engine the Excel model exposes as input cells. Read-only.
  Use when the owner says "what if revenue drops 10%," "what if my biggest
  customer pays 30 days late," "what if Westport pays late," "what if I hire
  a tech," "what if I stop paying vendors early," "what if I lose an
  agreement," "what if I collect 15 days faster," "run some what-ifs," or
  "what's the best combination."
---

# What-If

The forecast answers "how low does it get." This skill answers "and what
moves that number." Every lever is a mechanical change to the 13-week table
from [`../cash-flow-snapshot`](../cash-flow-snapshot/SKILL.md); the output is
Δ minimum balance per lever, never a narrative guess. Nothing is staged or
written to the books.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Baseline forecast"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

## Step 1 — Baseline

Reuse the 13-week table from this session if `cash-flow-snapshot` already ran
(same day, same opening balance); otherwise build it now with that skill's
Steps 1–4. Record **baseline minimum close and week**. Resolve "today" from the
actual date.

## Step 2 — Apply the levers the owner asked for (or all of them)

Each lever is one transformation of the `Lines` rows; recompute the weekly
closes; report Δ min.

| Lever | Transformation | Inputs needed |
|---|---|---|
| Revenue −X% (default 10) | Scale `Seasonal` and `Recurring billing` inflow rows by (1 − X/100). Open invoices are unchanged — they are already earned. | none |
| Largest customer +30 days | Find the customer with the largest open AR (books). Shift all of that customer's inflow rows +30 days. Name the customer. | none |
| Any named customer +N days | Same, for the customer the owner names ("what if Westport pays late" → that customer). | name |
| Collect 15 days faster | Shift every AR inflow row −15 days (floor: today). | none |
| Stop paying early | No change if bills are already modeled at due date; otherwise move habitually-early bills to due date (the `ap-timing` pattern). Also report the historical version: dollars paid early over 12 months and the mean days. | `ap-timing` data |
| Hire a tech | Add an outflow on each pay Friday: hourly rate × hours × 2 weeks × (1 + employer-tax rate). Rate from the books' employee records (`search_employees`, `search_time_activities`) or the owner; **ask if unknown**. Optionally add billable inflow after a ramp the owner states. | rate, hours |
| Lose an agreement | Remove one recurring customer's monthly billing rows. Candidate = the smallest-margin or most-delinquent agreement customer from the books; name it and let the owner pick another. | customer |
| Buy the van — cash | One-time outflow in the chosen week, amount from the quote (see [`../big-purchase-decision`](../big-purchase-decision/SKILL.md)). | quote |
| Buy the van — financed | Down payment in the chosen week + monthly payment from the term sheet thereafter, plus added operating cost minus mileage offset. | quote, term sheet |
| Line of credit $X | Floor each weekly close at 0 by drawing up to X; report the peak draw and how many weeks it is used. | X |

## Step 3 — Report

```
What-if — 13 weeks from {date}        Baseline minimum: ${m} in week {w} ({date})

Lever                                Δ minimum     New minimum   New low week
Revenue −10%                          −$…           $…            wk … (…)
{Largest customer} pays 30 days late  −$…           $…            wk …
Collect 15 days faster                +$…           $…            wk …
Stop paying early                     +$…           $…            wk …
Hire a tech (${rate}/h × {h}h)         −$…           $…            wk …
Lose {agreement customer}             −$…           $…            wk …
Van — cash in wk {n}                  −$…           $…            wk …
Van — financed (${pmt}/mo)            −$…           $…            wk …
LOC ${X}                              (peak draw $…, {n} weeks)

Best combination: {lever} + {lever} (+ {lever}) → minimum ${m'} in week {w'}
```

**Best combination** = the two or three levers with the largest positive Δ
that the owner controls (collections, pay-on-due, deferring a purchase),
applied together — interactions are recomputed, not summed. Say in one line
what each one requires of the owner.

## Step 4 — Point at the model

The same levers are the yellow input cells on the `Inputs` sheet of
`models/cash-13w.xlsx` (layout:
[`../cash-flow-snapshot/reference/model-layout.md`](../cash-flow-snapshot/reference/model-layout.md)).
If the model exists in the working folder, write this run's rows into its
`Levers` sheet; if not, offer to build it.

## Rules

- Never stage, propose or move money from here; "stop paying early" is a
  model change, not an instruction to `pay-bills`.
- Never invent a rate, price or payment — ask, or read it from the quote /
  books, and show the source next to the number.
- Δ values are versus the baseline built in Step 1; say so, and re-baseline
  if the owner changes an assumption mid-conversation.
- Not financial advice; timing assumptions are the owner's to confirm.
