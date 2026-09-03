---
name: pay-bills
version: 1.0.4
description: >
  Stages this week's vendor payments as ONE mixed-rail batch for the owner to
  approve on the bank's page: pulls open bills from QuickBooks, selects what is
  overdue or due within 7 days, HOLDS bills that are not yet due from vendors
  the owner habitually pays early (pay-when-due), resolves each vendor's rail
  from the saved payees, pays by name, stages ACH and wire lines (and any
  savings top-up as a transfer line) in a single make_batch_payment, and
  prints the /confirm URL as the approval step. Money moves only after the
  owner approves with a passkey; the QuickBooks Bill Payment booking is
  narrated (the QuickBooks connector is read-only). Use when the owner says "pay the bills due
  this week," "pay my bills," "pay what's due," "pay Johnstone and Voltage"
  (any named vendors), "stage the vendor payments," or "catch up on payables."
---

# Pay Bills

One conversation, one batch, one approval — on the bank's surface.

> `make_ach_payment`, `make_wire_payment` and `make_batch_payment` **never
> move money**: they stage lines on the owner's open proposal and return a
> confirmation URL of the form `https://<bank host>/confirm/<id>/<nonce>`.
> **Print that URL verbatim as the approval step**; the owner opens it and
> approves with a passkey, and only then does money move. **Never claim money
> has moved** — say "staged" / "awaiting your approval". Internal transfers
> are staged the same way as a `{rail: "transfer", fromAccountNumber,
> toAccountNumber, amount}` item, **never `transfer_funds`**. Full path:
> [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md).

## Quick start

```
User: "pay the bills due this week"
→ search_bills (open) + get_aged_payables → overdue / due ≤ 7 days / not yet due
→ Early-pay history (ap-timing method) → HOLD not-yet-due bills from habitually-early vendors
→ list_accounts + get_account_balance → operating balance, true available
→ list_saved_payees once → name → rail map (ACH / WIRE)
→ Duplicate check: query_transactions debits for each vendor+amount (today/this week)
→ ONE make_batch_payment (ACH + wire lines, by payee name) → confirmation_url
→ Show the table (pay / held / excluded) AND the URL + confirmation_title in
  the same reply. Two steps for the owner in total: read the table, approve
  on the bank's page. No "stage these?", no dry run.
→ Narrate the QuickBooks Bill Payments that would follow approval
```

## Sources of truth

- **QuickBooks** says what is owed, to whom, when (open `Balance`, not
  `TotalAmt`). It is **read-only** here; the Bill Payment booking is narrated.
- **Paywhere** says what can be paid (live balance), holds the saved payees
  (rail and bank details, resolved by **name**), stages the proposal and,
  after approval, shows the debits.
- **Saved payees** carry the ABA / account / wire instructions. This skill
  never types one. No saved payee → the owner confirms details, or the bill
  is excluded and listed.

Without QuickBooks: **stop** (no system of record). Without Paywhere: the
analysis runs and a drafted payment list is shown; nothing is staged.

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Pull open bills"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

### 1. Pull open bills

`search_bills` (open) and `get_aged_payables`. Resolve "today" from the actual
date. Per bill: vendor, DocNumber, due date, open balance, days overdue /
until due. Bucket **overdue**, **due within 7 days**, **not yet due**. Trust
the bill list over the report if they disagree, and say so. If the owner
named vendors ("pay X and Y"), select those vendors' open bills and still run
the hold check.

### 2. Apply pay-when-due

Run the early-payment check from
[`../ap-timing/reference/early-payment-method.md`](../ap-timing/reference/early-payment-method.md)
(12 months of `search_bills` vs `search_bill_payments` — the whole year for
every vendor with an open bill, not the last two or three payments: the habit
is seasonal, paid early in the slow months when cash was flush and on the due
date in summer, so a recent sample says "no pattern" when the year says
otherwise). A **not-yet-due**
bill from a vendor habitually paid early is **HELD**: shown in the table as
"held — due {date}, {n} days; usually paid {m} days early", not staged. The
owner can override ("pay it anyway") — re-present. Overdue and due-within-7
bills are the default selection. _E.g. an equipment supplier's invoice not
due for 18 days stays held; a parts supplier's statement due Friday and a
crane subcontractor paid on receipt go in the batch._

### 3. Balance and true available

