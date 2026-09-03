---
name: daily-cash-brief
version: 1.0.4
description: >
  The scheduled morning cash brief (autonomous agent). Every weekday it reads
  the bank, the books and the calendar, writes `briefs/YYYY-MM-DD.md` (three
  balances, true available cash, today's and this week's dated obligations,
  exceptions: overdue customers with no bank credit, bills due within 7 days,
  bills to HOLD because the vendor is habitually paid early, tax-reserve
  shortfall and missed Friday sweeps, pending authorizations, unknown
  recurring debits, unreconciled merchant settlements), regenerates
  `dashboard/cash.html`, and STAGES one batch (reserve top-up transfer + due
  bills) for the owner to approve on the bank's /confirm page with a passkey.
  Proposes, never executes; drafts only; degrades gracefully. Use when the
  owner says "run my morning cash brief," "daily cash brief," "morning
  brief," or schedules "every weekday at 7:30 run my morning cash brief."
  NOT for "what's my cash" or "show my balances" asked in conversation —
  those get a direct answer, not a brief.
---

# Daily Cash Brief (agent)

The assistant's `business-pulse`, run unattended every weekday before the
owner opens the laptop, with two additions: it **writes files** and it
**stages the day's money movement** for one passkey approval. It follows
[`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md) and
[`../_shared/APPROVAL.md`](../_shared/APPROVAL.md). The load-bearing rules,
repeated because this file is loaded on its own:

> Stamp `sessionType: "scheduled"` and `taskId: "daily-cash-brief"` on every
> tool call. Write `briefs/YYYY-MM-DD.md`; if today's file already exists,
> stop and say so. **Propose, never execute**: the reserve top-up and the due
> bills are staged with ONE `make_batch_payment` (the transfer as a
> `{rail: "transfer", fromAccountNumber, toAccountNumber, amount}` item —
> never `transfer_funds`), and the returned `/confirm/<id>/<nonce>` URL is
> printed verbatim with its `confirmation_title` and the sentence *"Nothing
> has moved until you approve this on the bank's page."* Never say "paid" or
> "transferred". A missing connector removes a section, not the run. Drafts
> only — this skill creates none by default; it never sends mail or invites.

## Schedule (Cowork Desktop → scheduled task)

| Field | Value |
|---|---|
| Schedule | `Every weekday at 7:30am` |
| Prompt | `Run my morning cash brief` |
| Working folder | the owner's finance folder (where `briefs/` and `dashboard/` live) |

Cowork must be open for the run to fire. To see the output without waiting
for 7:30, run the same prompt interactively; the file, the dashboard and the
staged proposal are identical.

Interactive invocation ("run my morning cash brief" typed by the owner) is
fine: same output, `sessionType: "interactive"`, and you may show the batch
table and ask "stage these?" before staging.

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

### 2. Pull in parallel (same map as business-pulse)

- **Paywhere**: `list_accounts` (operating = primary checking; tax reserve =
  the savings account named for tax; savings = the other — by name/type/
  `isPrimary`, never by number); `get_account_balance` per account;
  `query_transactions {status: ["pending"]}`; `query_transactions
  {direction: "credit", dateFrom: <14 days ago>}` (credits to match against
  open AR); `query_transactions {direction: "debit", descriptionContains:
  "DEPT OF REVENUE", limit: 3}` (last remittance); `query_transactions
  {descriptionContains: "TAX RESERVE", dateFrom: <8 weeks ago>}` (sweeps);
  `query_transactions {direction: "debit", dateFrom: today}` (same-day
  duplicate check, used in step 5); `list_saved_payees` once.
- **quickbooks** (read-only): `get_aged_receivables`, `search_invoices`
  (open), `search_payments` for the months not yet remitted (the 20th pays
  the previous month: before the 20th, last month + this month; see
  tax-reserve-check's method), `get_aged_payables`,
  `search_bills` (open), `search_bill_payments` (12 months, for early-pay
  history), `search_deposits` (last 30 days, for settlement matching).
- **google calendar**: `list_events` today → +7 days.
- If Paywhere is unreachable: write a one-line brief saying so and stop.
  Any other missing connector: its section reads "unavailable".

### 3. Compute the brief

1. **Balances + true available** — the formula in
   [`../business-pulse/reference/true-available.md`](../business-pulse/reference/true-available.md):
   Operating − reserve shortfall (floor 0); the bank's balance is already net
   of pending authorizations, so list them but do not subtract them. Business
   Savings and the Tax Reserve are never spendable.
2. **Today / this week** — calendar events with amounts (payroll Friday, the
   20th remittance, estimates, appointments), plus bank-derived items the
   calendar may lack (next payroll estimate from the last two processor
   debits).
3. **Exceptions**, each with dollars and evidence:
   - Overdue invoices with **no matching bank credit** (amount ± $0.50 and
     counterparty in the descriptor), largest first. An invoice whose cash
     already landed is listed as "received, not yet booked" and excluded.
   - Bills due within 7 days (vendor, amount, due date, rail from saved
     payees).
   - **Held bills**: open bills not yet due whose vendor has a habit of being
     paid early (method in [`../ap-timing/SKILL.md`](../ap-timing/SKILL.md));
     recommend the due date, do not stage.
   - **Reserve**: collected-not-remitted vs Tax Reserve balance → shortfall,
     and the Fridays with no sweep credit (method in
     [`../tax-reserve-check/SKILL.md`](../tax-reserve-check/SKILL.md)).
   - Pending authorizations (descriptors + total).
   - Unknown recurring debit: a monthly-repeating descriptor with no matching
     vendor bill or purchase in the books (see `../subscription-audit`).
   - Unreconciled merchant settlements: count of bank
     `INTUIT PYMT SOLN DEPOSIT` rows (30 days) whose amount does not equal a
     QBO deposit's net — method in
     [`../month-end-prep/SKILL.md`](../month-end-prep/SKILL.md).

### 4. Decide what to stage (rule-based, no judgment calls)

Stage exactly these, nothing else:

- **Reserve top-up**: if shortfall > 0, one transfer line Operating → Tax
  Reserve for the shortfall (exact unmasked account numbers from
  `list_accounts`).
- **Bills due within 7 days** that are (a) not on the held list, (b) have a
  saved payee (rail from `list_saved_payees`; pay by `recipientId` = the
  payee's name; wire lines for wire payees), and (c) have no same-day
  duplicate: no debit today for the same amount and no already-staged line
  for the same payee + amount (the server also flags duplicates — honour the
  flag).

Everything else goes under **Needs you**: overdue-but-not-due bills for
vendors without a saved payee, held bills (with the recommended pay date),
anything the true-available balance could not cover (stage nothing that
would take true available below the next payroll estimate; list the
conflict instead), and the customers the owner would chase — **this skill
does not create Gmail drafts** unless the owner has told it to (then it
follows `../invoice-chase`, drafts only). Say that in the brief.

### 5. Stage — ONE `make_batch_payment`

Build the item list (transfer first, then ACH, then wire) and call
`make_batch_payment` once with `sessionType: "scheduled"` and `taskId:
"daily-cash-brief"`. Optionally `dryRun: true` first if any
payee match is uncertain. From the response keep `confirmation_url`,
`confirmation_title`, `total_amount`, `by_rail`, `lines[]`, `expires_at`.
If the response is `{ error }`, record it in the brief and move on. If there
is nothing to stage, say "Nothing to stage today."

### 6. Regenerate the dashboard

Rebuild `dashboard/cash.html` (same path, overwrite) with the embedded JSON
shape and layout defined in
[`../build-cash-dashboard/SKILL.md`](../build-cash-dashboard/SKILL.md), using
today's numbers, and stamp the "generated at" line with the run time. If the
dashboard has never been built, build it now; the owner can ask for it
interactively later.

### 7. Write `briefs/YYYY-MM-DD.md`

```
# Cash brief — {date} (scheduled 7:30)

**True available: ${x}** = Operating ${a} − reserve shortfall ${b}   (pending ${c} already netted by the bank)
Operating ${a} · Tax Reserve ${r} (owes ${t}, short ${b}) · Business Savings ${s} (not counted)

## Today / this week
- {date} payroll ≈ ${p} → headroom after ${x−p}
- {date} sales-tax remittance ${z} (KS ${k} / MO ${m})
- {other calendar items}

## Exceptions
- Overdue, no credit yet: {customer} ${amt}, {n} days late ({pattern}) …
- Received but not booked: {customer} ${amt} ({descriptor}, {date})
- Due within 7 days: {vendor} ${amt} {rail} due {date} …
- HOLD (habitually early): {vendor} ${amt} due in {n} days — pay on {date}
- Reserve: short ${b}; Fridays missed: {dates}
- Pending authorizations: {n} items, ${c}
- Unknown recurring debit: {descriptor} ${amt}, seen {n} months
- Unreconciled settlements: {n}

## Staged for approval — {confirmation_title}
{confirmation_url}
Nothing has moved until you approve this on the bank's page. Expires {expires_at}.
| Line | Payee / transfer | Amount | Rail |
…

## Needs you
- …

## Dashboard
Regenerated dashboard/cash.html at {time}.

Sources: Paywhere ✓ · quickbooks ✓/✗ · calendar ✓/✗ · gmail ✓/✗
```

### 8. Run output (what Cowork shows as the notification)

```
Daily cash brief — {date} (scheduled)
Written: briefs/{date}.md · dashboard/cash.html regenerated
True available ${x}. Staged for approval: {n} lines, ${total} → {confirmation_title}
{confirmation_url}
Nothing has moved until you approve this on the bank's page.
Needs you: {top 2 bullets} | Unavailable: {connectors or none}
```

**What the bank sees:** the calls arrive with `sessionType: scheduled`, and
the staged batch sits at the bank as agent-proposed, awaiting a human
approval. The server records the assertion; it does not verify the
scheduler — say so if asked.

## Guardrails

- Never `transfer_funds`; never a money tool other than `make_batch_payment`.
- Never stage a held bill, a bill without a saved payee, or a same-day
  duplicate; never invent payee details.
- Never claim a payment posted; verification is a separate owner ask
  ("I approved it" → `query_transactions` for today's debits).
- Never send email or create calendar events; drafts only, and none by
  default.
- Never write to QuickBooks; the missing-fee-line and unbooked-payment fixes
  are narrated.
- Not tax or accounting advice; the reserve math uses the business's own
  simplified rules.

## Reference

- [`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md) · [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md)
- [`../business-pulse/SKILL.md`](../business-pulse/SKILL.md) — the interactive twin
- [`../build-cash-dashboard/SKILL.md`](../build-cash-dashboard/SKILL.md) — the dashboard this run regenerates
- [`../tax-reserve-check/SKILL.md`](../tax-reserve-check/SKILL.md) · [`../ap-timing/SKILL.md`](../ap-timing/SKILL.md) · [`../month-end-prep/SKILL.md`](../month-end-prep/SKILL.md)
