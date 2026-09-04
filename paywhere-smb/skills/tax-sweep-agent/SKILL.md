---
name: tax-sweep-agent
version: 1.0.3
description: >
  The weekly sales-tax sweep, automated (scheduled agent). On the owner's
  sweep day it totals the sales tax inside the payments RECEIVED this week
  (one QuickBooks cash-basis report, cross-checked against the bank's
  credits), writes sweeps/YYYY-MM-DD.md, and STAGES one Operating to Tax
  Reserve transfer for the owner to approve on the bank's /confirm page with
  a passkey. Five calls: four reads in one turn, one staged transfer.
  Proposes, never executes; never transfer_funds. Use when the owner says
  "run the tax sweep," "sweep this week's sales tax," "tax sweep," "move this
  week's sales tax to the reserve," or schedules "every Friday at 4pm run the
  tax sweep" (any weekday the owner picks).
---

# Tax Sweep (agent)

The owner's weekly rule — *"total the tax in the money that came in this week
and move exactly that to the Tax Reserve"* — run on a schedule. Follows
[`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md) and
[`../_shared/APPROVAL.md`](../_shared/APPROVAL.md). The load-bearing rules,
repeated because this file is loaded on its own:

> Stamp `sessionType: "scheduled"` and `taskId: "tax-sweep-agent"` on every
> tool call. Write `sweeps/YYYY-MM-DD.md`; if today's exists, stop and say
> so. **Propose, never execute**: the transfer is staged as ONE
> `make_batch_payment` with a single `{rail: "transfer", fromAccountNumber,
> toAccountNumber, amount}` item — never `transfer_funds` — and the returned
> `/confirm/<id>/<nonce>` URL is printed verbatim with its
> `confirmation_title` and *"Nothing has moved until you approve this on the
> bank's page."* Never say "swept" or "transferred". A missing connector
> removes a section, not the run. No email, no invites, no questions.

*Not tax advice.* The sweep uses the business's own sales-tax items as they
appear on its invoices; the accountant owns the return.

## Schedule (Cowork Desktop → scheduled task)

| Field | Value |
|---|---|
| Schedule | `Every <sweep day> at 4:00pm` — the weekday the owner sweeps; the run day *is* the sweep day |
| Prompt | `Run the tax sweep` |

Cowork must be open for the run to fire. To see a run on demand, use the
same prompt interactively. The week is always **Monday through the run day**.

## Why "received", not "invoiced"

Tax is owed on what was billed, but the *cash* for it only exists once the
customer pays. Sweeping on invoiced amounts moves money the business has not
received yet and starves Operating. Sweeping on received amounts keeps the
reserve exactly funded for the cash in hand; the gap to the next remittance
is the unpaid invoices' tax, which [`../tax-reserve-check`](../tax-reserve-check/SKILL.md)
reports separately.

## Quick start — five calls

```
Schedule fires (or: "run the tax sweep")
→ sweeps/<today>.md exists? → one line, stop.
→ In ONE turn, in parallel (all four reads at once):
    list_accounts                                                                            (Operating + Tax Reserve, exact unmasked numbers, balances)
    get_sales_tax_collected {date_from:<Monday>, date_to:<today>}                            (tax inside payments RECEIVED this week: total, byItem, byPayment)
    query_transactions {accountNumbers:[<Operating>], direction:"credit", dateFrom:<Monday>, dateTo:<today>, status:["posted"]}   (bank cross-check)
    query_transactions {accountNumbers:[<Tax Reserve>], direction:"credit", dateFrom:<7 days ago>}                              (already swept this week? same-day duplicate?)
→ amount = collected.total − tax on booked payments with no bank credit − transfers already into the reserve this week
→ ONE make_batch_payment {payments:[{rail:"transfer", fromAccountNumber:<Operating>, toAccountNumber:<Tax Reserve>, amount}], sessionType:"scheduled", taskId:"tax-sweep-agent"}
→ Write sweeps/<today>.md · print the run output with the URL
```

Never rebuild the tax figure from `search_payments` and `read_invoice`; the
report is the books side in one call. If `list_accounts` lacks balances,
`get_account_balance` on both accounts joins the same turn.

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Dedupe and stamp"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

### 1. Dedupe and stamp

Resolve today from the actual date; the week is Monday through today (on a
day other than the scheduled one, still Monday through today, and say so).
If `sweeps/YYYY-MM-DD.md` exists → "Today's sweep exists at
sweeps/YYYY-MM-DD.md — skipping." and stop. Every Paywhere call carries
`sessionType: "scheduled"` and `taskId: "tax-sweep-agent"`.

### 2. Pull — four reads, one turn

Issue the four reads in the Quick start together. Accounts by role, never by
number: Operating = the primary checking; Tax Reserve = the savings account
named for tax or reserve. If Paywhere is unreachable: one-line file, stop.
If QuickBooks is unreachable: the sweep cannot be computed (the bank has no
tax field) — write the file saying so, list the week's bank credits, stage
nothing.

### 3. Compute the sweep amount

1. **This week's received tax** = `collected.total`, with `collected.byItem`
   for the split per tax item.
2. **Bank cross-check.** Match each `byPayment[]` row (`txnDate`, `total`,
   `customer`) to a bank credit this week by amount and counterparty; card
   payments settle net of fee and grouped, so match a merchant settlement to
   the sum of that day's card payments ± fee. A booked payment with **no**
   bank credit is not yet received — subtract its `taxCollected` and list it.
   A bank credit with **no** payment is received but not booked — its tax
   cannot be computed from the books; list it under "needs you", never guess.
3. **Already swept.** A transfer credit into the reserve this week (the
   owner moved it by hand, or a run already staged and it was approved) is
   subtracted and named. This is also the same-day duplicate check
   AUTONOMY.md requires: a credit today of the same amount → "already
   staged/posted", stage nothing.
4. **Prior shortfall** (tax collected in earlier weeks and never swept) is
   not this skill's line. One sentence under "needs you" pointing at
   `tax-reserve-check`; do not compute it here and do not add it to the
   transfer.

### 4. Stage — ONE `make_batch_payment`

```json
{ "payments": [ { "rail": "transfer",
                  "fromAccountNumber": "<Operating, unmasked>",
                  "toAccountNumber":   "<Tax Reserve, unmasked>",
                  "amount": <this week's received tax> } ],
  "sessionType": "scheduled", "taskId": "tax-sweep-agent" }
```

Keep `confirmation_url`, `confirmation_title`, `expires_at`. If the amount
is $0 (nothing received, or already swept), stage nothing and say so. If
the response is `{ error }`, record it in the file. Never `transfer_funds`.

### 5. Write `sweeps/YYYY-MM-DD.md`

```
# Sales-tax sweep — {date} (scheduled) · week {Mon}–{today}

Sweep amount: ${total}  ({item A} ${a} · {item B} ${b})   ← tax inside payments RECEIVED this week
Tax Reserve before ${r} → after approval ${r+total}. Prior shortfall, if any: see tax-reserve-check (not included).

## Payments counted
| Date | Customer | Invoice(s) | Paid | Tax portion | Bank credit |
…
## Excluded
- Not yet received (booked payment, no bank credit): …
- Received, not booked (bank credit, no payment — tax unknown): …
- Already into the reserve this week: ${x} on {date}

## Staged for approval — {confirmation_title}
{confirmation_url}
Nothing has moved until you approve this on the bank's page. Expires {expires_at}.

Not tax advice; tax items as they appear on the invoices.
```

### 6. Run output

```
Tax sweep — {date} (scheduled)
Written: sweeps/{date}.md
This week's received tax ${total} ({item A} ${a} / {item B} ${b}) → staged Operating → Tax Reserve · {confirmation_title}
{confirmation_url}
Nothing has moved until you approve this on the bank's page.
Needs you: {unbooked credits}; prior shortfall → tax-reserve-check | Unavailable: {none}
```

**What the bank sees:** a `scheduled` session and an internal transfer
waiting for a human approval.

## Guardrails

- One transfer line; never a vendor payment from this skill.
- Never `transfer_funds`; never claim the reserve is funded until the owner
  approves and the credit posts (`query_transactions` on the Tax Reserve).
- Never guess tax on an unbooked credit; list it.
- Never write to QuickBooks (the transfer entry is narrated, not posted).
- Never ask a question unattended; degrade and list under "needs you".

## Reference

- [`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md) · [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md)
- [`../tax-reserve-check/SKILL.md`](../tax-reserve-check/SKILL.md) — the interactive check, the shortfall and the catch-up transfer
