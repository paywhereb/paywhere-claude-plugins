---
name: pay-bills
version: 1.0.6
description: >
  Pays this week's vendor bills as ONE mixed-rail batch the owner approves on
  the bank's page: pulls the OPEN bills from QuickBooks (never the year's
  history), selects what is overdue or due within 7 days, leaves everything
  not yet due for its due date, resolves each vendor's rail from the saved
  payees, dry-runs the batch, shows one table, and after the owner's yes
  stages the real batch and prints the /confirm URL. Money moves only after
  the owner approves with a passkey; the QuickBooks Bill Payment booking is
  narrated (the QuickBooks connector is read-only). Use when the owner says
  "pay the bills due this week," "pay my bills," "pay what's due," "pay Acme and
  Northside" (any named vendors), "stage the vendor payments," or
  "catch up on payables." NOT for "am I paying anyone early?" or vendor
  payment habits — that is ap-timing.
---

# Pay Bills

Open bills in, one batch out, one approval on the bank's surface.

> `make_ach_payment`, `make_wire_payment` and `make_batch_payment` **never
> move money**: they stage lines on the owner's open proposal and return a
> confirmation URL of the form `https://<bank host>/confirm/<id>/<nonce>`.
> **Print that URL verbatim as the approval step**; the owner opens it and
> approves with a passkey, and only then does money move. **Never claim money
> has moved** — say "staged" / "awaiting your approval". Internal transfers
> are staged the same way as a `{rail: "transfer", fromAccountNumber,
> toAccountNumber, amount}` item, **never `transfer_funds`**. Full path:
> [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md).

## Quick start — six calls, two owner turns

```
User: "pay the bills due this week"
→ In ONE turn, in parallel:
    search_bills {criteria:[{field:"Balance", operator:">", value:"0"}], fetchAll:true}   (open AP only)
    list_saved_payees                                                                    (name → rail)
    list_accounts                                                                        (Operating balance)
    query_transactions {direction:"debit", dateFrom:<7 days ago>}                        (duplicate check)
→ Select: overdue + due within 7 days. Not yet due → listed, not staged.
→ make_batch_payment {dryRun:true, payments:[…]}  → per-line validation, no card, no proposal
→ Reply: the table (pay / not yet due / excluded), totals, "Stage these?"
User: "yes"
→ ONE make_batch_payment (no dryRun) → confirmation_url  → the card and link render
→ One closing line: what is staged, nothing has moved, what QuickBooks would book.
```

Never pull the year's bills or bill payments here: a year does not fit in one
result, and the question is what is owed today. Payment habits ("am I paying
anyone early?") are [`../ap-timing`](../ap-timing/SKILL.md); if the owner
asks that in the same breath, answer the bills first and offer ap-timing.

## Sources of truth

- **QuickBooks** says what is owed, to whom, when (open `Balance`, not
  `TotalAmt`). It is **read-only** here; the Bill Payment booking is narrated.
- **Paywhere** says what can be paid (live balance), holds the saved payees
  (rail and bank details, resolved by **name**), validates and stages the
  proposal and, after approval, shows the debits.
- **Saved payees** carry the ABA / account / wire instructions. This skill
  never types one. No saved payee → the owner confirms details, or the bill
  is excluded and listed.

Without QuickBooks: **stop** (no system of record). Without Paywhere: the
selection table is shown with every rail "unconfirmed"; nothing is staged.

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name), `TaskUpdate` it to `in_progress`
when you begin that step and `completed` when it's done. This drives Cowork's
progress display and does not happen unless you do it explicitly.

### 1. Read everything at once

Issue the four reads in the Quick start in **one turn**: open bills
(`search_bills` with `Balance > 0`; skip `get_aged_payables`, the open bills
are the aging), saved payees, accounts, and the last 7 days of Operating
debits. If the owner named vendors ("pay X and Y"), still read all open bills
and select those vendors' bills.

### 2. Select

Resolve "today" from the actual date. Per open bill: vendor, DocNumber, due
date, open balance, days overdue / until due.

- **Overdue** and **due within 7 days** → the batch.
- **Not yet due** (8+ days out) → listed under "not yet due — pay on {date}",
  not staged. Paying a bill two weeks early is cash given away for nothing;
  say so in one clause when a large one is in the list. The owner can pull it
  in ("pay the equipment supplier now too") — re-present.

### 3. Rails, balance, duplicates

- Saved payees → name → rail map (forgiving on suffix/case). The matched rail
  is the line's rail — **never guess or default to ACH**. No saved payee → ask
  once for rail and details (never autocomplete an ABA or account number);
  unconfirmed → **excluded and listed**.
