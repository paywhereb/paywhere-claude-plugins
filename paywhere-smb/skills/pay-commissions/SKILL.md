---
name: pay-commissions
version: 0.1.0
description: >
  Pays sales commissions on payments your business actually received, across
  all three Paywhere rails (ACH, Wire, Stablecoin). Reads a "commission
  register" Google Sheet (who gets paid, at what rate, by which rail) as the
  source of truth, matches Paywhere bank credits to QuickBooks customer
  payments, computes each commission, dedupes against already-paid runs, and —
  only after you approve — disburses via Paywhere and books the expense as a
  Bill + Bill Payment in QuickBooks. Use when the owner says "pay commissions,"
  "run commissions for last week," "pay my reps," or asks who is owed
  commission.
---

# Pay Commissions

## Quick start

```
User: "pay commissions for last week"
→ Open the commission register Google Sheet (Customers + ACH/Wire/Stablecoin + PaidLog tabs)
→ Pull Paywhere credits for the range; match each to a QuickBooks customer payment
→ Join paying customers to the register → rate, payee, rail
→ Dedupe: skip anything already booked (QBO marker Bill or PaidLog row)
→ Show a table: customer, payment, gross, rate, commission, payee, rail, status
→ WAIT for explicit approval — nothing moves money before this
→ Disburse per rail, book a marker Bill + Bill Payment in QBO, append a PaidLog row
```

Money moves on three rails and is recorded in two systems. Get the data model right before running — read [DATA-MODEL.md](DATA-MODEL.md).

## What is the source of truth

- **The commission register Google Sheet** decides *who* gets commission, at *what rate*, to *which payee*, on *which rail*, with the *payment details* for that rail. A customer not listed in the register's `Customers` tab earns no commission — skip them.
- **QuickBooks** is the system of record for the *payments received* (the unit we commission on) and for the *commission expense* (a Bill + Bill Payment per commission paid).
- **Paywhere** is the bank — it shows the credits that prove a customer actually paid, and it is the rail that disburses each commission.

Commission config is **never** stored as JSON in QBO notes. The register Sheet is the only place who-gets-paid / rate / payment details live.

## Setup (first run only)

If the commission register Sheet doesn't exist yet, do not improvise one — stop and point the owner at the `commission-setup` skill, which seeds the register, the QBO vendors/history, and the verified Paywhere stablecoin recipient. Resume `pay-commissions` once setup has run.

## Workflow

### 1. Open the register

- `search_files` (Google Drive) for the commission register by name (default `Paywhere Commission Register`). If more than one matches, list them and ask which to use. If none, stop and recommend `commission-setup`.
- Read the tabs with `read_file_content`: `Customers`, `ACH`, `Wire`, `Stablecoin`, `PaidLog`. See [DATA-MODEL.md](DATA-MODEL.md) for the exact columns.
- Build in-memory lookups: `Customers` keyed by Customer DisplayName; each rail tab keyed by `Payee`; `PaidLog` as a set of `QBOPaymentId` already paid.

### 2. Collect incoming payments (Paywhere)

- `list_accounts` to enumerate accounts. Determine the date range from the owner's phrase ("last week", "May") as concrete `fromDate`/`toDate` (YYYY-MM-DD).
- For each account, `get_account_transactions` over the range and keep **credits only** (positive `amount`). These are the candidate payments we commission on.

### 3. Match credits to QuickBooks payments

- QuickBooks `search_payments` over the same range. Each QBO Payment carries the `CustomerRef` DisplayName — this is the join key to the register.
- Match each Paywhere credit to a QBO payment on **amount + date (±2 business days)**.
- List unmatched Paywhere credits and unmatched QBO payments separately for the owner — do not commission on either until matched. The **QBO Payment is the unit we commission on** (it carries the customer); a Paywhere credit with no QBO payment can't be attributed.

### 4. Look up the commission

For each matched QBO payment, join its customer DisplayName to the `Customers` tab:
- Customer present → read `CommissionRate`, `Payee`, `Rail`.
- Customer absent → **skip** (no commission due). Note it in the skip list so the owner can confirm.
- `commission = round(amountReceived * CommissionRate, 2)`. On a **partial payment**, commission on the amount actually received (the QBO Payment amount), not the invoice total.

### 5. Dedupe — before paying

For each candidate, check **two independent signals**; either positive ⇒ skip and show "already paid":
1. **QBO**: `search_bills` for `DocNumber = COMM-{qboPaymentId}` (fallback: `PrivateNote LIKE` the payment id).
2. **Register**: `QBOPaymentId` already present in `PaidLog`.

This makes the run safe to re-run: a second pass reports everything "already paid".

### 6. Resolve payees and rail details

