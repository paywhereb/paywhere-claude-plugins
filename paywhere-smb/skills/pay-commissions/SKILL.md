---
name: pay-commissions
version: 0.3.0
description: >
  Pays sales commissions on payments your business actually received, across
  all three Paywhere rails (ACH, Wire, Stablecoin). Uses the business's
  commission map (client → rate → payee → rail), matches Paywhere bank credits
  to QuickBooks customer payments, computes each commission, dedupes against
  already-paid runs via the QBO COMM- marker, and — only after you approve —
  disburses the whole batch in a single make_batch_payment call and books each
  expense as a Bill + Bill Payment in QuickBooks. Use when the owner says "pay
  commissions," "run commissions for last week," "pay my reps," or asks who is
  owed commission.
---

# Pay Commissions

## Quick start

```
User: "pay commissions for last week"
→ query_transactions for the range's posted credits; match each to a QuickBooks customer payment
→ Join each paying customer to the commission map → rate, payee, rail
→ Dedupe: skip anything already booked (QBO COMM- marker Bill)
→ Assemble ONE make_batch_payment call for all candidates; dry-run it to surface the stablecoin fee
→ Show a table: customer, payment, gross, rate, commission, payee, rail, status
→ WAIT for explicit approval — nothing moves money before this
→ Run the batch live, book a marker Bill + Bill Payment per commission
```

Money moves on three rails in one batch call and is recorded in QuickBooks. Get the data model right before running — read [DATA-MODEL.md](DATA-MODEL.md).

## What is the source of truth

- **The commission map** — the business's policy of *who* gets commission, at *what rate*, to *which payee*, on *which rail*. It is server-known (configured at setup, not entered per run) and surfaced alongside the seeded QBO customer payments; for the demo world it is documented in [../../DATASET.md](../../DATASET.md). A customer not in the map earns no commission — skip them.
- **QuickBooks** is the system of record for the *payments received* (the unit we commission on) and for the *commission expense* (a Bill + Bill Payment per commission paid).
- **Paywhere** is the bank — it shows the credits that prove a customer actually paid, and it is the rail that disburses each commission. A pay step passes the payee's **name** (`recipientId`) + amount, and the bank resolves it to the saved payee.

## Setup (first run only)

This skill reads the business's existing commission map and QBO payments — it does not stand up its own data. If no commission map is configured, help the owner define it (client → rate → payee → rail, plus saved ACH/Wire payees and a verified stablecoin recipient). For the demo world this is all seeded by `/demo-setup` — the commission map and payees are documented in [../../DATASET.md](../../DATASET.md). Resume `pay-commissions` once the map exists.

## Workflow

### 1. Collect incoming payments (Paywhere)

- `list_accounts` to enumerate accounts. Determine the date range from the owner's phrase ("last week", "May") as concrete `dateFrom`/`dateTo` (YYYY-MM-DD), resolved from today's actual date.
- One `query_transactions` call: `{direction: "credit", dateFrom, dateTo, status: ["posted"], includeTransactions: true}` (defaults to all accounts). Credits are money in — these are the candidate payments we commission on. If the response says `truncated: true`, narrow the date range and re-query rather than commissioning on a partial scan.

### 2. Match credits to QuickBooks payments

- QuickBooks `search_payments` over the same range. Each QBO Payment carries the `CustomerRef` DisplayName — this is the join key to the commission map.
- Match each Paywhere credit to a QBO payment on **amount + date (±2 business days)**.
- List unmatched Paywhere credits and unmatched QBO payments separately for the owner — do not commission on either until matched. The **QBO Payment is the unit we commission on** (it carries the customer); a Paywhere credit with no QBO payment can't be attributed.

### 3. Look up the commission

For each matched QBO payment, join its customer DisplayName to the commission map:
- Customer present → read its `rate`, `payee`, and `rail`.
- Customer absent → **skip** (no commission due — "not in the commission map"). Note it in the skip list so the owner can confirm.
- `commission = round(amountReceived * rate, 2)`. On a **partial payment**, commission on the amount actually received (the QBO Payment amount), not the invoice total.

