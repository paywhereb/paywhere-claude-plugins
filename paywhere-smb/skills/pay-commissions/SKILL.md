---
name: pay-commissions
version: 0.2.0
description: >
  Pays sales commissions on payments your business actually received, across
  all three Paywhere rails (ACH, Wire, Stablecoin). Reads the local
  commission register (commission-register.xlsx — who gets paid, at what
  rate, by which rail) as the source of truth, matches Paywhere bank credits
  to QuickBooks customer payments, computes each commission, dedupes against
  already-paid runs, and — only after you approve — disburses the whole
  batch in a single make_batch_payment call and books each expense as a Bill
  + Bill Payment in QuickBooks. Use when the owner says "pay commissions,"
  "run commissions for last week," "pay my reps," or asks who is owed
  commission.
---

# Pay Commissions

## Quick start

```
User: "pay commissions for last week"
→ Open commission-register.xlsx (Customers + ACH/Wire/Stablecoin + PaidLog sheets) from the session working folder
→ query_transactions for the range's posted credits; match each to a QuickBooks customer payment
→ Join paying customers to the register → rate, payee, rail
→ Dedupe: skip anything already booked (QBO COMM- marker Bill or PaidLog row)
→ Assemble ONE make_batch_payment call for all candidates; dry-run it to surface the stablecoin fee
→ Show a table: customer, payment, gross, rate, commission, payee, rail, status
→ WAIT for explicit approval — nothing moves money before this
→ Run the batch live, book a marker Bill + Bill Payment per commission, append PaidLog rows
```

Money moves on three rails in one batch call and is recorded in two systems. Get the data model right before running — read [DATA-MODEL.md](DATA-MODEL.md).

## What is the source of truth

- **The commission register** — a local Excel workbook, `commission-register.xlsx`, in the session working folder — decides *who* gets commission, at *what rate*, to *which payee*, on *which rail*, with the *payment details* for that rail. A customer not listed in the register's `Customers` sheet earns no commission — skip them.
- **QuickBooks** is the system of record for the *payments received* (the unit we commission on) and for the *commission expense* (a Bill + Bill Payment per commission paid).
- **Paywhere** is the bank — it shows the credits that prove a customer actually paid, and it is the rail that disburses each commission.

Commission config is **never** stored as JSON in QBO notes, and **never** on the QBO vendor record. The register workbook is the only place who-gets-paid / rate / payment details live.

## Setup (first run only)

If `commission-register.xlsx` doesn't exist yet, don't improvise its contents — the register is the owner's source of truth. Either help the owner create one with the documented sheets and their **real** payees, rates, and payment details (build it with Bash + Python per [DATA-MODEL.md](DATA-MODEL.md)), or, to stand up the demo scaffold for evaluation, run [/demo-setup-commissions](../demo-setup-commissions/SKILL.md) (which builds an example register on the Meridian demo world, plus QBO payees, sample history, and a verified stablecoin recipient). Resume `pay-commissions` once the register exists.

## Workflow

### 1. Open the register

- Locate `commission-register.xlsx` in the session working folder by filename. If more than one matches, list them and ask which to use. If none, stop — see Setup above.
- Read all five sheets with Bash + Python (openpyxl or an equivalent xlsx library): `Customers`, `ACH`, `Wire`, `Stablecoin`, `PaidLog`. See [DATA-MODEL.md](DATA-MODEL.md) for the exact columns.
- Build in-memory lookups: `Customers` keyed by Customer DisplayName; each rail sheet keyed by `Payee`; `PaidLog` as a set of `QBOPaymentId` already paid.

### 2. Collect incoming payments (Paywhere)

- `list_accounts` to enumerate accounts. Determine the date range from the owner's phrase ("last week", "May") as concrete `dateFrom`/`dateTo` (YYYY-MM-DD), resolved from today's actual date.
- One `query_transactions` call: `{direction: "credit", dateFrom, dateTo, status: ["posted"], includeTransactions: true}` (defaults to all accounts). Credits are money in — these are the candidate payments we commission on. If the response says `truncated: true`, narrow the date range and re-query rather than commissioning on a partial scan.

### 3. Match credits to QuickBooks payments

- QuickBooks `search_payments` over the same range. Each QBO Payment carries the `CustomerRef` DisplayName — this is the join key to the register.
- Match each Paywhere credit to a QBO payment on **amount + date (±2 business days)**.
- List unmatched Paywhere credits and unmatched QBO payments separately for the owner — do not commission on either until matched. The **QBO Payment is the unit we commission on** (it carries the customer); a Paywhere credit with no QBO payment can't be attributed.

