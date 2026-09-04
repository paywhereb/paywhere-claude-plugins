---
name: sweep-to-savings
version: 1.1.1
description: >
  The idle-cash sweep, automated (scheduled agent). On its run day it works
  out how much of the operating balance is genuinely spare — net of everything
  committed through the next pay cycle, the operating buffer the business's
  own history says it needs, and any money earmarked and not yet moved — then
  writes savings/YYYY-MM-DD.md and STAGES one operating-to-savings transfer
  for the owner to approve on the bank's /confirm page with a passkey. Four
  reads in one turn, one staged transfer. Proposes, never executes; never
  transfer_funds. Use when the owner says "run the savings sweep," "sweep the
  spare cash to savings," "how much can I move to savings," "how much spare
  cash do I have," or schedules "every Friday at 6am run the savings sweep"
  (any day the owner picks). NOT for the sales-tax reserve — that is
  tax-sweep-agent, and a tax reserve is a liability, not spare cash.
---

# Sweep to Savings (agent)

Most operating accounts carry a balance the business never touches, because
nobody has ever worked out what the real floor is. This agent works it out from
the account's own history and stages the difference — once, behind one
approval, on a schedule.

Follows [`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md) and
[`../_shared/APPROVAL.md`](../_shared/APPROVAL.md). The load-bearing rules,
repeated because this file is loaded on its own:

> Stamp `sessionType: "scheduled"` and `taskId: "sweep-to-savings"` on every
> tool call. Write `savings/YYYY-MM-DD.md`; if today's exists, stop and say so.
> **Propose, never execute**: the transfer is staged as ONE
> `make_batch_payment` with a single `{rail: "transfer", fromAccountNumber,
> toAccountNumber, amount}` item — never `transfer_funds` — and the returned
> `/confirm/<id>/<nonce>` URL is printed verbatim with its
> `confirmation_title` and *"Nothing has moved until you approve this on the
> bank's page."* Never say "swept", "moved" or "transferred". A missing
> connector removes a term, not the run. No email, no invites, no questions —
> **nobody is there to answer them**, which is also why the run shows its
> arithmetic in full.

The figure is deliberately conservative: being wrong here bounces payroll, so
it rounds DOWN and says what the number is net of.

## Schedule (Cowork Desktop → scheduled task)

| Field | Value |
|---|---|
| Schedule | `Every Friday at 6:00am` — any day the owner picks; a weekly cadence suits a business paid weekly, monthly suits one paid monthly |
| Prompt | `Run the savings sweep` |

Cowork must be open for the run to fire. To see a run on demand, use the same
prompt interactively.

## Quick start — six calls, no questions

```
Scheduled task fires: "Run the savings sweep"
→ In ONE turn, in parallel (all four reads at once — never one after another):
    list_accounts                                                          (roles, balances, exact unmasked numbers)
    query_transactions {accountNumbers:[<operating>], direction:"debit",
                        dateFrom:<90 days ago>, status:["posted"], limit:400}   (recurring debits, payroll cadence, average weekly outflow)
    search_bills {status:"open", due_before:<window end>}                  (ONLY bills due inside the window)
    get_sales_tax_collected {date_from:<1st of the month last remitted>}   (earmarked: collected, not yet swept)
→ Window = today through the next payroll date + 7 days (payroll cadence comes from the processor debits)
→ safeToSweep = operating − committed − buffer − earmarked, floored at 0, rounded DOWN
→ If safeToSweep is 0: write the file saying so, stage NOTHING, and stop.
→ ONE make_batch_payment {payments:[{rail:"transfer", fromAccountNumber:<operating>,
                                     toAccountNumber:<savings>, amount:<safeToSweep>}]}   → confirmation_url renders
→ write_file savings/YYYY-MM-DD.md — the figure, the arithmetic, the staged transfer, the /confirm URL
→ Run output: the figure, what it is net of, the transfer, the link, "nothing has moved until you approve it".
```

**Nobody is asked anything.** There is no "Stage it?" turn: the run stages the
transfer itself and the owner approves it — or does not — when they next open
Cowork. That is the whole point of a scheduled agent, and it is safe precisely
because staging is not moving.

Nothing else is read: no balance sheet, no P&L, no per-invoice loop, no
calendar, no email. Four reads, one stage, one file — six calls. If the
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

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "2. Read — four calls, one
turn"), then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly. The owner reads the
finished run in the morning, but the steps are what a presenter watches live.

### 1. Dedupe and stamp

Stamp `sessionType: "scheduled"` and `taskId: "sweep-to-savings"` on every
call. If `savings/YYYY-MM-DD.md` already exists for today, the sweep has run:
stop and say so. Never stage a second transfer for the same day.

### 2. Read — four calls, one turn

The four reads in the quick start, issued together, never one after another:
balances and roles, ninety days of operating debits, the open bills due inside
the window, and the sales tax collected since the month last remitted.

### 3. Compute the safe figure

Window = today through the next payroll date + 7 days. Then
`safeToSweep = operating − committed − buffer − earmarked`, floored at 0 and
rounded DOWN to the nearest 100 — every term as defined above and in
[`../_shared/AVAILABLE-CASH.md`](../_shared/AVAILABLE-CASH.md). Sanity-check a
zero before reporting one.

### 4. Stage — ONE `make_batch_payment`

A single `{rail: "transfer", fromAccountNumber: <operating>, toAccountNumber:
<savings>, amount: <safeToSweep>}` item. No `dryRun` first — an agent has
nobody to show a table to — and never `transfer_funds`. If the figure is zero,
skip this step entirely and record why. Read back `confirmation_url`,
`confirmation_title` and `expires_at`.

### 5. Write `savings/YYYY-MM-DD.md`

The figure, the arithmetic one line per term, the staged transfer and the
`/confirm` URL verbatim. This file is what the owner actually reads; the run
output is its summary.

### 6. Run output

What Cowork shows in the notification: the figure, what it is net of, the
transfer, the link, and one line saying nothing has moved until it is
approved.

## Output — the figure, then how you got there

The run writes `savings/YYYY-MM-DD.md` and says the same thing in its output.
**Show the work**: the owner reads this the next morning with nobody to ask, so
a bare figure is not actionable. The derivation is required — three or four
lines, not three or four sections.

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
3. **The staged transfer:** from, to, amount, the `confirmation_title`, and
   the `/confirm/<id>/<nonce>` URL verbatim.
4. **One closing line:** nothing has moved until the owner approves it on the
   bank's page.
5. One extra line naming `tax-reserve-check` for the earmarked shortfall is
   welcome; anything more is not.

It stays a **run report, not an essay**: no 13-week forecast, no month-by-month
history, no per-invoice ledger, no unrelated analysis. Naming four vendors
inline is right; itemising four bills as a table is not.

**Sanity-check a zero before you report it.** A healthy operating account
should usually have something to sweep. If the figure lands at or below zero,
re-check the two mistakes that cause a false zero — counting open bills that
fall due after the window, and using a worst-case week as the buffer — before
writing that there is nothing spare. A legitimate zero is fine: say why, stage
nothing.

## Guardrails

- **Never sweep earmarked money.** Collected tax, customer deposits and
  retainage are liabilities that happen to be sitting in a checking account.
- **Never sweep from a reserve account**, and never present a sweep as
  freeing money it does not free — the total across accounts is unchanged.
- **One transfer, one approval, one run.** Never stage twice. If today's
  `savings/YYYY-MM-DD.md` already exists, the sweep has run — stop and say so.
- **Round down, and say what it is net of.** A figure with no stated basis
  is not actionable.
- If the business has no separate savings account, say so and stop; do not
  invent a destination.
