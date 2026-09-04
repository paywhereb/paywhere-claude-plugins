---
name: sweep-to-savings
version: 1.0.4
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

## Quick start — four reads in one turn, one staged transfer

```
User: "how much can I move to savings without getting tight?"
→ In ONE turn, in parallel (all four at once — never one after another):
    list_accounts                                                          (roles, balances, exact unmasked numbers)
    query_transactions {accountNumbers:[<operating>], direction:"debit",
                        dateFrom:<90 days ago>, status:["posted"], limit:400}   (recurring debits, payroll cadence, average weekly outflow)
    search_bills {status:"open", due_before:<window end>}                  (ONLY bills due inside the window)
    get_sales_tax_collected {date_from:<1st of the month last remitted>}   (earmarked: collected, not yet swept)
→ Window = today through the next payroll date + 7 days (payroll cadence comes from the processor debits)
→ safeToSweep = operating − committed − buffer − earmarked, floored at 0, rounded DOWN
→ Reply: the figure first, the three things it is net of, ONE transfer line, "Stage it?"
User: "yes"
→ ONE make_batch_payment {payments:[{rail:"transfer", fromAccountNumber:<operating>,
                                     toAccountNumber:<savings>, amount:<safeToSweep>}]}   → confirmation_url renders
→ One closing line: staged, nothing has moved.
```

Nothing else is read: no balance sheet, no P&L, no per-invoice loop, no
calendar. Four reads plus the stage is five calls; the budget is six. If the
books are not connected, skip the tax call, subtract nothing for earmarked
money, and say in one line that the figure does not account for collected tax.

## The four terms

Defined once in [`../_shared/AVAILABLE-CASH.md`](../_shared/AVAILABLE-CASH.md)
and shared with `plan-payroll`, which answers the other half of the same
question. That skill asks *will payroll clear* and subtracts committed and
earmarked; this one asks *can I take money out* and subtracts the buffer too.
Same definitions, same figures — the demo must never show two numbers for the
same money. The summary below is the local restatement; the shared file wins
if they ever drift.

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
- **Bills due inside the window — not every open bill.** Read open bills
  filtered by due date on or before the window end (`search_bills`); if only
  `get_aged_payables` is available, count the overdue buckets plus what is due
  this week and **exclude the rest of "current"**, which is mostly bills due
  weeks from now. Counting the whole payables balance is the single easiest
  way to arrive at a wrong zero.

**buffer** — the floor the operating account should not drop below:

```
buffer = one payroll run (mean of the last three) + one week of average outflows
```

Same cushion the purchase decision uses, so two skills never give the owner
two different floors. Do **not** use the worst week in the quarter: the worst
week contains a payroll AND the month's supplier statements, so it
double-counts payroll and quietly swallows the entire answer.

**earmarked** — money sitting in the operating account that belongs to someone
else and has not moved yet. The common case is sales tax collected and not yet
swept to a reserve.

**Use ONE definition of that shortfall, the reserve skill's**, so two skills
can never put two different numbers for the same money on the same screen:

```
earmarked = max(0, sales tax collected on RECEIVED payments not yet remitted − reserve balance)
```

The window, the one call that produces the collected figure, and the traps are
in [`../tax-reserve-check/reference/true-available.md`](../tax-reserve-check/reference/true-available.md)
— follow it exactly. In particular:

- **Never derive the shortfall by adding up the sweeps that were missed.** Two
  skipped Fridays is a symptom, not the amount: the sweeps are approximations
  of a week's tax, and summing them lands near the right number while
  disagreeing with `tax-reserve-check` by a few hundred. Name the missed dates
  as evidence, then state the shortfall from the formula above.
- The window is the **months not yet remitted**, not "since the last sweep"
  and not "since the last remittance debit".

If the shortfall cannot be established inside this skill's budget, say so in
one line, subtract nothing, and name `tax-reserve-check` as the follow-up
rather than guessing.

`safeToSweep = max(0, operating − committed − buffer − earmarked)`, rounded
DOWN to the nearest 100 of the account's currency. A figure at or below zero
is a legitimate answer: say the operating account has no spare cash this
cycle and why, and stage nothing.

## Output — the figure, then how you got there

Lead with the number and the transfer. Then **show your work**: the owner is
being asked to move real money, often reading this the next morning with
nobody to ask, so a bare figure is not actionable. The derivation is required,
and it is three or four lines — not three or four sections.

1. **One line:** the safe-to-sweep figure and the destination account.
2. **"That's net of:"** one line per term, each with its amount:
   - **Committed through `<window end>`** — the total, then the pieces in a
     clause: the payroll run (say it is the mean of the last three), the bills
     due inside the window (name the vendors), the recurring debits landing in
     that window.
   - **Operating buffer** — the amount, and its basis in the owner's own words
     ("one payroll run plus about a week of normal outflows"), never a round
     number with no story.
   - **Earmarked, not yours to sweep** — sales tax collected and not yet
     swept, with the sweep days that were missed if the history shows them.
3. **The transfer line:** from, to, amount.
4. **"Stage it?"** — and stop. Do not stage on the same turn as the figure.
   One extra line offering `tax-reserve-check` for the earmarked shortfall is
   welcome; anything more is not.
5. After the owner agrees: the staged transfer, the `/confirm` URL verbatim,
   and one line saying nothing has moved yet.

It stays a **reply, not a report**: no 13-week forecast, no month-by-month
history, no per-invoice ledger, no unrelated analysis. Naming four vendors
inline is right; itemising four bills as a table is not.

**Sanity-check a zero before you report it.** A healthy operating account
should usually have something to sweep. If the figure lands at or below zero,
re-check the two mistakes that cause a false zero — counting open bills that
fall due after the window, and using a worst-case week as the buffer — before
telling the owner there is nothing spare.

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
