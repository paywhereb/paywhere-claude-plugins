---
name: commission-setup
version: 0.1.0
description: >
  Seeds (or resets) the demo for pay-commissions — builds the "commission
  register" Google Sheet, creates the matching payee vendors and historical
  customer payments in QuickBooks, and registers + verifies the stablecoin
  recipient in Paywhere. Idempotent: search-before-create on every entity, so
  re-running tops up what's missing without duplicating. Use before the first
  pay-commissions run, or to reset the demo. Triggers: "set up commissions,"
  "seed the commission demo," "reset commission data."
---

# Commission Setup

Stands up everything `pay-commissions` needs so its first run is a clean demo and its second run proves dedupe. Read [pay-commissions/DATA-MODEL.md](../pay-commissions/DATA-MODEL.md) first — this skill creates exactly that data model.

## Idempotency rule (applies to every step)

**Search before create, always.** Re-running must top up what's missing, never duplicate:
- Sheet — find by name (`search_files`) before `create_file`.
- Vendors — match by DisplayName before `create_vendor`.
- QBO invoices/payments — match by `DocNumber` before creating.
- Register rows — match by key (Customer / Payee / `QBOPaymentId`) before appending.
- Stablecoin recipient — `get_stablecoin_recipient` by wallet before `create_stablecoin_recipient`.

## Workflow

### 1. Build the commission register Sheet

`search_files` for `Paywhere Commission Register`. If absent, `create_file` (Google Drive) a Sheet with five tabs and seed rows. Three payees, one per rail; ~4 customers mapped at mixed rates; deliberately leave other QBO customers **off** the `Customers` tab to demo the skip path.

**`Customers`** (Customer | CommissionRate | Payee | Rail):

| Customer | CommissionRate | Payee | Rail |
|---|---|---|---|
| Acme Corp | 0.05 | Jane Doe Referrals | ACH |
| Globex | 0.10 | CryptoConsult DAO | Stablecoin |
| Initech | 0.05 | Acme Sales Partners LLC | Wire |
| Soylent | 0.10 | Jane Doe Referrals | ACH |

**`ACH`** (Payee | RecipientName | ABA | AccountNumber | AccountType | Email):

| Payee | RecipientName | ABA | AccountNumber | AccountType | Email |
|---|---|---|---|---|---|
| Jane Doe Referrals | Jane Doe | 021000021 | 1234567890 | Checking | jane@example.com |

**`Wire`** (Payee | RecipientName | RecipientAccount | RecipientAddr1 | City | State | PostalCode | BankName | RoutingNumber):

| Payee | RecipientName | RecipientAccount | RecipientAddr1 | City | State | PostalCode | BankName | RoutingNumber |
|---|---|---|---|---|---|---|---|---|
| Acme Sales Partners LLC | Acme Sales Partners LLC | 9876543210 | 100 Market St | San Francisco | CA | 94105 | Demo Bank NA | 121000248 |

**`Stablecoin`** (Payee | WalletAddress | Chain | Currency):

| Payee | WalletAddress | Chain | Currency |
|---|---|---|---|
| CryptoConsult DAO | 0xc838058cc6c71db99c9ac001e6f003e65ffbcca4 | POLY | USD |

**Real Polygon (POLY) test addresses** — draw from these when creating example
stablecoin recipients (real wallets on the test chain, safe for demos). Seed
the first by default; if you stand up more than one stablecoin payee, pick the
next unused one rather than reusing an address:

- `0xc838058cc6c71db99c9ac001e6f003e65ffbcca4`
- `0xf9b6e65ea4e02122295253cdeaa51082e46b7613`
- `0xaacb9205d4087ae89af823d008bbc392689dffe4`
- `0x495ebc4aa079b959a0e9a301ad9331b98ac18219`
- `0x18500a1c9a8864587cb751ed286e3cd23a279ef3`

> The bank ABAs/routing numbers above are placeholder test values — replace
> with real details before paying anyone real. The Polygon addresses are real
> wallets on the test chain, intended for demo stablecoin recipients.

**`PaidLog`** — header row only (append-only thereafter):
`Date | Customer | QBOPaymentId | GrossAmount | Rate | Commission | Payee | Rail | PaywherePaymentId | QBOBillId`

### 2. Create the QBO payee vendors

For each of the 3 payees, match by DisplayName then `create_vendor` if missing: `Jane Doe Referrals`, `Acme Sales Partners LLC`, `CryptoConsult DAO`. Bills and Bill Payments book against these vendors. **Payment details live only in the register, not on the vendor** — the vendor is just the expense counterparty.

### 3. Create QBO history (so "last week" returns results)

In the demo window (e.g. last week), for each mapped customer create a historical invoice + a received Payment (match by `DocNumber` before creating), so `pay-commissions` has QBO Payments to commission on. Use round amounts that make the math obvious (e.g. Acme $4,000 → 5% = $200).

Then **pre-create one marker Bill + Bill Payment** for one of those payments (`DocNumber = COMM-{thatPaymentId}`, the `PrivateNote` format from DATA-MODEL.md) **and** append a matching `PaidLog` row. This makes the dedupe path demo on the very first `pay-commissions` run (one row shows "already paid").

### 4. Paywhere side — verify the stablecoin recipient

`get_stablecoin_recipient` for the `Stablecoin` tab's wallet (a real Polygon test address from the list above); if not present/verified, `create_stablecoin_recipient` with that `wallet` (`address`, `chain: "POLY"`, `currency: "USD"`) and a `walletOwner`. Confirm it reaches **verified** before finishing — `pay-commissions` refuses to pay an unverified recipient.

> **Dependency — incoming bank credits (ENG-332).** `pay-commissions` matches Paywhere bank *credits* to QBO payments. Seeding mock incoming credits in the Paywhere demo env requires the **ENG-332** seeding MCP, which does not exist yet. Until it ships, this skill cannot fabricate Paywhere credits. Work around it by seeding the QBO Payments (Step 3) to **mirror whatever credits already exist** in the demo bank account (`list_accounts` → `get_account_transactions`), so amount+date matching still finds pairs. If the demo account has no credits in the window, note the gap explicitly: the matching step will list QBO payments as "unmatched" until ENG-332 lands.

### 5. Report

Summarize what was created vs. already present (Sheet + tab/row counts, vendors, QBO invoices/payments, the pre-seeded marker, stablecoin verification status), and tell the owner they can now run `pay-commissions "last week"`.

## Approval gates

- **Confirm before writing to QuickBooks or Paywhere.** Show the owner the seed plan (which vendors, how many invoices/payments, the stablecoin recipient) before creating anything that persists outside the Sheet.
- **Never delete existing data to "reset."** Top up missing entities idempotently; if a true reset is requested, list what would be removed and get explicit confirmation first.

## Reference

- [pay-commissions/DATA-MODEL.md](../pay-commissions/DATA-MODEL.md) — the exact schema this skill seeds, plus real MCP tool signatures.
