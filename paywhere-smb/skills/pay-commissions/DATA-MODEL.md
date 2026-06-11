# Commission data model

Three concerns, three homes:

| Concern | Home | Why |
|---|---|---|
| (a) Who gets commission + at what rate | **Register workbook** `Customers` sheet | Business policy — changes often, owner-editable, not a QBO concept |
| (b) How to pay each payee (rail + account details) | **Register workbook** rail sheets | Payment instructions map 1:1 onto Paywhere's three rail item shapes |
| (c) Pay once and only once | **QBO marker Bill** + Register `PaidLog` | Two independent dedupe signals; QBO is the system of record for the expense |

Commission config is **not** stored as JSON in QBO notes — that was rejected. The local workbook is the source of truth for (a) and (b). QBO records *payments received* (what we commission on) and the *commission expense* (Bill + Bill Payment).

## Local register file

- **What**: one Excel workbook, `commission-register.xlsx`, with five sheets: `Customers`, `ACH`, `Wire`, `Stablecoin`, `PaidLog`.
- **Location**: the session working folder. Not Google Sheets, not Drive — no Drive tools are involved.
- **Discovery**: by filename. Multiple matches → list and ask the owner; none → stop (Setup in [SKILL.md](SKILL.md), or [/demo-setup-commissions](../demo-setup-commissions/SKILL.md) for the demo scaffold).
- **Read/write**: locally with Bash + Python (openpyxl or an equivalent xlsx library). Rates and amounts are numbers, not strings.
- **Concurrency**: single-writer. Append `PaidLog` rows atomically — load the workbook, append, save as one operation (a sheet rewrite); never interleave manual edits with a run in flight.

### Sheet `Customers` — (a) who gets commission, at what rate

One row per commission-eligible customer. A customer **not** in this sheet earns no commission (skip).

| Column | Meaning |
|---|---|
| `Customer` | Matches the QBO Payment's `CustomerRef` DisplayName exactly |
| `CommissionRate` | Decimal, e.g. `0.05` for 5% |
| `Payee` | Join key into the matching rail sheet |
| `Rail` | One of `ACH` / `Wire` / `Stablecoin` — which sheet holds this payee's details |

### Sheet `ACH` — (b) ACH payment details

Maps onto the batch `ach` item's `recipient` block (identical to `make_ach_payment`'s). Always `recipientIdType: "Inline"` — never DisplayName (mock recipients are global and permanent, so DisplayName is ambiguous).

| Column | → ach item field |
|---|---|
| `Payee` | join key (not sent) |
| `RecipientName` | `recipient.name` |
| `ABA` | `recipient.aba` (9 digits) |
| `AccountNumber` | `recipient.accountNumber` |
| `AccountType` | `recipient.accountType` (`Checking` / `Savings`) |
| `Email` | `recipient.emailAddress` |

### Sheet `Wire` — (b) wire payment details

