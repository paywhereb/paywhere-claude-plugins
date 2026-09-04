# Available cash — one set of terms

Several skills answer a version of "how much of this balance can I actually
use": can payroll clear on Friday, how much can go to savings, can this
purchase fit. They must answer with **the same arithmetic on the same
definitions**, or the demo contradicts itself on screen — two skills, two
figures, same money, in the same conversation.

The terms below are shared. Each skill says which ones its question needs and
over what window; none of them redefines a term locally.

```
available(window) = operating − committed(window) − earmarked          ← "will it clear?"
safe to move      = operating − committed(window) − earmarked − buffer ← "can I take money out?"
```

The difference is the buffer, and it is not arbitrary: answering *will this
clear* asks whether the balance survives what is already coming; answering
*can I take money out* has to leave the business able to absorb an ordinary
bad week afterwards.

## operating

The operating account's current balance, from `list_accounts`. It **already
nets pending card authorizations** — never subtract them again. Never count a
tax reserve or a savings account as available: the reserve holds customers'
money and savings is the cushion the question is about.

## committed(window)

Everything that will leave the operating account between today and the end of
the window. Three parts, all from data, none estimated:

- **The next payroll run(s).** Find the payroll processor's debits; the
  descriptor repeats on a fixed cadence. Use the **mean of the last three
  runs**, not the last one — payroll moves with overtime. Count every run
  whose date falls inside the window.
- **Bills due inside the window.** Open bills with a due date on or before the
  window end. Not the whole payables balance, and not bills due after it —
  though in a short window those can coincide, which is fine.
- **Recurring debits landing inside the window.** A descriptor that repeats in
  the same shape three or more months running on roughly the same day of
  month: rent, utilities, insurance, loan and lease payments, subscriptions.
  Count each at its most recent amount.

## earmarked

Money in the operating account that belongs to someone else and has not moved
yet — most often sales tax collected and not yet swept to a reserve. **One
definition, `tax-reserve-check`'s:**

```
earmarked = max(0, sales tax collected on RECEIVED payments not yet remitted − reserve balance)
```

Method, window and traps:
[`../tax-reserve-check/reference/true-available.md`](../tax-reserve-check/reference/true-available.md).
Never derive it by summing the sweeps that were missed — name those dates as
evidence, then state the figure from the formula. If it cannot be established
inside the skill's call budget, say so in one line, subtract nothing, and name
`tax-reserve-check` as the follow-up.

## buffer

The floor the operating account should not drop below once money leaves.

```
buffer = one payroll run (mean of the last three) + one week of average outflows
```

Not a percentage, not a round number, and **not the worst week in the
quarter** — the worst week contains a payroll *and* the month's supplier
statements, so it double-counts payroll and can swallow the entire answer.

## Saying it

Whatever the question, show the arithmetic with the numbers filled in — one
line per term, each with its amount, and the buffer with its basis in the
owner's own words ("one payroll run plus about a week of normal outflows").
A figure with no stated basis is not actionable, and the owner is often
reading it the next morning with nobody to ask.
