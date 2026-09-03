---
name: tax-sweep-agent
version: 1.0.2
description: >
  The Friday sales-tax sweep, automated (autonomous agent). Every Friday it
  totals the sales tax included in the payments RECEIVED this week (books
  payments cross-checked against bank credits, per-state tax line items
  pro-rated by the share paid), writes `sweeps/YYYY-MM-DD.md`, and STAGES
  one Operating → Tax Reserve transfer for the owner to approve on the
  bank's /confirm page with a passkey. Proposes, never executes; never
  `transfer_funds`. Use when the owner says "run the Friday tax sweep,"
  "sweep this week's sales tax," "tax sweep," "move this week's sales tax
  to the reserve," or schedules "every Friday at 4pm run the tax sweep."
---

# Tax Sweep (agent)

The owner's manual Friday rule — *"total the tax in the money that came in
this week and move exactly that to the Tax Reserve"* — run on a schedule.
Follows [`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md) and
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
> removes a section, not the run. No email, no invites.

*Not tax advice.* The sweep uses the business's own simplified sales-tax
rules as they appear on its invoices; the accountant owns the return.

## Schedule (Cowork Desktop → scheduled task)

| Field | Value |
|---|---|
| Schedule | `Every Friday at 4:00pm` |
| Prompt | `Run the Friday tax sweep` |

Cowork must be open for the run to fire. To see a run on demand, use the
same prompt interactively.

## Why "received", not "invoiced"

Tax is owed on what was billed, but the *cash* for it only exists once the
customer pays. Sweeping on invoiced amounts moves money the business has not
received yet and starves Operating (the one week the owner did that is
visible in the bank history). Sweeping on received amounts keeps the reserve
exactly funded for the cash in hand; the gap to the 20th remittance is the
unpaid invoices' tax, which `tax-reserve-check` reports separately.

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Dedupe and stamp"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

### 1. Dedupe and stamp

Resolve today from the actual date. The week is **Monday through today**
(normally Friday; on any other weekday, Monday through today, and say so).
If `sweeps/YYYY-MM-DD.md` exists → "Today's sweep exists at
sweeps/YYYY-MM-DD.md — skipping." and stop. Every Paywhere call carries
`sessionType: "scheduled"` and `taskId: "tax-sweep-agent"`.

### 2. Pull

- **Paywhere**: `list_accounts` (operating = primary checking; tax reserve =
  the savings account named for tax — by name/type/`isPrimary`, never by
  number, exact unmasked `accountNumber`); `get_account_balance` on both;
  `query_transactions {direction: "credit", dateFrom: <Monday>, dateTo:
  today, status: ["posted"]}` — customer money in (`ACH CR …`, `MOBILE CHECK
  DEPOSIT …`, `WIRE IN …`, merchant settlements `INTUIT PYMT SOLN DEPOSIT`);
  `query_transactions {descriptionContains: "TAX RESERVE", dateFrom: <today
  − 7 days>}` (has a sweep already posted this week?).
- **quickbooks** (read-only): `search_payments {dateFrom: <Monday>}` and the
  invoices they apply to (`search_invoices` by the applied refs), with the
  explicit sales-tax line items and the liability account/state each posts
  to; `search_deposits {dateFrom: <Monday>}` for grouping card/check
  payments into settlements.
- If Paywhere is unreachable: one-line file, stop. If quickbooks is
  unreachable: the sweep cannot be computed (the bank has no tax field) —
  write the file saying so, list the week's bank credits, stage nothing.

### 3. Compute the sweep amount

1. For each payment received this week, for each invoice it applies to:
   `tax portion = invoice tax lines total × (amount applied ÷ invoice total)`.
   Group by the liability account (e.g. per state). Sum → **this week's
   received tax**.
2. **Cross-check against the bank**: each payment (or the deposit that
   groups card/check payments, at net of merchant fee) should match a bank
   credit this week by amount (± fee) and counterparty in the descriptor.
   Payments with no bank credit are **not yet received** — list them and
   exclude their tax. Bank credits with no payment are **received but not
   booked** — list them; their tax cannot be computed from the books, so
   flag them under "needs you" rather than guessing.
3. If a `TRANSFER TO TAX RESERVE` credit already posted this week, subtract
   it (the owner swept manually) and say so.
4. **Prior shortfall** (missed Fridays, tax collected earlier and never
   swept): compute as in [`../tax-reserve-check`](../tax-reserve-check/SKILL.md)
   and REPORT it, but by default do **not** add it to the transfer — one line,
   this week's tax, is what the rule says. List the catch-up under "needs
   you" pointing at `tax-reserve-check`. (If the owner has configured "include
   the catch-up", add it as a second transfer line, clearly labelled.)

### 4. Stage — ONE `make_batch_payment`

```json
{ "payments": [ { "rail": "transfer",
                  "fromAccountNumber": "<Operating, unmasked>",
                  "toAccountNumber": "<Tax Reserve, unmasked>",
                  "amount": <this week's received tax> } ],
  "sessionType": "scheduled", "taskId": "tax-sweep-agent" }
```

Keep `confirmation_url`, `confirmation_title`, `expires_at`. If the amount
is $0 (nothing received, or already swept), stage nothing and say so. If
the response is `{ error }`, record it. Never `transfer_funds`.

### 5. Write `sweeps/YYYY-MM-DD.md`

```
# Friday tax sweep — {date} (scheduled 4:00pm) · week {Mon}–{Fri}

Sweep amount: ${total}  (KS ${k} · MO ${m})   ← tax inside payments RECEIVED this week
Tax Reserve before ${r} → after approval ${r+total}. Prior shortfall (missed Fridays): ${b} — not included; see tax-reserve-check.

## Payments counted
| Date | Customer | Invoice | Paid | Tax portion | State | Bank credit |
…
## Excluded
- Not yet received (booked payment, no bank credit): …
- Received, not booked (bank credit, no payment — tax unknown): …
- Already swept this week: ${x} on {date}

## Staged for approval — {confirmation_title}
{confirmation_url}
Nothing has moved until you approve this on the bank's page. Expires {expires_at}.

Not tax advice; per-state rules as they appear on the invoices.
```

### 6. Run output

```
Tax sweep — {date} (scheduled)
Written: sweeps/{date}.md
This week's received tax ${total} (KS ${k} / MO ${m}) → staged Operating → Tax Reserve · {confirmation_title}
{confirmation_url}
Nothing has moved until you approve this on the bank's page.
Needs you: prior shortfall ${b} (tax-reserve-check); {unbooked credits} | Unavailable: {none}
```

**What the bank sees:** a `scheduled` session and an internal transfer
waiting for a human approval.

## Guardrails

- One transfer line by default; never a vendor payment from this skill.
- Never `transfer_funds`; never claim the reserve is funded until the owner
  approves and the credit posts (`query_transactions` on the Tax Reserve).
- Never guess tax on an unbooked credit; list it.
- Never write to QuickBooks (the transfer entry is narrated, not posted).

## Reference

- [`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md) · [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md)
- [`../tax-reserve-check/SKILL.md`](../tax-reserve-check/SKILL.md) — the interactive check, the shortfall and the catch-up transfer