Maps onto the batch `wire` item (identical to `make_wire_payment`'s blocks). **The wire API's `recipientBank` takes `aba`, not `routingNumber`** — hence the `BankABA` column. (Legacy registers may still carry the old header `RoutingNumber`; it maps to the same `recipientBank.aba` field.)

| Column | → wire item field |
|---|---|
| `Payee` | join key (not sent) |
| `RecipientName` | `recipient.name` |
| `RecipientAccount` | `recipient.accountNumber` |
| `RecipientAddr1` | `recipient.address1` |
| `City` | `recipient.city` |
| `State` | `recipient.state` |
| `PostalCode` | `recipient.postalCode` |
| `BankName` | `recipientBank.name` |
| `BankABA` | `recipientBank.aba` |

### Sheet `Stablecoin` — (b) stablecoin payment details

| Column | → stablecoin item / recipient |
|---|---|
| `Payee` | join key (not sent) |
| `WalletAddress` | `walletAddress` — also the join key for `get_stablecoin_recipient` |
| `Chain` | e.g. `POLY` (used at recipient-creation time) — discover the live list via `list_supported_chains` |
| `Currency` | `USD` (the only supported stablecoin currency) |

Stablecoin payees must additionally be pre-registered **and VERIFIED** in Paywhere via `create_stablecoin_recipient`; check status with `get_stablecoin_recipient` before paying. The wallet address is the join key between the sheet and Paywhere.

### Sheet `PaidLog` — (c) append-only audit + dedupe

Append one row per commission paid. Never edit or delete prior rows.

`Date | Customer | QBOPaymentId | GrossAmount | Rate | Commission | Payee | Rail | PaywherePaymentId | QBOBillId`

Demo pre-seeded rows (written by /demo-setup-commissions) carry the sentinel `PaywherePaymentId = DEMO-SEED` — a marker created without a bank disbursement; it dedupes exactly like a real row.

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

**`make_batch_payment`** — the execution call: **one call per run**, mixed rails. `payments: []` of 1–50 items, each discriminated by `rail`:

- `{rail: "ach", fromAccountNumber, recipientIdType: "Inline", recipient: {name, aba, accountNumber, accountType, emailAddress}, paymentAmount, paymentDate (YYYY-MM-DD), paymentName}` — batch ACH items are made **and authorized** automatically (no separate `authorize_ach_payment`).
- `{rail: "wire", fromAccountNumber, amount, processDate (YYYY-MM-DD), recipient: {name, accountNumber, address1, city, state, postalCode}, recipientBank: {name, **aba**}, purposeOfWire?, autoApprove? (default true)}`.
- `{rail: "stablecoin", walletAddress, currency: "USD", accountNumber (the funding account), amount}`.

Options and results:
- `dryRun: true` — validates every item **without moving money**; stablecoin items return the **real 1% fee** preview, other rails report status `validated_not_executed`. Run the dry-run before the confirmation table, the live call after approval.
- `stopOnError?: bool` (default false — continues and reports per item).
- Returns `{summary: {requested, attempted, succeeded, failed, validatedOnly, byRail, totalSucceededAmount}, results: [{index, rail, ok, paymentId?, fee?, status?, error?}], warning}`. `results[index]` maps back to the commission row at the same position in the `payments` array.
- **NOT idempotent**: on partial failure re-submit **only** the failed items in a new call — never the whole array.

**`query_transactions`** — the collection call: `{accountNumbers? (default all accounts), dateFrom?, dateTo? (YYYY-MM-DD, inclusive), direction: "credit", status?: ["posted"], amountMin?/amountMax?, descriptionContains?, sort?, limit? (1–500), includeTransactions: true}` → `{accountsQueried, scanned, matched, returned, truncated, transactions}`. Credits = money in. `truncated: true` ⇒ the scan hit caps — narrow the date range and re-query.

**Single-payment fallbacks** — for one-off corrections (e.g. re-paying a single failed item by hand); the run itself uses the batch call:

- **`make_ach_payment`** — required: `fromAccountNumber`, `recipientIdType` (`"Inline"`), `paymentAmount`, `paymentDate` (YYYY-MM-DD), `paymentName`; `recipient`: `{name, aba, accountNumber, accountType: "Checking"|"Savings", emailAddress}`. Returns `paymentId` **drafted** — unlike batch ACH it needs `authorize_ach_payment` to move. Status: `get_ach_payment_status`.
- **`make_wire_payment`** — required: `fromAccountNumber`, `amount`, `processDate` (YYYY-MM-DD), `recipient` `{name, accountNumber, address1, city, state, postalCode}`, `recipientBank` `{name, **aba** (NOT routingNumber), address1?, city?, state?, postalCode?}`. `autoApprove` defaults true. Call `get_wire_config` before wires. Returns `paymentId`. Status: `get_wire_payment_status`.
- **`make_stablecoin_payment`** — required: `walletAddress`, `currency` (`"USD"`), `accountNumber`, `amount`. `preview: true` returns the 1% fee estimate without executing (the batch dry-run covers this in the normal flow). Recipient must be VERIFIED. Returns `paymentId`, `fee`, `status`. Status: `get_stablecoin_payment_status`.
- **`create_stablecoin_recipient`** — `wallet` `{address, chain, currency: "USD"}`, `walletOwner` `{type: "Self"|"Individual"|"Business", name, address}`, `description`. Returns verification statuses. **`get_stablecoin_recipient`** `{walletAddress}` fetches current verification status.
- **`get_account_transactions`** — `{accountNumber, fromDate, toDate, pageNumber?, pageSize?}`; credits are positive `amount`. Legacy paging fallback for collection — prefer `query_transactions`.
- **`list_accounts`** — enumerate accounts; resolve the funding account at run time, never hardcode it.

## Real MCP tool signatures (QuickBooks fork)

Note the fork's naming anomaly: **bill and vendor CRUD use hyphens** (`create-bill`, `get-bill`, `update-bill`, `delete-bill`, `create-vendor`, `get-vendor`, `update-vendor`, `delete-vendor`); everything else uses underscores.

- `search_payments` — filter by customer / date; each Payment carries `CustomerRef` DisplayName and amount. The unit we commission on.
- `search_bills` — filters `DocNumber` and `PrivateNote` with `LIKE` (the dedupe mechanism).
- **`create-bill`** + `create_bill_payment` — accept `DocNumber` and `PrivateNote`; book the commission expense against the payee vendor.
- **`create-vendor`** — creates the payee vendor (done in [/demo-setup-commissions](../demo-setup-commissions/SKILL.md)). The vendor record carries **no** payment details — ABA/account/wallet live only in the register.
