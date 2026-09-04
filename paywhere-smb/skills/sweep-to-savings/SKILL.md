---
name: sweep-to-savings
version: 1.0.0
description: >
  Answers "how much can I move to savings without getting tight" for a
  business whose operating account carries a cushion it never actually
  needs: the committed outflows between today and the end of the next pay
  cycle (recurring debits, the next payroll run, bills already due),
  the operating buffer the business's own history says it needs, and any
  money earmarked but not yet moved, subtracted from the operating balance
  to give ONE safe-to-sweep figure — staged as a transfer the owner
  approves on the bank's /confirm page. Three reads in one turn, one staged
  transfer. Use when the owner says "how much can I move to savings," "how
  much spare cash do I have," "can I put some cash away," "sweep the extra
  to savings," or "how much can I set aside this month." NOT for "show my
  balances" (one list_accounts call, no skill), not for moving money OUT of
  savings, and not for the sales-tax reserve — a tax reserve is a
  liability, not spare cash.
---

# Sweep to Savings

Most operating accounts carry a balance the business never touches, because
nobody has ever worked out what the real floor is. This skill works it out
from the account's own history and moves the difference — once, behind one
approval.

The safe-to-sweep figure is deliberately conservative: it is what is left
after everything already committed, plus a buffer the business has actually
needed, plus anything earmarked for someone else. Being wrong here bounces
payroll, so the skill rounds DOWN and says what the number is net of.

> `make_batch_payment` **never moves money**: it stages the transfer on the
> owner's open proposal and returns a confirmation URL of the form
> `https://<bank host>/confirm/<id>/<nonce>`. **Print that URL verbatim as
> the approval step**; the owner approves with a passkey, and only then does
> money move. **Never claim money has moved** — say "staged" / "awaiting your
> approval". Internal transfers are staged as a `{rail: "transfer",
> fromAccountNumber, toAccountNumber, amount}` item, **never
> `transfer_funds`**. Full path: [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md).

## Quick start — three reads in one turn, one staged transfer

```
User: "how much can I move to savings without getting tight?"
→ In ONE turn, in parallel (all three at once — never one after another):
    list_accounts                                                          (roles, balances, exact unmasked numbers)
    query_transactions {accountNumbers:[<operating>], direction:"debit",
                        dateFrom:<90 days ago>, status:["posted"], limit:400}   (recurring debits, payroll cadence, weekly outflow peaks)
    get_aged_payables                                                      (bills already due or due inside the window)
→ Window = today through the next payroll date + 7 days (payroll cadence comes from the processor debits)
→ safeToSweep = operating − committed − buffer − earmarked, floored at 0, rounded DOWN
→ Reply: the figure first, the three things it is net of, ONE transfer line, "Stage it?"
User: "yes"
→ ONE make_batch_payment {payments:[{rail:"transfer", fromAccountNumber:<operating>,
                                     toAccountNumber:<savings>, amount:<safeToSweep>}]}   → confirmation_url renders
→ One closing line: staged, nothing has moved.
```

Nothing else is read: no balance sheet, no P&L, no per-invoice loop, no
calendar. Budget: about 30 seconds, at most six calls including the stage.

## The four terms

**operating** — the operating account's current balance from
`list_accounts`. It already nets pending card authorizations; do not subtract
them again.

**committed** — every outflow that will leave the operating account inside
the window, from the debit history:

- **Recurring debits.** A descriptor that appears in the same shape three or
  more months running, on roughly the same day of month, is recurring: rent,
  utilities, insurance, loan and lease payments, subscriptions. Count each
  one whose day-of-month falls inside the window, at its most recent amount.
- **The next payroll run.** Find the payroll processor's debits (the
  descriptor repeats on a fixed cadence — weekly, biweekly, semi-monthly).
  The next run lands one cadence after the last one. Use the mean of the
  last three runs, not the last one alone; payroll varies with overtime.
  If the window spans two runs, count both.
- **Bills already due.** From `get_aged_payables`: everything current or
  overdue. Do not count bills due after the window.

**buffer** — the floor the operating account should not drop below. Derive
it, never assume a round number: take the **largest single week of outflows
in the trailing quarter** and **one payroll run**, and use whichever is
larger. That is the business's own worst ordinary week; a business that
survives it survives most surprises.

**earmarked** — money sitting in the operating account that belongs to
someone else and has not moved yet. The common case is collected sales tax
not yet swept to a reserve; see
[`../tax-reserve-check/reference/true-available.md`](../tax-reserve-check/reference/true-available.md)
for the short form. If a reserve account exists and this skill cannot
establish the shortfall inside its budget, say so in one line and subtract
nothing — then name `tax-reserve-check` as the follow-up rather than
guessing.

`safeToSweep = max(0, operating − committed − buffer − earmarked)`, rounded
DOWN to the nearest 100 of the account's currency. A figure at or below zero
is a legitimate answer: say the operating account has no spare cash this
cycle and why, and stage nothing.

## Output

Lead with the number and the transfer, then the arithmetic — never the other
way round.

1. **One line:** the safe-to-sweep figure, and the destination account.
2. **What it is net of** — three or four lines, one per term, each with its
   figure: committed outflows through `<date>`, the buffer and where it came
   from ("your worst week in the last quarter"), anything earmarked.
3. **The transfer line:** from, to, amount.
4. **"Stage it?"** — and stop. Do not stage on the same turn as the figure.
5. After the owner agrees: the staged transfer, the `/confirm` URL verbatim,
   and one line saying nothing has moved yet.

Keep the whole first reply under about 150 words. The owner asked one
question; a long answer costs more than it explains.

## Guardrails

- **Never sweep earmarked money.** Collected tax, customer deposits and
  retainage are liabilities that happen to be sitting in a checking account.
- **Never sweep from a reserve account**, and never present a sweep as
  freeing money it does not free — the total across accounts is unchanged.
- **One transfer, one approval.** If the owner asks for a different amount,
  stage that amount instead; do not stage twice.
- **Round down, and say what it is net of.** A figure with no stated basis
  is not actionable.
- If the business has no separate savings account, say so and stop; do not
  invent a destination.
