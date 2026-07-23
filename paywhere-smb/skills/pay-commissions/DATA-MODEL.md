# Commission data model

Three concerns, three homes — all server-known or in QuickBooks, no local files:

| Concern | Home | Why |
|---|---|---|
| (a) Who gets commission + at what rate | **The commission map** (server-side, surfaced with the seeded QBO payments) | Business policy — configured at setup, not entered per run |
| (b) How to pay each payee (rail + recipient) | **Saved payees** (ACH/Wire, paid by name) + a **verified stablecoin recipient** | The pay step passes the payee's name (`recipientId`) and the bank resolves the bank details |
| (c) Pay once and only once | **Bank-side marker** (`COMM-{qboPaymentId}` in each disbursement's description) | The dedupe signal — the read-only demo books never record a run |

Commission config is **not** stored as JSON in QBO notes and **not** on the QBO vendor record. The commission map is the source of truth for (a); the Paywhere recipient store holds (b). QBO records the *payments received* (what we commission on); outside a demo it would also record the *commission expense* (Bill + Bill Payment) — on the read-only demo connector that booking is narrated, not written.

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

- **ACH / Wire** — the payee is a **saved payee** at the bank. The pay step passes the payee's **name** (`recipientId`) + amount; the bank resolves it to the saved payee's bank/wire details. No raw ABA/account/routing handling in this skill.
- **Stablecoin** — the payee's wallet is **pre-registered and VERIFIED** in Paywhere via `create_stablecoin_recipient`; check status with `get_stablecoin_recipient` before paying. The pay step uses `{walletAddress, currency: "USD", accountNumber, amount}` — stablecoin has no pay-by-name form.

**Graceful fallback:** if a real payee has no saved payee (not yet onboarded), fall back to an inline recipient block on the payment item rather than erroring (see "Tool signatures"). The demo payees are all saved at setup.

## Dedupe — pay once and only once

Checked **before** paying. The marker positive ⇒ report "already paid" with the prior bank reference; never pay it again without the owner's explicit go-ahead:

- **Bank-side marker** — every ACH/wire disbursement carries `Commission COMM-{qboPaymentId}` as its `paymentName` / wire `description`, so `query_transactions {direction: "debit", descriptionContains: "COMM-{qboPaymentId}"}` (with `dateFrom` wide enough to cover prior runs) finds it; confirm on amount. Stablecoin disbursements carry no description — match those by amount + date + type.
- The read-only demo books never record a run, so there are **no** `COMM-` marker Bills in QBO to search for — the bank is the only dedupe signal.

`COMM-{qboPaymentId}` keys on the QBO Payment being commissioned (the natural unique key). Outside a demo the same marker would also be written to QBO as a Bill (`DocNumber: COMM-{qboPaymentId}`, `PrivateNote: Commission on QBO payment {id} for {customer} @ {rate} — Paywhere {rail} ref {paywherePaymentId}`) — that write is narrated on the demo connector.

## Real MCP tool signatures (Paywhere)

Match these exactly — the register columns above map onto them.

**`make_batch_payment`** — the execution call: **one call per run**, mixed rails. `payments: []` of 1–50 items, each discriminated by `rail`. **Pay by the payee's name** (`recipientId`) for ACH/Wire; the inline forms are the graceful fallback when a payee has no saved payee:

- `{rail: "ach", fromAccountNumber, recipientId: <payee name>, paymentAmount, paymentName}` — **preferred**; the bank resolves the name to the saved payee. Batch ACH items are made **and authorized** automatically (no separate `authorize_ach_payment`). **Fallback**: `{rail: "ach", fromAccountNumber, recipient: {name, aba, accountNumber, accountType, emailAddress}, paymentAmount, paymentName}`.
- `{rail: "wire", fromAccountNumber, recipientId: <payee name>, amount, purposeOfWire?, description?, autoApprove? (default true)}` — **preferred**; set `description` to `Commission COMM-{qboPaymentId}` (the dedupe marker). **Fallback**: `{rail: "wire", fromAccountNumber, amount, recipient: {name, accountNumber, address1, city, state, postalCode}, recipientBank: {name, **aba**}, purposeOfWire?, description?}`. `processDate` is **optional** and defaults to the next business day; set it only to override.
- `{rail: "stablecoin", walletAddress, currency: "USD", accountNumber (the funding account), amount}` — no pay-by-name form.

Options and results:
- `dryRun: true` — validates every item **without moving money**; stablecoin items return the **real 1% fee** preview, other rails report status `validated_not_executed`. Run the dry-run before the confirmation table, the live call after approval.
- `stopOnError?: bool` (default false — continues and reports per item).
- Returns `{summary: {requested, attempted, succeeded, failed, validatedOnly, byRail, totalSucceededAmount}, results: [{index, rail, ok, paymentId?, fee?, status?, error?}], warning}`. `results[index]` maps back to the commission row at the same position in the `payments` array.
- **NOT idempotent**: on partial failure re-submit **only** the failed items in a new call — never the whole array.

**`query_transactions`** — the collection call: `{accountNumbers? (default all accounts), dateFrom?, dateTo? (YYYY-MM-DD, inclusive), direction: "credit", status?: ["posted"], amountMin?/amountMax?, descriptionContains?, sort?, limit? (1–500), includeTransactions: true}` → `{accountsQueried, scanned, matched, returned, truncated, transactions}`. Credits = money in. `truncated: true` ⇒ the scan hit caps — narrow the date range and re-query.

**Single-payment fallbacks** — for one-off corrections (e.g. re-paying a single failed item by hand); the run itself uses the batch call:

- **`make_ach_payment`** — required: `fromAccountNumber`, `paymentAmount`, `paymentName`, and either `recipientId` (the payee's name) **or** the inline `recipient` `{name, aba, accountNumber, accountType: "Checking"|"Savings", emailAddress}`. `paymentDate` (YYYY-MM-DD) is optional. Returns `paymentId` **drafted** — unlike batch ACH it needs `authorize_ach_payment` to move. Status: `get_ach_payment_status`.
- **`make_wire_payment`** — required: `fromAccountNumber`, `amount`, and either `recipientId` (the payee's name) **or** the inline `recipient` `{name, accountNumber, address1, city, state, postalCode}` + `recipientBank` `{name, **aba** (NOT routingNumber), address1?, city?, state?, postalCode?}`. `processDate` (YYYY-MM-DD) is **optional** and defaults to the next business day. `autoApprove` defaults true. Returns `paymentId`. Status: `get_wire_payment_status`.
- **`make_stablecoin_payment`** — required: `walletAddress`, `currency` (`"USD"`), `accountNumber`, `amount`. `preview: true` returns the 1% fee estimate without executing (the batch dry-run covers this in the normal flow). Recipient must be VERIFIED. Returns `paymentId`, `fee`, `status`. Status: `get_stablecoin_payment_status`.
- **`create_stablecoin_recipient`** — `wallet` `{address, chain, currency: "USD"}`, `walletOwner` `{type: "Self"|"Individual"|"Business", name, address}`, `description`. Returns verification statuses. **`get_stablecoin_recipient`** `{walletAddress}` fetches current verification status.
- **`get_account_transactions`** — `{accountNumber, fromDate, toDate, pageNumber?, pageSize?}`; credits are positive `amount`. Legacy paging fallback for collection — prefer `query_transactions`.
- **`list_accounts`** — enumerate accounts; resolve the funding account at run time, never hardcode it.

## Real MCP tool signatures (QuickBooks fork)

The shared demo connector is **read-only**: only `get_*` / `search_*` / `read_*` tools are advertised; the create/update/delete tools do not exist there.

- `search_payments` — filter by customer / date; each Payment carries `CustomerRef` DisplayName and amount. The unit we commission on.
- `search_bills` — filters `DocNumber` and `PrivateNote` with `LIKE` (useful reads; not a dedupe source on the demo connector — see "Dedupe" above).

Outside a demo, the narrated booking would use `create-bill` (the fork's hyphen anomaly on bill/vendor CRUD) + `create_bill_payment` to put the commission expense against the payee vendor. The vendor record carries **no** payment details — ABA/account/wallet live only in the Paywhere recipient store (the demo world's payees are seeded by `/demo-setup` — see [../../DATASET.md](../../DATASET.md)).