- Operating balance (primary checking, by role, never a hardcoded number).
  Show the batch total against it and the balance after approval. The Tax
  Reserve and Business Savings are never spendable here. If the batch would
  leave less than the next payroll (last processor debit in the same
  `query_transactions` result, or ask), **warn** and offer to narrow the
  selection or add a savings → operating `transfer` line to the same batch.
- Duplicates: a debit in the 7-day result matching a selected vendor's stem
  and exact amount is a **possible duplicate** — shown with its date, not
  staged without the owner's explicit yes on that row. The server also flags
  lines that look like a recent payment; surface that flag the same way.

### 4. Dry run

One `make_batch_payment` with `dryRun: true` over the whole selection
(`rail: "ach"` items with `recipientId` = payee name, `paymentAmount`,
`paymentName` = "Bill {DocNumber} {vendor}"; `rail: "wire"` items with
`recipientId`, `amount`, `purposeOfWire`; any top-up as `rail: "transfer"`
with exact unmasked account numbers). It returns per-line validation and
`status: "validated_not_proposed"` — no proposal, no card, no URL. A line
that fails is fixed (or excluded and listed) before the table is shown.

### 5. The table — "Stage these?"

| Bill | Vendor | Due | Days | Amount | Rail | From |
|---|---|---|---|---|---|---|
| _DocNumber_ | _parts supplier_ | {date} | due in 1 | $6,850.00 | ACH | Operating Checking |
| _DocNumber_ | _electrical sub_ | {date} | due in 1 | $2,150.00 | ACH | Operating Checking |
| _DocNumber_ | _crane sub_ | {date} | due in 1 | $1,900.00 | Wire | Operating Checking |
| _DocNumber_ | _equipment supplier_ | {date} | due in 3 | $3,860.00 | ACH | Operating Checking |

Below the table, in this order: batch total · Operating balance · balance
after approval · **not yet due** list (vendor, amount, due date) · excluded
list with reasons · possible duplicates. Then exactly: **"Stage these?"**
Keep the whole reply under about 25 lines; the table is the reply.

### 6. Stage — ONE real `make_batch_payment`

On the owner's yes: the same lines, no `dryRun`. Read back
`confirmation_url`, `confirmation_title`, `total_amount`, `by_rail`,
`lines[]`, `expires_at`. The bank's card and link render from the result, so
the reply after it is **one to three lines**:

```
Staged for approval: {line_count} lines, ${total_amount} ({by_rail}). Nothing has moved —
open the link and approve with your passkey. Once approved, each payment would be booked in
QuickBooks as a Bill Payment against its bill (the connector is read-only, so that is narrated).
```

Print the URL in plain text as well as the link. Do **not** say paid, sent,
executed or transferred. If the owner trims the set after the table, dry-run
and re-present; a proposal already staged expires unused. A rejected batch
comes back as `{ error, invalid_items[] }` naming the line — fix that line and
re-submit once. Never invent a URL.

### 7. After the owner approves — verify on request

When the owner says "I approved it" or later asks "did those go out?",
`query_transactions {direction: "debit", dateFrom: <approval date>}` once and
match the lines (vendor stem, exact amount). Report what posted, what is
pending (ACH 1–3 business days; a wire whose `processDate` is the next
business day), and any wire fee. Never report this before the owner approves.

## Scheduled runs

No owner present: skip the dry run and the question, stage overdue +
due-within-7 bills in one real batch, print the URL in the run output, dedupe
on the day's output file — see [`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md).

## Edge cases

- **Partially paid bill**: stage the open `Balance`; show both numbers.
- **Similar vendor names**: ask which is canonical; never merge silently.
- **Insufficient balance**: the server validates per line; a failed line is
  reported, the rest stage. Offer the savings top-up as a transfer line.
- **Expired proposal** (`expires_at` passed, `{ error }` on the next call):
  re-stage on a fresh call; the old URL is dead.

## Approval gates

- **Money moves only on the bank's `/confirm` page with a passkey.** This
  skill stages; it never executes and never says it did.
- **Never invent payment details.** Unconfirmed → excluded and listed.
- **Never stage a possible duplicate** without the owner's explicit yes on
  that row.
- **Never `transfer_funds`.** Top-ups are `transfer` lines in the batch.
- **Never raid the Tax Reserve** for a top-up.

## Reference

- [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md) — the approval path in full
- [`../ap-timing/SKILL.md`](../ap-timing/SKILL.md) — vendor payment habits, when the owner asks
