---
name: tax-reserve-check
version: 1.0.5
description: >
  Answers "how much of my balance is actually mine" for a business that
  collects sales tax: sales tax on payments RECEIVED since the last
  remittance (from the invoices' explicit tax lines, grouped by the per-state
  liability account they post to) vs the Tax Reserve balance at the bank vs
  what is due on the 20th; lists the Fridays whose sweep into the reserve was
  skipped; computes true available cash; and proposes the catch-up transfer
  Operating → Tax Reserve as a staged proposal the owner approves on the
  bank's /confirm page. Not tax advice. Use when the owner says "how much of
  my balance is actually mine," "how much of my cash is really mine," "what's
  reserved for taxes," "is my tax reserve enough," "am I holding enough for
  sales tax," "what do I owe on the 20th," or "did I miss a tax sweep." NOT
  for "show my balances" or "what's my balance" — those are one list_accounts
  call and a two-sentence answer, no skill.
---

# Tax Reserve Check

The bank knows a fact the books cannot: how much money actually sits in the
Tax Reserve today. The books know a fact the bank cannot: how much sales tax
was inside the payments that landed. This skill puts the two together, names
the gap, names the Fridays that caused it, and stages the fix for approval.
It owns the full method; `../business-pulse/reference/true-available.md` is
the one-paragraph version used by the pulse and the daily brief.

> **Not tax advice.** Rates, jurisdictions and what is taxable are read from
> the books (the tax items and the liability accounts they post to). Say so
> in the output; the owner's CPA owns the rules.

**Approval (see [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md)):**
`make_batch_payment` never moves money — it stages the transfer on the
owner's open proposal and returns a confirmation URL of the form
`https://<bank host>/confirm/<id>/<nonce>`. Print that URL verbatim as the
approval step; the owner approves with a passkey and only then does money
move. Never say the transfer "is done" — say "staged, awaiting your
approval". Internal transfers go through `make_batch_payment` as a
`{rail: "transfer", fromAccountNumber, toAccountNumber, amount}` item, never
`transfer_funds`.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Accounts and balances"),
then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

## Step 1 — Accounts and balances (bank)

`list_accounts` → identify by role, never by number: **Operating** (the
primary checking), **Tax Reserve** (the savings account whose name mentions
tax or reserve), **Business Savings** (the other savings — reported, never
touched). `get_account_balance` on each. If no account reads as a tax
reserve, say so and run the rest as "collected vs nothing set aside".

## Step 2 — The window (bank)

The window is the **months whose tax has not been remitted yet**, not "the
days since the remittance debit". The 20th remittance pays the *previous*
calendar month, so: before the 20th, the window is last month + this month
to date; on or after the 20th, it is this month to date. Confirm the last
remittance with `query_transactions` on the Tax Reserve, `direction:
"debit"`, `descriptionContains: "DEPT OF REVENUE"` (or whatever stem the
remittance rows carry — see `reference/method.md`), `limit: 5`: a debit
on or after the 20th of month M paid month M−1, so the window starts on the
1st of month M. Fallback when none is found in 60 days: the 1st of the
previous month. Resolve every date from the actual current date; a payment
received on the 19th of last month is in the window, one received on the
day of the remittance debit is too — it belongs to a month not yet filed.

## Step 3 — Sales tax inside payments RECEIVED (books)

1. `search_payments {dateFrom: <window start>}` — payments received, not
   invoices issued. Receipt is what creates the obligation the reserve must
   cover; invoiced-but-unpaid tax is a future line, shown separately.
2. For each payment, follow its applied invoices (`search_invoices` by ref /
   DocNumber). Take the invoice's **explicit sales-tax line items** (the
   items whose income account is a sales-tax liability account) and pro-rate
   by the share of the invoice the payment covered
   (`tax collected = invoice tax × payment applied ÷ invoice total`).
3. Group by the **liability account the tax item posts to** (one per
   jurisdiction, e.g. "Sales Tax Payable - <state>"). Read those account
   names from the books; do not assume how many states or which.
4. Cross-check: `get_balance_sheet` (or `get_general_ledger` on the
   liability accounts) should show balances that move with your sum; a big
   gap means the books post tax on invoice (accrual) while the reserve
   follows receipts — say which basis each number is on.

Output: collected-not-remitted **by jurisdiction** and **total**.