`list_accounts` → the operating account by role (primary checking; never a
hardcoded number) → `get_account_balance`. Compute true available as in
[`../business-pulse/reference/true-available.md`](../business-pulse/reference/true-available.md)
(operating − tax-reserve shortfall − pending). Show the batch total against
it. If the batch would leave less than the next payroll (bank pattern of the
processor's debits) plus a week of typical outflow, **warn** and offer:
narrow the selection, or add a savings → operating top-up **as a `transfer`
line in the same batch** (from Business Savings, never the Tax Reserve). The
top-up waits for the same passkey.

### 4. Rails and payees

`list_saved_payees` **once** → name → rail map. Match each selected vendor
(forgiving on suffix/case). The matched rail is the batch item's rail —
**never guess or default to ACH**. Pay by name: `recipientId` = the payee's
name, plus amount. No saved payee → ask the owner to confirm the rail and
details (never autocomplete an ABA or account number); unconfirmed →
**excluded and listed**. If a tool error names the correct rail (`"… pays by
WIRE, not ACH"`), retry on that rail. Wire `processDate` defaults to the next
business day; say so.

### 5. Duplicate check

For each selected bill, `query_transactions {direction: "debit",
descriptionContains: "<vendor stem>", dateFrom: <7 days ago>}` and an exact
amount match. A hit (a prior rehearsal run that was approved, or a payment
made outside this flow) is shown as **possible duplicate** with the debit's
date and amount; it is not staged without the owner's explicit yes. The
server also flags lines that look like a recent payment — surface that flag
the same way.

### 6. The table — "stage these?"

| Bill | Vendor | Due | Days | Amount | Rail | From |
|---|---|---|---|---|---|---|
| _DocNumber_ | _parts supplier_ | {date} | due in 3 | $6,850.00 | ACH | Operating Checking |
| _DocNumber_ | _electrical sub_ | {date} | overdue 2 | $2,150.00 | ACH | Operating Checking |
| _DocNumber_ | _crane sub_ | {date} | due in 5 | $1,900.00 | Wire | Operating Checking |
| _DocNumber_ | _equipment supplier_ | {date} | **held — due in 18** | $11,400.00 | — | usually paid 14 days early |

Below: batch total, operating balance, true available, projected balance
after approval, held list, excluded list with reasons. **Do not ask "stage
these?"** — stage the batch (step 7) in the same turn and present the table
together with the approval link. A staged proposal is inert: the owner's
review happens on the bank's page, where the passkey is the one approval, and
declining there costs nothing. The only questions this skill asks before
staging are the two it cannot answer itself: a **possible duplicate**
(step 5) and a payee with **no saved rail** (step 4). If the owner trims the
set after seeing it, stage a fresh batch; the old proposal expires unused.

### 7. Stage — ONE `make_batch_payment`

No dry run. One call with every line that survived steps 4–6 (`rail: "ach"` items with
`recipientId`, `paymentAmount`, `paymentName` = "Bill {DocNumber} {vendor}";
`rail: "wire"` items with `recipientId`, `amount`, `purposeOfWire`; any
top-up as `rail: "transfer"` with exact unmasked account numbers from
`list_accounts`). In a scheduled run, stamp `sessionType` / `taskId` per
[`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md).

Read back `confirmation_url`, `confirmation_title`, `total_amount`,
`by_rail`, `lines[]`, `expires_at`. A rejected batch comes back as
`{ error, invalid_items[] }` naming the line and the reason (a payee name that
did not resolve, a missing field): fix that line and re-submit the whole
batch once — that is what a dry run would have told you, without the extra
round trip. An `{ error }` for an expired or sealed proposal is reported in
one line and the batch re-staged fresh. Never invent a URL.

### 8. Print the approval step

```
Staged for approval: {line_count} lines, ${total_amount} ({by_rail})
{confirmation_title}
{confirmation_url}
Nothing has moved. Open the link and approve with your passkey; the bank
executes the batch after that. Held: {vendor} ${amt} until {date}.
```

Render the title as the link text over the URL and also print the URL in
plain text. Do **not** say paid, sent, executed or transferred.

### 9. Narrate the booking (what follows approval)

One paragraph, per run not per bill: once approved and executed, each
payment would be booked to QuickBooks as a **Bill Payment** against its bill
(with a note carrying the Paywhere payment reference), and the bills would
show paid. The QuickBooks connector is read-only, so this is narrated; with
write access it is a one-approval write-back. Until it is booked, the aging
will keep showing these bills open — that is the missing write-back, not a
failed payment.

### 10. After the owner approves — verify on request

When the owner says "I approved it" (or on a later "did those go out?"),
`query_transactions {direction: "debit", dateFrom: <approval date>}` per
line (vendor stem, exact amount). Report what posted, what is still pending
(ACH 1–3 business days; a wire whose `processDate` is the next business
day), and any wire-fee debit. Never report this step before the owner has
approved.

## Without Paywhere (short)

Steps 1–2 run in full: the owner gets the aging and the pay/hold table with
every rail marked "unconfirmed". Nothing is staged. Say what connecting the
bank unlocks: saved-payee rails, one mixed-rail proposal, passkey approval
on the bank's page, settlement verification.

## Edge cases

- **Partially paid bill**: stage the open `Balance`; show both numbers.
- **Unapplied vendor credit** (`get_vendor_balance` ≠ sum of open bills):
  surface the difference; ask before staging.
- **Similar vendor names**: ask which is canonical; never merge silently.
- **Insufficient balance**: the server validates per line; a failed line is
  reported, the rest stage. Offer the savings top-up as a transfer line and
  re-stage only the failed lines.
- **Expired proposal** (`expires_at` passed, `{ error }` on the next call):
  re-stage on a fresh call; the old URL is dead.
- **Scheduled run** (no owner present): skip the "stage these?" question,
  stage only overdue + due-within-7 non-held bills, print the URL in the run
  output, dedupe on the day's output file — see
  [`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md).

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
- [`../ap-timing/SKILL.md`](../ap-timing/SKILL.md) — the pay-when-due analysis this skill applies
