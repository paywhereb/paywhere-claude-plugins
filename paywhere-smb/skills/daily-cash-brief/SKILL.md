---
name: daily-cash-brief
version: 1.0.7
description: >
  The scheduled morning cash brief (autonomous agent). Every weekday it reads
  the bank, the books and the calendar in one parallel turn, writes
  briefs/YYYY-MM-DD.md (balances by role, true available cash, this week's
  dated obligations, exceptions: overdue invoices with no bank credit, bills
  due within 7 days, not-yet-due bills to hold because the vendor is
  habitually paid early, the tax-reserve shortfall, pending authorizations)
  and STAGES one batch (reserve top-up transfer + bills due within 7 days)
  for the owner to approve on the bank's /confirm page with a passkey.
  Proposes, never executes; drafts only; degrades gracefully; about ten tool
  calls (a scheduled agent is exempt from the six-call bar). Use when the
  owner says "run my morning cash brief," "daily cash brief," "morning
  brief," or schedules "every weekday at 7:30 run my morning cash brief."
  NOT for "what's my cash" or "show my balances" asked in conversation —
  those get a direct answer, not a brief.
---

# Daily Cash Brief (agent)

The morning brief, run unattended before the owner opens the laptop: one
parallel read of the bank, the books and the calendar, one markdown file,
and the day's money movement staged for one passkey approval. It follows
[`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md) and
[`../_shared/APPROVAL.md`](../_shared/APPROVAL.md). The load-bearing rules,
repeated because this file is loaded on its own:

> Stamp `sessionType: "scheduled"` and `taskId: "daily-cash-brief"` on every
> bank tool call. Write `briefs/YYYY-MM-DD.md`; if today's file already
> exists, stop and say so. **Propose, never execute**: the reserve top-up and
> the due bills are staged with ONE `make_batch_payment` (the transfer as a
> `{rail: "transfer", fromAccountNumber, toAccountNumber, amount}` item —
> never `transfer_funds`), and the returned `/confirm/<id>/<nonce>` URL is
> printed verbatim in the run output with its `confirmation_title` and the
> sentence *"Nothing has moved until you approve this on the bank's page."*
> Never say "paid" or "transferred". A missing connector removes a section,
> not the run. Drafts only — this skill creates none by default; it never
> sends mail or creates events.

## Schedule (Cowork Desktop → scheduled task)

| Field | Value |
|---|---|
| Schedule | `Every weekday at 7:30am` |
| Prompt | `Run my morning cash brief` |
| Working folder | the owner's finance folder (where `briefs/` lives) |

Cowork must be open for the run to fire. To see the output without waiting
for 7:30, run the same prompt interactively; the file and the staged
proposal are identical.

Interactive invocation ("run my morning cash brief" typed by the owner) is
fine: same output, `sessionType: "interactive"`, and you may show the batch
table and ask "Stage these?" before staging.

## Quick start — about ten calls

```
Dedupe: briefs/YYYY-MM-DD.md exists? → print "Today's brief exists at briefs/YYYY-MM-DD.md — skipping." and stop.
→ In ONE turn, in parallel (sessionType "scheduled", taskId "daily-cash-brief" on every bank call):
    list_accounts                                                     (balances by role; exact unmasked numbers)
    query_transactions {status:["pending"]}                           (pending authorizations — reported, never subtracted)
    query_transactions {direction:"credit", dateFrom:<14 days ago>}   (all accounts: Operating credits to match against AR; Tax Reserve credits = recent sweeps)
    get_aged_receivables                                              (open invoices, per invoice)
    get_vendor_payment_timing                                         (open bills: dueWithin7Days, notYetDue with vendorHabituallyPaidEarly)
    get_sales_tax_collected {date_from:<1st of the oldest month not yet remitted>}   (collected.total → reserve shortfall)
    list_events {today → +7 days}                                     (dated obligations)
    list_saved_payees                                                 (name → rail)
→ Compute the brief (below).
→ make_batch_payment (ONE call: transfer line + due bills)            → confirmation_url
→ write_file briefs/YYYY-MM-DD.md
→ Run output: the notification text (below).
```

A scheduled agent is exempt from the interactive six-call bar; say the count
in the brief's footer. Do **not** add calls: no `search_bills`,
`search_bill_payments`, `search_payments` or `get_aged_payables` — the two
report tools cover them.

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Dedupe and stamp"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

### 1. Dedupe and stamp

- Resolve today from the actual date. If `briefs/YYYY-MM-DD.md` exists →
  print "Today's brief exists at briefs/YYYY-MM-DD.md — skipping." and stop.
- From here every Paywhere call carries `sessionType: "scheduled"` and
  `taskId: "daily-cash-brief"`.

### 2. Read everything in ONE parallel turn

- **Paywhere**: `list_accounts` — identify by role, never by number:
  **Operating** (primary checking), **Tax Reserve** (the savings account
  whose name mentions tax or reserve), **Business Savings** (the other
  savings — reported, never touched). Balances come back with the accounts;
  call `get_account_balance` only for an account that returned none.
  `query_transactions {status: ["pending"]}` for the authorizations.
  `query_transactions {direction: "credit", dateFrom: <14 days ago>}` with
  no `accountNumbers`, so one result carries the Operating credits (to match
  against open invoices) and the Tax Reserve credits (the recent sweeps).
  `list_saved_payees` once.
- **quickbooks** (read-only): `get_aged_receivables`;
  `get_vendor_payment_timing` (every open bill with `daysUntilDue`, split
  into `dueWithin7Days` and `notYetDue`, the latter flagged
  `vendorHabituallyPaidEarly`); `get_sales_tax_collected {date_from}` where
  `date_from` is the 1st of the oldest month whose tax has not been remitted
  yet. With a remittance on the 20th that pays the previous month: on or
  before the 20th the window opens on the 1st of **last** month; after the
  20th, on the 1st of **this** month. If the owner's remittance day differs,
  use it (method in
  [`../tax-reserve-check/SKILL.md`](../tax-reserve-check/SKILL.md)).
- **google calendar**: `list_events` today → +7 days.
- If Paywhere is unreachable: write a one-line brief saying so and stop.
  Any other missing connector: its section reads "unavailable".

### 3. Compute the brief

1. **Balances + true available** — `reserve shortfall = collected.total −
   Tax Reserve balance`, floor 0; `true available = Operating − shortfall`.
   The bank's balance **already nets pending authorizations**: list them
   (descriptors + total) but never subtract them. Business Savings and the
   Tax Reserve are never spendable. A skipped sweep is *why* the reserve is
   short, not *how much* — the shortfall is always the report's total minus
   the balance. Note the last sweep credit's date from the 14-day result and
   name the weeks in `byWeek` that collected tax but show no matching
   reserve credit.
2. **Today / this week** — calendar events with amounts (payroll, the
   remittance, estimates, appointments). Do not invent amounts the calendar
   lacks; if payroll falls inside the week and no amount is recorded, list
   the date and point at `plan-payroll`.
3. **Exceptions**, each with dollars and evidence:
   - **Overdue invoices with no matching bank credit** — from
     `get_aged_receivables`, **one line per invoice**: DocNumber, customer,
     open amount, days past due, largest first. An invoice whose amount (±
     $0.50) or customer stem appears in the 14-day credits is "received,
     not yet booked" and excluded. Never a customer's total open balance,
     never an invoice that is not yet due.
   - **Bills due within 7 days** — `dueWithin7Days`: vendor, DocNumber,
     open `balance`, due date, rail from saved payees.
   - **HOLD** — `notYetDue` items with `vendorHabituallyPaidEarly: true`:
     vendor, amount, due date, "pay on {dueDate}". Never staged.
   - **Reserve** — collected in the window (`collected.total`, split
     `byItem` by jurisdiction) vs the Tax Reserve balance, the shortfall,
     the weeks with no sweep credit.
   - **Pending authorizations** — count and total, already netted.

### 4. Decide what to stage (rule-based, no judgment calls)

Stage exactly these, nothing else:

- **Reserve top-up**: if shortfall > 0, one transfer line Operating → Tax
  Reserve for the shortfall (exact unmasked account numbers from
  `list_accounts`).
- **Bills due within 7 days** that (a) have a saved payee (rail from
  `list_saved_payees`; `recipientId` = the payee's name; wire lines for wire
  payees), and (b) are not flagged as duplicates by the server (same payee +
  amount as a recent payment — honour the flag, list the line under "already
  staged/posted" instead).

Everything else goes under **Needs you**: due bills for vendors without a
saved payee, the HOLD list with its pay-on dates, a batch that would exceed
true available (stage nothing; list the conflict), a payroll date inside the
week, and the customers the owner would chase — **this skill creates no
Gmail drafts** unless the owner has told it to (then it follows
[`../invoice-chase`](../invoice-chase/SKILL.md), drafts only). Say that in
the brief.

### 5. Stage — ONE `make_batch_payment`

Build the item list (transfer first, then ACH, then wire) and call
`make_batch_payment` once with `sessionType: "scheduled"` and `taskId:
"daily-cash-brief"`. No dry run. A rejected line comes back named in
`invalid_items` — fix that line (or drop it to Needs you) and re-submit
once. From the response keep `confirmation_url`, `confirmation_title`,
`total_amount`, `by_rail`, `lines[]`, `expires_at`. If the response is
`{ error }`, record it in the brief and move on. If there is nothing to
stage, say "Nothing to stage today."

### 6. Write `briefs/YYYY-MM-DD.md` (`write_file`, markdown)

```
# Cash brief — {date} (scheduled 7:30)

**True available: ${x}** = Operating ${a} − reserve shortfall ${b}   (pending ${c} already netted by the bank)
Operating ${a} · Tax Reserve ${r} (collected ${t}, short ${b}) · Business Savings ${s} (not counted)

## Today / this week
- {date} {calendar item} ${amount if recorded}
- {date} sales-tax remittance ${t} ({by jurisdiction})

## Exceptions
- Overdue, no credit yet: {DocNumber} {customer} ${amt}, {n} days late …
- Received but not booked: {DocNumber} {customer} ${amt} ({descriptor}, {date})
- Due within 7 days: {vendor} {DocNumber} ${amt} {rail} due {date} …
- HOLD (habitually paid early): {vendor} ${amt} due {date} — pay on {date}
- Reserve: collected ${t} since {window start}, held ${r}, short ${b}; weeks with no sweep credit: {week starts}
- Pending authorizations: {n} items, ${c} (already netted)

## Staged for approval — {confirmation_title}
{confirmation_url}
Nothing has moved until you approve this on the bank's page. Expires {expires_at}.
| Line | Payee / transfer | Amount | Rail |
…

## Needs you
- …

Sources: Paywhere ✓ · quickbooks ✓/✗ · calendar ✓/✗ · gmail ✓/✗ · {n} tool calls
```

### 7. Run output (what Cowork shows as the notification)

```
Daily cash brief — {date} (scheduled)
Written: briefs/{date}.md
True available ${x}. Staged for approval: {n} lines, ${total} → {confirmation_title}
{confirmation_url}
Nothing has moved until you approve this on the bank's page.
Needs you: {top 2 bullets} | Unavailable: {connectors or none}
```

**What the bank sees:** the calls arrive with `sessionType: scheduled`, and
the staged batch sits at the bank as agent-proposed, awaiting a human
approval. The server records the assertion; it does not verify the
scheduler — say so if asked.

## Degraded modes

| Missing | Effect |
|---|---|
| Paywhere | Stop — write a one-line brief saying the bank was unreachable. |
| quickbooks | Bank-only brief: balances, pending, recent credits and sweeps; AR, bills and reserve sections read "QuickBooks unavailable"; nothing is staged. |
| google calendar | No "Today / this week" overlay; say so. |
| gmail | Nothing changes — this skill drafts nothing by default. |

Never retry in a loop, never ask a question, never abort because one source
was down.

## Guardrails

- Never `transfer_funds`; never a money tool other than `make_batch_payment`.
- Never stage a HOLD bill, a not-yet-due bill, a bill without a saved payee,
  or a server-flagged duplicate; never invent payee details.
- Never claim a payment posted; verification is a separate owner ask
  ("I approved it" → `query_transactions {direction: "debit", dateFrom:
  today}` and match the lines).
- Never send email or create calendar events; drafts only, and none by
  default.
- Never write to QuickBooks; unbooked payments are narrated.
- Never subtract pending authorizations — the bank's balance already has.
- Not tax or accounting advice; the reserve math uses the business's own
  tax lines as booked.

## Reference

- [`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md) · [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md)
- [`../tax-reserve-check/SKILL.md`](../tax-reserve-check/SKILL.md) — the reserve window and shortfall method
- [`../pay-bills/SKILL.md`](../pay-bills/SKILL.md) — the interactive version of the bills batch
