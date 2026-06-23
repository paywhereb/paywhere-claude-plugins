# Commission data model

Three concerns, three homes — all server-known or in QuickBooks, no local files:

| Concern | Home | Why |
|---|---|---|
| (a) Who gets commission + at what rate | **The commission map** (server-side, surfaced with the seeded QBO payments) | Business policy — configured at setup, not entered per run |
| (b) How to pay each payee (rail + recipient) | **Pre-configured Paywhere recipients** (ACH/Wire) + a **verified stablecoin recipient** | Payment details live in the recipient store; a pay step passes only a `recipientRef` |
| (c) Pay once and only once | **QBO marker Bill** (`COMM-{qboPaymentId}`) | The system-of-record dedupe signal |

Commission config is **not** stored as JSON in QBO notes and **not** on the QBO vendor record. The commission map is the source of truth for (a); the Paywhere recipient store holds (b). QBO records *payments received* (what we commission on) and the *commission expense* (Bill + Bill Payment).

## The commission map

A small server-known table — one row per commission-eligible customer — surfaced alongside the seeded QBO customer payments. A customer **not** in the map earns no commission (skip — the "not in the register" path).

| Field | Meaning |
|---|---|
| `client` | Matches the QBO Payment's `CustomerRef` DisplayName exactly |
| `rate` | Decimal, e.g. `0.05` for 5% |
| `payee` | The party paid the commission |
| `rail` | One of `ACH` / `Wire` / `Stablecoin` |

The demo world's concrete map (client → rate → payee → rail) is documented in [../../DATASET.md](../../DATASET.md). For reference, the demo values are:

| Client | Rate | Payee | Rail | Commission (full month) |
|---|---|---|---|---|
| Thames Fintech | 5% | Jane Doe Referrals | ACH | $320 |
| Alderbrook | 5% | Jane Doe Referrals | ACH | $240 |
| Zurich Dynamics | 10% | Acme Sales Partners LLC | Wire | $720 |
| Mitsui Digital | 10% | CryptoConsult DAO | Stablecoin | $420 (half: $210) |
| Hallsten & Berg | — | — | — | absent → "skipped, not in the register" |

## How each payee is paid

- **ACH / Wire** — the payee is **pre-configured as a Paywhere recipient** at setup. The pay step passes a `recipientRef` (`ach:<slug>` / `wire:<slug>`) + amount; the server fills the bank/wire details. No raw ABA/account/routing handling in this skill.
- **Stablecoin** — the payee's wallet is **pre-registered and VERIFIED** in Paywhere via `create_stablecoin_recipient`; check status with `get_stablecoin_recipient` before paying. The pay step uses `{walletAddress, currency: "USD", accountNumber, amount}` — stablecoin has no `recipientRef` form.

**Graceful fallback:** if a real payee has no pre-configured recipient (not yet onboarded), fall back to an inline recipient block on the payment item rather than erroring (see "Tool signatures"). The demo payees are all pre-configured.

## Dedupe — pay once and only once

Checked **before** paying. The marker positive ⇒ skip and report "already paid":

- **QBO marker Bill** — `search_bills` for `DocNumber = COMM-{qboPaymentId}` (fallback: `PrivateNote LIKE` the payment id). This is the system-of-record signal.

The marker written at record-time:
- `DocNumber`: `COMM-{qboPaymentId}` — the QBO Payment being commissioned (the natural unique key).
- `PrivateNote`: `Commission on QBO payment {id} for {customer} @ {rate} — Paywhere {rail} ref {paywherePaymentId}`.

Because `search_bills` filters DocNumber and PrivateNote with `LIKE`, both the exact-DocNumber check and the payment-id fallback work against the same field.

## Real MCP tool signatures (Paywhere)

Match these exactly — the register columns above map onto them.

**`make_batch_payment`** — the execution call: **one call per run**, mixed rails. `payments: []` of 1–50 items, each discriminated by `rail`. **Prefer `recipientRef`** for ACH/Wire; the inline forms are the graceful fallback when a payee has no pre-configured recipient:

- `{rail: "ach", fromAccountNumber, recipientRef, paymentAmount, paymentName}` — **preferred**; the server fills the recipient. Batch ACH items are made **and authorized** automatically (no separate `authorize_ach_payment`). **Fallback**: `{rail: "ach", fromAccountNumber, recipientIdType: "Inline", recipient: {name, aba, accountNumber, accountType, emailAddress}, paymentAmount, paymentName}`.
- `{rail: "wire", fromAccountNumber, recipientRef, amount, purposeOfWire?, autoApprove? (default true)}` — **preferred**. **Fallback**: `{rail: "wire", fromAccountNumber, amount, recipient: {name, accountNumber, address1, city, state, postalCode}, recipientBank: {name, **aba**}, purposeOfWire?}`. `processDate` is **optional** and defaults to the next business day server-side; set it only to override.
- `{rail: "stablecoin", walletAddress, currency: "USD", accountNumber (the funding account), amount}` — no `recipientRef` form.

