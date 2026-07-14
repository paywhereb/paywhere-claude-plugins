---
name: pay-bills
version: 0.3.0
description: >
  Catches the business up on accounts payable in one pass: pulls the AP aging
  from QuickBooks, proposes the overdue bills for payment, checks the bank
  balance, resolves each vendor's payment rail (ACH or wire), validates the
  whole run with a dry-run batch, and — after ONE approval — executes a single
  mixed-rail batch payment through Paywhere, books a Bill Payment against
  every bill in QuickBooks, and verifies each debit actually posted at the
  bank. Use when the owner says "pay my bills," "what's overdue," "AP aging,"
  "catch up on payables," or "pay the vendors."
---

# Pay Bills

## Quick start

```
User: "pay my bills"
→ Pull AP: get_aged_payables + search_bills (open) → aging picture with
  overdue / due-this-week / due-later buckets and days-overdue per bill
→ Propose the default selection: every OVERDUE bill; show running total vs
  the live operating balance (list_accounts → get_account_balance)
→ Look up saved payee rails: list_saved_payees once, building a name → rail
  map so no vendor's rail is guessed
→ Resolve each vendor's rail: pay each open bill by the vendor's name
  (recipientId + amount — the bank resolves it to the saved payee; no raw bank
  details); for a vendor with no saved payee, confirm/onboard with the owner
→ Dry run: make_batch_payment with dryRun:true → per-item validation
→ THE GATE: one confirmation table, one explicit "yes, pay these"
→ Execute: ONE make_batch_payment across all rails
→ Book: create_bill_payment per bill, marker-first
→ Verify: query_transactions confirms each debit posted; re-pull the aging
  to show the overdue bucket cleared
```

One conversation, one approval, one batch — that is the whole product. The
"before" picture (owner logs into the bank, keys each payment by hand, then
marks bills paid in QuickBooks one at a time) is what this skill replaces.

## What is the source of truth

- **QuickBooks** is the system of record: the open bills say *what is owed to
  whom and when*, and every payment made here is booked back as a Bill
  Payment so the books never drift from the bank.
- **Paywhere** is the bank: the live balance says *what can be paid*, the
  rails (ACH / wire / stablecoin) move the money, and the transaction feed
  proves each payment actually posted.
- **Payment details** (ABA, account numbers, wire instructions) come from your
  **saved payees** when one exists — the pay tools take the vendor's **name**
  (`recipientId`) + amount and resolve the bank details, so this skill never
  handles raw account numbers. When no saved payee matches a vendor, the owner
  confirms the details (real-business onboarding flow). They are **never guessed**.

If QuickBooks is not connected, **stop** — without the system of record there
is no trustworthy list of what's owed and nowhere to book what gets paid. If
Paywhere is not connected, see "The 'before' contrast" below: the analysis
still runs; nothing executes.

## Workflow

### 1. Pull the AP picture

- `get_aged_payables` for the bucketed report, and `search_bills` for the
  open bills themselves (open = positive remaining `Balance`; a bill's
  `Balance`, not its original `TotalAmt`, is what's still owed — QBO nets
  partial payments and applied vendor credits into it).
- Build the aging picture per bill: vendor, DocNumber, bill date, due date,
  original amount, **open balance**, and days overdue (today − due date).
  Bucket into **overdue** (due before today), **due this week** (due within
  the next 7 days), and **due later** — with a total per bucket.
- Cross-check the report against the bill list; if they disagree (timing,
  unapplied credits), trust the bills and say so.
- Resolve "today" from the actual current date — never from a prior session.

### 2. Propose the selection