## Step 4 — Shortfall and the next remittance

```
shortfall = max(0, collected-not-remitted total − Tax Reserve balance)
```

Next remittance: `search_events` / `list_events` on the calendar for the
remittance deadline (an event naming the revenue department or "sales tax");
if absent, use the 20th of this month (or next month if today is past it).
Show the amount due **by jurisdiction** and whether the reserve covers it
today. If the reserve is short, say by how much and how many days remain.

## Step 5 — Missed Friday sweeps (bank)

`query_transactions` on the Tax Reserve, `direction: "credit"`,
`descriptionContains: "TAX RESERVE"` (the transfer-in stem), `dateFrom:
<today − 12 months>` — the whole year, not just the current remittance
window: a sweep skipped last autumn is still a missed sweep, and the owner
asked which Fridays, not which recent Fridays. Build the list of Fridays in
those 12 months; a Friday with no incoming transfer is a **missed sweep**. For each sweep found,
compare its amount with the tax inside that week's received payments (Step
3 sliced Mon–Sun): a sweep that matches the week's *invoiced* tax instead of
*received* tax is a "swept on invoiced, not received" note, not a miss.
Name the Fridays; do not just count them.

## Step 6 — True available cash

```
true available = Operating balance − shortfall
```
(`query_transactions {status: ["pending"]}` on Operating for the pending
sum.) Business Savings is not in the formula. Show every term with its
number. Then two separate lines the reserve does **not** cover: the owner's
quarterly estimated taxes (bank debits with an IRS stem from Operating; next
date from the calendar) and any local business tax — say plainly "paid from
Operating, not from the reserve" so the owner does not double-count.

## Step 7 — Propose the catch-up transfer

If `shortfall > 0`:

- Interactive: show one line — Operating → Tax Reserve, amount = shortfall,
  why (the missed Fridays) — and ask "stage the catch-up?". Unattended (see
  [`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md)): stage it without asking.
- Stage with ONE `make_batch_payment`:
  `{payments: [{rail: "transfer", fromAccountNumber: <Operating, exact unmasked
  from list_accounts>, toAccountNumber: <Tax Reserve, exact unmasked>, amount:
  <shortfall>}]}`.
- Print `confirmation_title` and `confirmation_url` verbatim, then:
  *"Nothing has moved. Approve on the bank's page with your passkey; I can
  verify the transfer posted afterwards."* Never call `transfer_funds`.
- If the owner later says "I approved", verify with `query_transactions` on
  the Tax Reserve (`direction: "credit"`, today, the amount) before saying
  anything posted.

If `shortfall == 0`, say the reserve is funded and by how much it exceeds
what is owed. Never propose moving money **out** of the reserve for anything
but a remittance, and never propose touching Business Savings.

## Output shape

```
Tax Reserve Check — {date}                          (not tax advice)
Window: {first day of the oldest unremitted month} … {today} (months not yet remitted; last remittance {date} paid {month})

Collected on RECEIVED payments, not yet remitted
  {jurisdiction A}   ${x}     {jurisdiction B}   ${y}     Total ${t}
Tax Reserve balance                                  ${r}
Shortfall                                            ${s}   ← {n} Friday sweeps missed: {dates}
Due {remittance date}: ${t} ({A} ${x}, {B} ${y}) — reserve {covers / short ${s}}

True available = Operating ${o} − shortfall ${s} = ${ta}   (pending card authorizations ${p} already netted by the bank)
Not covered by the reserve: owner estimate ${e} due {date} (from Operating)

Staged for approval: transfer Operating → Tax Reserve ${s}
{confirmation_title}
{confirmation_url}
Nothing has moved until you approve this on the bank's page.
```

## Degradation

| Missing | Effect |
|---|---|
| Paywhere | Stop — no reserve balance, no sweep history, nothing to stage. |
| quickbooks | Report reserve balance, sweeps found/missed and the remittance date; say the collected figure cannot be computed and skip the proposal. |
| google calendar | Use the 20th; say so. |

## Reference

- `reference/method.md` — formulas, pro-rating, descriptor stems to look for, the Friday test
- `../business-pulse/reference/true-available.md` — the short form
- `../tax-sweep-agent/SKILL.md` — the scheduled Friday version of Step 3 + Step 7
- `../tax-season-organizer/SKILL.md` — owner income-tax estimates and 1099s (not sales tax)
