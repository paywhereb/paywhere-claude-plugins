# Commission data model

Three concerns, three homes:

| Concern | Home | Why |
|---|---|---|
| (a) Who gets commission + at what rate | **Register Sheet** `Customers` tab | Business policy — changes often, owner-editable, not a QBO concept |
| (b) How to pay each payee (rail + account details) | **Register Sheet** rail tabs | Payment instructions map 1:1 onto Paywhere's three rail APIs |
| (c) Pay once and only once | **QBO marker Bill** + Register `PaidLog` | Two independent dedupe signals; QBO is the system of record for the expense |

Commission config is **not** stored as JSON in QBO notes — that was rejected. The Google Sheet is the source of truth for (a) and (b). QBO records *payments received* (what we commission on) and the *commission expense* (Bill + Bill Payment).

## The commission register Google Sheet

Default name: `Paywhere Commission Register`. Discovered by name via Google Drive `search_files`. Read tabs with `read_file_content`. Five normalized tabs:

### Tab `Customers` — (a) who gets commission, at what rate

One row per commission-eligible customer. A customer **not** in this tab earns no commission (skip).

| Column | Meaning |
|---|---|
| `Customer` | Matches the QBO Payment's `CustomerRef` DisplayName exactly |
| `CommissionRate` | Decimal, e.g. `0.05` for 5% |
| `Payee` | Join key into the matching rail tab |
| `Rail` | One of `ACH` / `Wire` / `Stablecoin` — which tab holds this payee's details |

### Tab `ACH` — (b) ACH payment details

| Column | → `make_ach_payment` field |
|---|---|
| `Payee` | join key (not sent) |
| `RecipientName` | `recipient.name` |
| `ABA` | `recipient.aba` (9 digits) |
| `AccountNumber` | `recipient.accountNumber` |
| `AccountType` | `recipient.accountType` (`Checking` / `Savings`) |
| `Email` | `recipient.emailAddress` |

### Tab `Wire` — (b) wire payment details

| Column | → `make_wire_payment` field |
|---|---|
| `Payee` | join key (not sent) |
| `RecipientName` | `recipient.name` |
| `RecipientAccount` | `recipient.accountNumber` |
| `RecipientAddr1` | `recipient.address1` |
| `City` | `recipient.city` |
| `State` | `recipient.state` |
| `PostalCode` | `recipient.postalCode` |
| `BankName` | `recipientBank.name` |
| `RoutingNumber` | `recipientBank.routingNumber` |

### Tab `Stablecoin` — (b) stablecoin payment details

| Column | → `make_stablecoin_payment` / recipient |
|---|---|
| `Payee` | join key (not sent) |
| `WalletAddress` | `walletAddress` — also the join key for `get_stablecoin_recipient` |
| `Chain` | `ETH` / `POLY` / `ARB` / `BASE` / `SOL` (used at recipient-creation time) |
| `Currency` | `USD` (the only supported stablecoin currency) |

Stablecoin payees must additionally be pre-registered **and verified** in Paywhere via `create_stablecoin_recipient`; check status with `get_stablecoin_recipient` before paying. The wallet address is the join key between the tab and Paywhere.

### Tab `PaidLog` — (c) append-only audit + dedupe

Append one row per commission paid. Never edit or delete prior rows.

`Date | Customer | QBOPaymentId | GrossAmount | Rate | Commission | Payee | Rail | PaywherePaymentId | QBOBillId`

## Dedupe — pay once and only once

Checked **before** paying. Either signal positive ⇒ skip and report "already paid":

1. **QBO marker Bill** — `search_bills` for `DocNumber = COMM-{qboPaymentId}` (fallback: `PrivateNote LIKE` the payment id). This is the system-of-record signal.
2. **Register `PaidLog`** — `QBOPaymentId` already present.

The marker written at record-time:
- `DocNumber`: `COMM-{qboPaymentId}` — the QBO Payment being commissioned (the natural unique key).
- `PrivateNote`: `Commission on QBO payment {id} for {customer} @ {rate} — Paywhere {rail} ref {paywherePaymentId}`.

Because `search_bills` filters DocNumber and PrivateNote with `LIKE`, both the exact-DocNumber check and the payment-id fallback work against the same field.

## Real MCP tool signatures (Paywhere)

Match these exactly — the register columns above map onto them.

**`make_ach_payment`** — required: `fromAccountNumber`, `recipientIdType` (`"Inline"`), `paymentAmount`, `paymentDate` (YYYY-MM-DD), `paymentName`; `recipient`: `{ name, aba, accountNumber, accountType: "Checking"|"Savings", emailAddress }`. Returns `paymentId`. Status: `get_ach_payment_status`.

**`make_wire_payment`** — required: `fromAccountNumber`, `amount`, `processDate` (YYYY-MM-DD), `recipient` `{ name, accountNumber, address1, city, state, postalCode }`, `recipientBank` `{ name, routingNumber, address1, city, state, postalCode }`. `autoApprove` defaults true. Returns `paymentId`. Status: `get_wire_payment_status`.

**`make_stablecoin_payment`** — required: `walletAddress`, `currency` (`"USD"`), `accountNumber`, `amount`. `preview: true` returns the 1% fee estimate without executing. Recipient must be verified. Returns `paymentId`, `fee`, `status`. Status: `get_stablecoin_payment_status`.

**`create_stablecoin_recipient`** — `wallet` `{ address, chain, currency: "USD" }`, `walletOwner` `{ type: "Self"|"Individual"|"Business", name, address }`, `description`. Returns verification statuses. **`get_stablecoin_recipient`** `{ walletAddress }` fetches current verification status.

**`get_account_transactions`** — `{ accountNumber, fromDate, toDate, pageNumber?, pageSize? }`. Credits are positive `amount`. Enumerate accounts with `list_accounts`.

## Real MCP tool signatures (QuickBooks fork)

- `search_payments` — filter by customer / date; each Payment carries `CustomerRef` DisplayName and amount. The unit we commission on.
- `search_bills` — filters `DocNumber` and `PrivateNote` with `LIKE` (the dedupe mechanism).
- `create_bill` + `create_bill_payment` — accept `DocNumber` and `PrivateNote`; book the commission expense against the payee vendor.
- `create_vendor` — creates the payee vendor (done in `commission-setup`).

## Google Drive tool signatures

- `search_files` — find the register by name.
- `read_file_content` / `download_file_content` — read the tabs.
- `create_file` — used by `commission-setup` to build the register; `pay-commissions` appends `PaidLog` rows.