For each surviving candidate, read the rail tab row keyed by `Payee`:
- **ACH** → `RecipientName`, `ABA`, `AccountNumber`, `AccountType`, `Email`.
- **Wire** → `RecipientName`, `RecipientAccount`, `RecipientAddr1`, `City`, `State`, `PostalCode`, `BankName`, `RoutingNumber`.
- **Stablecoin** → `WalletAddress`, `Chain`, `Currency`. Additionally call `get_stablecoin_recipient` for the wallet and confirm it is **verified**. Then run `make_stablecoin_payment` with `preview: true` to surface the 1% fee for the confirmation table.

If a payee's rail row is missing or malformed (blank ABA, no routing number, etc.), **flag it and exclude it — never guess** a payment detail.

Resolve the source account: use `list_accounts` and pay from the operating account (confirm which one in the table if there is more than one).

### 7. Confirm — the gate

Present a single table and **wait for explicit owner approval**. Nothing moves money before this.

| Customer | QBO Payment | Gross | Rate | Commission | Payee | Rail | Status |
|---|---|---|---|---|---|---|---|
| Acme Corp | 1042 | $4,000 | 5% | $200.00 | Jane Doe Referrals | ACH | ready |
| Globex | 1043 | $9,000 | 10% | $900.00 (+$9.00 fee) | CryptoConsult DAO | Stablecoin | ready (verified) |
| Initech | 1044 | $2,500 | 5% | $125.00 | Acme Sales Partners LLC | Wire | ready |

Also show: skipped (customer not in register), already-paid (with the prior reference), and flagged (missing/unverified payee). Get a clear "yes, pay these" — partial approval is fine, but adding or changing a row after approval starts a new round.

### 8. Execute — per rail

Pay only the approved rows. Match each rail to its API exactly (see real schemas in [DATA-MODEL.md](DATA-MODEL.md)):
- **ACH** → `make_ach_payment` with `recipientIdType: "Inline"` and the `recipient` block from the ACH tab; `fromAccountNumber`, `paymentAmount`, `paymentDate` (today), `paymentName` like `Commission COMM-{qboPaymentId}`. Poll `get_ach_payment_status`.
- **Wire** → `make_wire_payment` with `recipient` + `recipientBank` from the Wire tab; `fromAccountNumber`, `amount`, `processDate`. Poll `get_wire_payment_status`.
- **Stablecoin** → `make_stablecoin_payment` (`preview: false`) with `walletAddress`, `currency`, `accountNumber`, `amount`. Poll `get_stablecoin_payment_status`. Capture the 1% fee from the response.

Capture each `paymentId` as the Paywhere reference.

### 9. Record — both systems

For every commission that disbursed, **write the marker first so dedupe is never lost**, even if a later step fails:
1. **QBO marker**: `create_bill` against the payee's vendor, then `create_bill_payment`, with:
   - `DocNumber`: `COMM-{qboPaymentId}`
   - `PrivateNote`: `Commission on QBO payment {qboPaymentId} for {customer} @ {rate} — Paywhere {rail} ref {paywherePaymentId}`
2. **Register**: append a row to `PaidLog` — `Date | Customer | QBOPaymentId | GrossAmount | Rate | Commission | Payee | Rail | PaywherePaymentId | QBOBillId`.

End with a summary listing each commission with both its **QBO** (Bill id) and **Paywhere** (payment id) references, plus totals by rail.

## Edge cases — spell these out, don't guess

- **Partial payment**: commission on the amount actually received (the QBO Payment amount), not the invoice total.
- **Multiple payments per customer in range**: each QBO Payment is its own commission line with its own `COMM-{id}` marker. Do not collapse them.
- **Payee / rail row missing or malformed**: flag and exclude; never fabricate ABA, routing, or wallet values.
- **Unverified stablecoin recipient** (`get_stablecoin_recipient` not verified): do not pay on that rail. Offer an ACH fallback only if the payee also has a valid ACH row, otherwise skip and tell the owner to verify via `commission-setup`.
- **Paywhere succeeds but QBO Bill write fails**: the money already moved — write the `PaidLog` row immediately and retry the QBO marker; report the partial state explicitly so dedupe still catches it next run. Never treat the run as clean until the marker exists in at least one system (PaidLog).
- **Unmatched credits / payments**: surface both lists; never commission on a Paywhere credit that has no matching QBO payment, or vice versa.

## Approval gates

- **Never move money without explicit approval** of the confirmation table (Step 7).
- **Never pay a candidate that fails dedupe** (Step 5) — show it as already-paid instead.
- **Never invent payment details.** A missing or malformed register row is flagged and excluded, not guessed.
- **One approval covers one batch.** Changing the set after approval starts a new round.

## Reference

- [DATA-MODEL.md](DATA-MODEL.md) — register tab schemas, the rail-tab → Paywhere-API field mapping, dedupe markers, and the real MCP tool signatures.