- **Default proposal: every overdue bill.** The owner can widen ("also pay
  what's due Friday") or narrow ("skip the CPA bill this week") — recompute
  and re-present after any change.
- `list_accounts` to find the operating account (the primary checking
  account by role — **never a hardcoded account number**), then
  `get_account_balance` on it. Show the **running selection total against the
  live balance** as the selection changes.
- Ask about near-term obligations ("anything big coming up — payroll,
  rent?"). If the batch would draw the balance below the obligations the
  owner names, **warn before the gate** and offer to narrow the selection or
  top up from savings (`transfer_funds`, separately gated).

### 3. Look up saved payee rails

- Call `list_saved_payees` **once**. It returns every saved payee's name
  and rail (ACH or WIRE), no bank details. Build a name → rail map before
  touching any payment tool.
- Match each selected bill's vendor name against the list (forgiving on
  minor variations); that match's rail is what the batch item for that
  vendor must use. **Never guess a vendor's rail or default to ACH.**
- No match (or a truly ambiguous match) → carry the vendor into the next
  step as rail-unresolved rather than guessing.

### 4. Resolve the payee per vendor

- **Pay by the vendor's name.** For each open bill, build the batch item on
  the rail resolved in step 3, passing the vendor's name as **`recipientId`
  + amount** — the bank resolves it to the matching saved payee and fills
  the ACH/wire details, so this skill never touches an ABA or account
  number.
- **No saved payee** (a real business that hasn't onboarded one): fall back to
  the normal onboarding flow — ask the owner to confirm the rail and details,
  read them back, then pass them **inline**. **NEVER guess or autocomplete an
  ABA, account number, or wire instruction.** A vendor with no saved payee and
  no confirmed details is **flagged and excluded** from the batch, listed so the
  owner can supply details and re-add it.
- **Wire** `processDate` is optional — when omitted it defaults to the next
  business day server-side; tell the owner when the wire will move. (There is
  no separate wire-config call.)
- If a batch item's rail turns out wrong anyway (a stale or ambiguous match
  from step 3), `make_ach_payment` / `make_wire_payment` / `make_batch_payment`
  now name the correct rail directly in the error (e.g. `"'Sutter Hill
  Properties' is a saved payee, but pays by WIRE, not ACH — retry with
  make_wire_payment (or a batch item with rail: 'wire')."`) — retry on the
  named rail; don't report the payee as unresolved.
- Before paying anything, check each selected bill for an **already-paid**
  signal: `search_bill_payments` against the bill, and `query_transactions`
  for a recent debit matching the vendor/amount. A hit means the bill may be
  paid at the bank but not booked — surface it, exclude it from the batch,
  and offer to book the missing Bill Payment instead (a QBO write, still
  gated). Never double-pay.

### 5. Dry run

One `make_batch_payment` with `dryRun: true` over the entire selection.
Every item should come back `validated_not_executed` (a stablecoin item, if
any, returns its real 1% fee — carry it into the confirmation table). An item
that fails validation is shown as flagged with its error; fix or exclude it
before the gate. Keep the item order — execution maps results back to bills
by `index`.

### 6. The gate — one approval for the whole batch

Present a single table and **wait for an explicit "yes, pay these"** (column
values come from live data, not these placeholders):

| Bill | Vendor | Days overdue | Amount | Rail | From account |
|---|---|---|---|---|---|
| _DocNumber_ | _vendor_ | 5 | $300.00 | ACH | Operating Checking |
| _DocNumber_ | _vendor_ | 9 | $560.00 | Wire | Operating Checking |

Below the table: the **batch total**, the **current balance**, and the
**projected post-batch balance** (balance − total − any fees), plus the
flagged/excluded list with reasons. Partial approval is fine — but **adding,
removing, or changing any row after approval restarts the gate** (and the dry
run, if amounts or details changed).

### 7. Execute — one batch

- **ONE `make_batch_payment`** call with the approved items exactly as
  dry-run (no `dryRun`). Items run sequentially; `stopOnError` defaults to
  false, so the batch continues past a failed item and reports per-item
  results. ACH items are made **and authorized** automatically — no separate
  `authorize_ach_payment` step.
- Map `results[].index` back to bills; capture each `paymentId` as the
  Paywhere reference for that bill.
- **`make_batch_payment` is NOT idempotent.** On partial failure, fix the
  cause and re-submit **only the failed items** in a new batch — never the
  whole list (the succeeded items would pay twice).

### 8. Write back to QuickBooks — marker-first

Money has moved; record it **immediately**, before anything else:

- For every succeeded item, `create_bill_payment` applied to its bill for the
  amount paid (the open balance), with `PrivateNote`:
  `Paid via Paywhere {rail} ref {paymentId} on {date}`.
- In the seeded demo world, open bills carry `PWD-BILL-` DocNumbers; mirror
  the id onto the Bill Payment (`PWD-BILL-0610` → `PWD-BPAY-0610`) **and lead
  the PrivateNote with it** — `PWD-BPAY-0610 — Paid via Paywhere {rail} ref
  {paymentId} on {date}` — so the seeder's `PrivateNote LIKE 'PWD-%'` fallback
  still finds these rows if the sandbox drops DocNumbers on bill payments. On
  real books the PrivateNote reference is the marker.
- **If a QBO write fails after the money moved, report the partial state
  loudly** — bill, rail, amount, `paymentId` — and retry the write. Do not
  declare the run finished while any executed payment is unbooked; if a
  retry won't stick, hand the owner the exact references so it can be booked
  manually, and say in plain terms that the books are behind the bank.

### 9. Verify settlement and show the after picture

- Per payment, `query_transactions` with `direction: "debit"`, `dateFrom` =
  today, and `descriptionContains` (payment name / vendor) or an exact amount
  match (`amountMin` = `amountMax` = amount) to confirm the debit posted at
  the bank. A still-`pending` ACH is normal, and a wire whose default
  `processDate` is the next business day won't post until then — report the
  status and offer to re-check rather than calling either missing.
- If a separate bank wire-fee debit appears, surface it; booking the fee is a
  one-line follow-up the owner approves separately.
- Report per bill: **paid ✓** (bank accepted, paymentId) / **posted ✓**
  (debit visible at the bank) / **booked ✓** (Bill Payment in QBO).
- Re-pull `get_aged_payables` and close with the before/after aging — the
  overdue bucket cleared (or exactly what remains and why), the new bank
  balance, and totals by rail.

## The "before" contrast — running without Paywhere

This is the demo's before/after moment, and the skill's honest degraded mode
on real books. **Without the Paywhere connector, steps 1–2 still run in
full**: the owner gets the complete AP aging analysis. Step 3 (the rail
lookup) has nothing to call without Paywhere, so every vendor is flagged
**"rail unconfirmed — ask the owner"** rather than resolved, and the
resulting **drafted payment list** — who would be paid, how much, on which
rail (where confirmed), with details resolved or flagged — reflects that, but
**nothing executes**. End that run by saying exactly what
connecting Paywhere would unlock: dry-run validation of the whole batch,
one-approval mixed-rail execution (ACH + wire in a single call), automatic
Bill Payment write-back, and settlement verification against the live bank
feed. The aging analysis is the same either way; the difference is whether
the overdue bucket is still there afterwards.

**Without QuickBooks: stop.** There is no system of record — no trustworthy
list of what's owed, and nowhere to book a payment. Paying from memory is how
books drift; this skill won't do it.

## Edge cases — spell these out, don't guess

- **Partially-paid bill**: pay the open `Balance`, never the original
  `TotalAmt`. Show both in the gate table so the smaller number is explained.
- **Vendor credits / credit memos**: QBO nets applied credits into the
  bill's `Balance` — paying the balance is already correct. If
  `get_vendor_balance` disagrees with the sum of the vendor's open bills,
  there is likely an **unapplied** credit: surface the difference and ask
  before paying.
- **Duplicate vendors with similar DisplayNames** ("DigitalOcean" vs
  "Digital Ocean Inc"): ask which is canonical before resolving details or
  booking anything. Never merge or pick silently.
- **Bill already paid at the bank but not booked**: caught by the step-4
  check (`search_bill_payments` + `query_transactions`). Surface it, exclude
  it, offer to book the missing Bill Payment — don't double-pay.
- **Insufficient balance mid-batch**: the affected items fail individually
  while the rest proceed. Offer `transfer_funds` from savings (its own
  approval gate), then re-submit **only** the failed items.
- **Missing/unconfirmed payment details**: flag and exclude; never fabricate
  ABA, account, or wire fields.
- **Wire timing**: `processDate` defaults to the next business day when
  omitted; tell the owner the wire settles then rather than silently shifting.

## Approval gates

- **Never move money without the explicit batch approval** (step 6). One
  approval covers exactly one batch; changing the set restarts the gate.
- **Never invent payment details** — missing or unconfirmed details mean the
  bill is flagged and excluded, not guessed at.
- `transfer_funds` top-ups and booking a previously unbooked payment are each
  approved separately — they are never smuggled into the batch approval.

## Reference

- [`/demo-setup`](../demo-setup/SKILL.md) — seeds the demo world (including the
  overdue + due-this-week open bills and their saved payees) this skill shines on.
- [../../DATASET.md](../../DATASET.md) — the demo dataset reference: the open-bill
  set, expected numbers, and the recipient/rail map (for understanding the demo;
  the skill reads it all from QuickBooks/Paywhere at run time).