### 4. Look up the commission

For each matched QBO payment, join its customer DisplayName to the `Customers` sheet:
- Customer present → read `CommissionRate`, `Payee`, `Rail`.
- Customer absent → **skip** (no commission due). Note it in the skip list so the owner can confirm.
- `commission = round(amountReceived * CommissionRate, 2)`. On a **partial payment**, commission on the amount actually received (the QBO Payment amount), not the invoice total.

### 5. Dedupe — before paying

For each candidate, check **two independent signals**; either positive ⇒ skip and show "already paid":
1. **QBO**: `search_bills` for `DocNumber = COMM-{qboPaymentId}` (fallback: `PrivateNote LIKE` the payment id).
2. **Register**: `QBOPaymentId` already present in `PaidLog`.

This makes the run safe to re-run: a second pass reports everything "already paid".

### 6. Resolve payees and rail details

For each surviving candidate, read the rail sheet row keyed by `Payee`:
- **ACH** → `RecipientName`, `ABA`, `AccountNumber`, `AccountType`, `Email`.
- **Wire** → `RecipientName`, `RecipientAccount`, `RecipientAddr1`, `City`, `State`, `PostalCode`, `BankName`, `BankABA`.
- **Stablecoin** → `WalletAddress`, `Chain`, `Currency`. Additionally call `get_stablecoin_recipient` for the wallet and confirm it is **VERIFIED** — refuse the row otherwise (see Edge cases). The fee comes from the batch dry-run in step 7, not from a separate preview call.

If a payee's rail row is missing or malformed (blank ABA, no bank aba on a wire row, etc.), **flag it and exclude it — never guess** a payment detail.

Resolve the source account via `list_accounts` and pay from the operating account (confirm which one in the table if there is more than one).

### 7. Assemble the batch and dry-run it