### 4. Dedupe — before paying

For each candidate, check the QBO marker: `search_bills` for `DocNumber = COMM-{qboPaymentId}` (fallback: `PrivateNote LIKE` the payment id). A positive hit ⇒ skip and show "already paid". This makes the run safe to re-run: a second pass reports everything "already paid".

### 5. Resolve the payee for each candidate

For each surviving candidate, take the `payee` + `rail` from the commission map:
- **ACH / Wire** → carry the payee's **name** (passed as `recipientId`; per [DATA-MODEL.md](DATA-MODEL.md)). The bank resolves it to the saved payee — no raw ABA/account handling.
- **Stablecoin** → carry the payee's wallet address; call `get_stablecoin_recipient` and confirm it is **VERIFIED** — refuse the row otherwise (see Edge cases). The fee comes from the batch dry-run in step 6, not from a separate preview call.

If a payee has no saved payee and no inline details, **flag it and exclude it — never guess** a payment detail.

Resolve the source account via `list_accounts` and pay from the operating account (confirm which one in the table if there is more than one).

### 6. Assemble the batch and dry-run it

Build **one** `make_batch_payment` `payments` array covering every surviving candidate (≤50 items, mixed rails in a single call — see exact shapes in [DATA-MODEL.md](DATA-MODEL.md)). **Pay by the payee's name** for ACH and wire payees; **degrade gracefully** to an inline recipient block only if a payee has no saved payee:
- **ACH** item → `{rail: "ach", fromAccountNumber, recipientId: <payee name>, paymentAmount, paymentName: "Commission COMM-{qboPaymentId}"}` (the bank resolves the name to the saved payee). Batch ACH items are made **and authorized** automatically — no separate `authorize_ach_payment`.
- **Wire** item → `{rail: "wire", fromAccountNumber, recipientId: <payee name>, amount, purposeOfWire: "Sales commission"}`. `processDate` is **optional** and defaults to the next business day — set it only to override.
- **Stablecoin** item → `{rail: "stablecoin", walletAddress, currency: "USD", accountNumber: <the funding account>, amount}` (pay-by-name is ACH/Wire only).

Call `make_batch_payment` with **`dryRun: true`** first: it validates every item without moving money and returns the **real 1% fee** for each stablecoin item (other rails report `validated_not_executed`). Fix any per-item validation errors (or move the item to the flagged list) before showing the confirmation table.

### 7. Confirm — the gate