Options and results:
- `dryRun: true` — validates every item **without moving money**; stablecoin items return the **real 1% fee** preview, other rails report status `validated_not_executed`. Run the dry-run before the confirmation table, the live call after approval.
- `stopOnError?: bool` (default false — continues and reports per item).
- Returns `{summary: {requested, attempted, succeeded, failed, validatedOnly, byRail, totalSucceededAmount}, results: [{index, rail, ok, paymentId?, fee?, status?, error?}], warning}`. `results[index]` maps back to the commission row at the same position in the `payments` array.
- **NOT idempotent**: on partial failure re-submit **only** the failed items in a new call — never the whole array.

**`query_transactions`** — the collection call: `{accountNumbers? (default all accounts), dateFrom?, dateTo? (YYYY-MM-DD, inclusive), direction: "credit", status?: ["posted"], amountMin?/amountMax?, descriptionContains?, sort?, limit? (1–500), includeTransactions: true}` → `{accountsQueried, scanned, matched, returned, truncated, transactions}`. Credits = money in. `truncated: true` ⇒ the scan hit caps — narrow the date range and re-query.

**Single-payment fallbacks** — for one-off corrections (e.g. re-paying a single failed item by hand); the run itself uses the batch call:

- **`make_ach_payment`** — required: `fromAccountNumber`, `paymentAmount`, `paymentName`, and either `recipientRef` **or** the inline `recipientIdType: "Inline"` + `recipient` `{name, aba, accountNumber, accountType: "Checking"|"Savings", emailAddress}`. `paymentDate` (YYYY-MM-DD) is optional. Returns `paymentId` **drafted** — unlike batch ACH it needs `authorize_ach_payment` to move. Status: `get_ach_payment_status`.
- **`make_wire_payment`** — required: `fromAccountNumber`, `amount`, and either `recipientRef` **or** the inline `recipient` `{name, accountNumber, address1, city, state, postalCode}` + `recipientBank` `{name, **aba** (NOT routingNumber), address1?, city?, state?, postalCode?}`. `processDate` (YYYY-MM-DD) is **optional** and defaults to the next business day. `autoApprove` defaults true. Returns `paymentId`. Status: `get_wire_payment_status`.
- **`make_stablecoin_payment`** — required: `walletAddress`, `currency` (`"USD"`), `accountNumber`, `amount`. `preview: true` returns the 1% fee estimate without executing (the batch dry-run covers this in the normal flow). Recipient must be VERIFIED. Returns `paymentId`, `fee`, `status`. Status: `get_stablecoin_payment_status`.
- **`create_stablecoin_recipient`** — `wallet` `{address, chain, currency: "USD"}`, `walletOwner` `{type: "Self"|"Individual"|"Business", name, address}`, `description`. Returns verification statuses. **`get_stablecoin_recipient`** `{walletAddress}` fetches current verification status.
- **`get_account_transactions`** — `{accountNumber, fromDate, toDate, pageNumber?, pageSize?}`; credits are positive `amount`. Legacy paging fallback for collection — prefer `query_transactions`.
- **`list_accounts`** — enumerate accounts; resolve the funding account at run time, never hardcode it.

## Real MCP tool signatures (QuickBooks fork)

Note the fork's naming anomaly: **bill and vendor CRUD use hyphens** (`create-bill`, `get-bill`, `update-bill`, `delete-bill`, `create-vendor`, `get-vendor`, `update-vendor`, `delete-vendor`); everything else uses underscores.

- `search_payments` — filter by customer / date; each Payment carries `CustomerRef` DisplayName and amount. The unit we commission on.
- `search_bills` — filters `DocNumber` and `PrivateNote` with `LIKE` (the dedupe mechanism).
- **`create-bill`** + `create_bill_payment` — accept `DocNumber` and `PrivateNote`; book the commission expense against the payee vendor.
- **`create-vendor`** — creates the payee vendor (the demo world's payees are seeded by `/demo-setup` — see [../../DATASET.md](../../DATASET.md)). The vendor record carries **no** payment details — ABA/account/wallet live only in the Paywhere recipient store.