Build **one** `make_batch_payment` `payments` array covering every surviving candidate (≤50 items, mixed rails in a single call — see exact shapes in [DATA-MODEL.md](DATA-MODEL.md)):
- **ACH** item → `{rail: "ach", fromAccountNumber, recipientIdType: "Inline", recipient: {name, aba, accountNumber, accountType, emailAddress} (from the ACH sheet), paymentAmount, paymentDate (today), paymentName: "Commission COMM-{qboPaymentId}"}`. Batch ACH items are made **and authorized** automatically — no separate `authorize_ach_payment`.
- **Wire** item → `{rail: "wire", fromAccountNumber, amount, processDate (today), recipient: {name, accountNumber, address1, city, state, postalCode}, recipientBank: {name, aba}, purposeOfWire: "Sales commission"}` — `recipientBank` takes **`aba`** (the Wire sheet's `BankABA`), not `routingNumber`. Call `get_wire_config` before assembling wire items.
- **Stablecoin** item → `{rail: "stablecoin", walletAddress, currency: "USD", accountNumber: <the funding account>, amount}`.

Call `make_batch_payment` with **`dryRun: true`** first: it validates every item without moving money and returns the **real 1% fee** for each stablecoin item (other rails report `validated_not_executed`). Fix any per-item validation errors (or move the item to the flagged list) before showing the confirmation table.

### 8. Confirm — the gate

Present a single table — fees from the dry-run, not estimates — and **wait for explicit owner approval**. Nothing moves money before this. Example layout (values come from live data, not these placeholders):

| Customer | QBO Payment | Gross | Rate | Commission | Payee | Rail | Status |
|---|---|---|---|---|---|---|---|
| _customer_ | _paymentId_ | $4,000 | 5% | $200.00 | _ACH payee_ | ACH | ready |
| _customer_ | _paymentId_ | $9,000 | 10% | $900.00 (+$9.00 fee) | _stablecoin payee_ | Stablecoin | ready (verified) |
| _customer_ | _paymentId_ | $2,500 | 5% | $125.00 | _wire payee_ | Wire | ready |

Also show: skipped (customer not in register), already-paid (with the prior reference), unmatched (both lists from step 3), and flagged (missing/unverified payee). Get a clear "yes, pay these" — partial approval is fine, but adding or changing a row after approval starts a new round **and a fresh dry-run**.

### 9. Execute — one live batch call

Re-submit the approved `payments` array (dropping any rows the owner excluded) with `dryRun` off; leave `stopOnError` at its default (false) so every item is attempted and reported. Then:
- Map `results[index]` back to commission rows **by index** — capture each item's `paymentId` as the Paywhere reference, and the actual `fee` on stablecoin items.
- **`make_batch_payment` is NOT idempotent.** On partial failure (`summary.failed > 0`), re-submit **only the failed items** in a new call — never the whole array, or every previously succeeded payment doubles.
- Optionally verify settlement with the per-rail status tools (`get_ach_payment_status`, `get_wire_payment_status`, `get_stablecoin_payment_status`) using the returned `paymentId`s.

### 10. Record — both systems

For every commission that disbursed, **write the marker first so dedupe is never lost**, even if a later step fails:
1. **QBO marker**: **`create-bill`** (note the hyphen) against the payee's vendor, then `create_bill_payment`, with:
   - `DocNumber`: `COMM-{qboPaymentId}`
   - `PrivateNote`: `Commission on QBO payment {qboPaymentId} for {customer} @ {rate} — Paywhere {rail} ref {paywherePaymentId}`
2. **Register**: append a row to the `PaidLog` sheet of the xlsx (load workbook → append → save, one operation; see the concurrency note in [DATA-MODEL.md](DATA-MODEL.md)) — `Date | Customer | QBOPaymentId | GrossAmount | Rate | Commission | Payee | Rail | PaywherePaymentId | QBOBillId`.

End with a summary listing each commission with both its **QBO** (Bill id) and **Paywhere** (payment id) references, plus totals by rail and total fees.

## Edge cases — spell these out, don't guess

- **Partial payment**: commission on the amount actually received (the QBO Payment amount), not the invoice total.
- **Multiple payments per customer in range**: each QBO Payment is its own commission line with its own `COMM-{id}` marker. Do not collapse them.
- **Payee / rail row missing or malformed**: flag and exclude; never fabricate ABA, bank aba, or wallet values.
- **Unverified stablecoin recipient** (`get_stablecoin_recipient` not VERIFIED): do not pay on that rail. Offer an ACH fallback only if the payee also has a valid ACH row; otherwise exclude the row and tell the owner how to fix it — register and verify the wallet with `create_stablecoin_recipient` / `get_stablecoin_recipient` (the demo scaffold does this via [/demo-setup-commissions](../demo-setup-commissions/SKILL.md)).
- **Batch partial failure**: per-item `ok` flags tell you exactly which rows paid. Record the successes immediately (step 10 — marker first), then re-submit **only** the failed items; the tool is not idempotent. An item that failed validation in the dry-run never makes it into the live call.
- **Paywhere succeeds but QBO Bill write fails**: the money already moved — append the `PaidLog` row immediately and retry the QBO marker; report the partial state explicitly so dedupe still catches it next run. Never treat the run as clean until the marker exists in at least one system (PaidLog).
- **Unmatched credits / payments**: surface both lists; never commission on a Paywhere credit that has no matching QBO payment, or vice versa.
- **Register missing or ambiguous**: stop and resolve it with the owner (see Setup) — never guess which file, and never invent register contents.

## Graceful degradation

- **Without Paywhere**: no credits to verify against and no rails to pay on. Fall back to a QBO-only *draft*: `search_payments` for the range, join to the register, dedupe via the `COMM-` markers and PaidLog, and present the would-pay table clearly labeled "drafted — unverified against the bank, nothing disbursed". No PaidLog rows are written (nothing happened).
- **Without QuickBooks**: credits can't be attributed to customers and dedupe loses its system-of-record signal — show the raw credit list and stop; do not pay.
- **Without the register file**: stop — see Setup. The register is the source of truth; there is no degraded mode that guesses rates or payment details.

## Approval gates

- **Never move money without explicit approval** of the confirmation table (Step 8).
- **Never pay a candidate that fails dedupe** (Step 5) — show it as already-paid instead.
- **Never invent payment details.** A missing or malformed register row is flagged and excluded, not guessed.
- **One approval covers one batch** — exactly one live `make_batch_payment` call. Changing the set after approval starts a new round (and a new dry-run).

## Reference

- [DATA-MODEL.md](DATA-MODEL.md) — register sheet schemas, the rail-sheet → Paywhere-API field mapping, dedupe markers, and the real MCP tool signatures (batch + single-payment fallbacks).