Present a single table — fees from the dry-run, not estimates — and **wait for explicit owner approval**. Nothing moves money before this. Example layout (the values below are the demo world's numbers, labeled **example** — live data drives the real table):

| Customer | QBO Payment | Gross | Rate | Commission | Payee | Rail | Status |
|---|---|---|---|---|---|---|---|
| _Thames Fintech_ | _paymentId_ | $6,400 | 5% | $320.00 | _ACH payee_ | ACH | ready |
| _Zurich Dynamics_ | _paymentId_ | $7,200 | 10% | $720.00 | _wire payee_ | Wire | ready |
| _Mitsui Digital_ | _paymentId_ | $2,100 | 10% | $210.00 (+$2.10 fee) | _stablecoin payee_ | Stablecoin | ready (verified) |

Also show: skipped (customer not in the commission map — e.g. the demo's Hallsten & Berg), already-paid (with the prior reference), unmatched (both lists from step 2), and flagged (missing/unverified payee). Get a clear "yes, pay these" — partial approval is fine, but adding or changing a row after approval starts a new round **and a fresh dry-run**.

### 8. Execute — one live batch call

Re-submit the approved `payments` array (dropping any rows the owner excluded) with `dryRun` off; leave `stopOnError` at its default (false) so every item is attempted and reported. Then:
- Map `results[index]` back to commission rows **by index** — capture each item's `paymentId` as the Paywhere reference, and the actual `fee` on stablecoin items.
- **`make_batch_payment` is NOT idempotent.** On partial failure (`summary.failed > 0`), re-submit **only the failed items** in a new call — never the whole array, or every previously succeeded payment doubles.
- Optionally verify settlement with the per-rail status tools (`get_ach_payment_status`, `get_wire_payment_status`, `get_stablecoin_payment_status`) using the returned `paymentId`s.

### 9. Record — the QBO marker

For every commission that disbursed, **write the marker** so dedupe is never lost, even if a later step fails — **`create-bill`** (note the hyphen) against the payee's vendor, then `create_bill_payment`, with:
- `DocNumber`: `COMM-{qboPaymentId}`
- `PrivateNote`: `Commission on QBO payment {qboPaymentId} for {customer} @ {rate} — Paywhere {rail} ref {paywherePaymentId}`

End with a summary listing each commission with both its **QBO** (Bill id) and **Paywhere** (payment id) references, plus totals by rail and total fees.

## Edge cases — spell these out, don't guess

- **Partial payment**: commission on the amount actually received (the QBO Payment amount), not the invoice total. (In the demo world, Mitsui pays in two $2,100 halves — commission each half it actually receives: $210.)
- **Multiple payments per customer in range**: each QBO Payment is its own commission line with its own `COMM-{id}` marker. Do not collapse them.
- **Payee has no configured recipient and no inline details**: flag and exclude; never fabricate ABA, bank aba, or wallet values.
- **Unverified stablecoin recipient** (`get_stablecoin_recipient` not VERIFIED): do not pay on that rail. Exclude the row and tell the owner how to fix it — register and verify the wallet with `create_stablecoin_recipient` / `get_stablecoin_recipient` (the demo world seeds a verified recipient — see [../../DATASET.md](../../DATASET.md)).
- **Batch partial failure**: per-item `ok` flags tell you exactly which rows paid. Record the successes immediately (step 9 — marker first), then re-submit **only** the failed items; the tool is not idempotent. An item that failed validation in the dry-run never makes it into the live call.
- **Paywhere succeeds but QBO Bill write fails**: the money already moved — retry the QBO marker and report the partial state explicitly (customer, commission, Paywhere `paymentId`) so dedupe still catches it next run. Never treat the run as clean until the marker exists in QBO.
- **Unmatched credits / payments**: surface both lists; never commission on a Paywhere credit that has no matching QBO payment, or vice versa.
- **Commission map missing**: stop and resolve it with the owner (see Setup) — never invent rates or payees.

## Graceful degradation

- **Without Paywhere**: no credits to verify against and no rails to pay on. Fall back to a QBO-only *draft*: `search_payments` for the range, join to the commission map, dedupe via the `COMM-` markers, and present the would-pay table clearly labeled "drafted — unverified against the bank, nothing disbursed". Nothing is recorded (nothing happened).
- **Without QuickBooks**: credits can't be attributed to customers and dedupe loses its system-of-record signal — show the raw credit list and stop; do not pay.
- **Without the commission map**: stop — see Setup. The map is the source of truth; there is no degraded mode that guesses rates or payees.

## Approval gates

- **Never move money without explicit approval** of the confirmation table (Step 7).
- **Never pay a candidate that fails dedupe** (Step 4) — show it as already-paid instead.
- **Never invent payment details.** A payee with no configured recipient and no inline details is flagged and excluded, not guessed.
- **One approval covers one batch** — exactly one live `make_batch_payment` call. Changing the set after approval starts a new round (and a new dry-run).

## Reference

- [DATA-MODEL.md](DATA-MODEL.md) — the commission map shape, the payee names, the dedupe marker, and the real MCP tool signatures (batch + single-payment fallbacks).
- [../../DATASET.md](../../DATASET.md) — the demo world's commission map, payees, rails, and verified stablecoin recipient (seeded by `/demo-setup`).
