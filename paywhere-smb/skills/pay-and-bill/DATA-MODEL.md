# Pay-and-bill data model

Three concerns, three homes — all in QuickBooks + Paywhere, no local files:

| Concern | Home | Why |
|---|---|---|
| (a) Who works where, at what rates, paid by which rail | **QBO worker vendors** | The vendor record carries the worker's client, BillRate, PayRate, rail, and recipientRef |
| (b) How many hours were actually worked | **QBO time-activities** | Evidence in the books. Hours are read, never invented |
| (c) Bill and pay once and only once | **QBO marker DocNumbers** (`PWD-PB-…`) | The system-of-record dedupe signal |

QuickBooks records the *client invoices* (revenue) and the *worker cost* (a
Bill + Bill Payment per worker per period). Paywhere is the bank that actually
pays the workers; each worker is **pre-configured as a recipient** at setup, so
the pay step passes a `recipientRef` + amount.

## The worker roster — QBO worker vendors

Each placed contractor is a QBO **vendor**. Read them with `search_vendors`.
The vendor record carries the policy fields the pay/bill math needs; a blank
required field ⇒ flag the worker and exclude — never guess.

| Field | Meaning / use |
|---|---|
| `DisplayName` | The worker's name — the time-activity join key and the bill vendor |
| Placed `Client` | The QBO customer DisplayName the hours are invoiced to |
| `BillRate` | $/hour billed to the client |
| `PayRate` | $/hour paid to the worker |
| `Rail` | `ACH` / `Wire` / `Stablecoin` — the `make_batch_payment` item discriminator |
| `recipientRef` | `ach:<slug>` / `wire:<slug>` — the pre-configured recipient the server pays (ACH/Wire workers) |
| `WalletAddress` | Stablecoin workers only — the wallet to pay and the key for `get_stablecoin_recipient` |

**recipientRef vs inline:** for ACH/Wire workers the pay step passes only
`recipientRef` + amount and the server fills the bank/wire details. If a worker
has **no** pre-configured recipient (a real worker not yet onboarded), fall
back to the inline recipient block from their vendor record rather than
erroring (see "Tool signatures"). Stablecoin is never a recipientRef rail — it
always uses the stablecoin payment flow.

The demo world's concrete worker roster, rates, rails, and recipientRefs are
documented in [../../DATASET.md](../../DATASET.md) (seeded by `/demo-setup`).

## Hours — QBO time-activities

A **period** is a Mon–Sun week; its key is the **ISO date of its Monday**
(e.g. week Mon 2026-06-01 – Sun 2026-06-07 ⇒ period `2026-06-01`).

Last period's hours live in QuickBooks as **time-activities**. Read them with
`search_time_activities`, filtered to the time-activity date falling in the
Mon–Sun window. Each time-activity ties a worker (vendor) to a client
(customer), an hours figure, and the hourly rate. Sum hours per worker for the
period. A roster worker with **no** time-activity for the period is flagged and
excluded; hours are never invented.

## The math

- **Invoice (per client):** one invoice per client per period; one line per
  assigned worker — Qty = hours, Rate = `BillRate`, line amount =
  hours × BillRate. Use the QBO service items already on the books (e.g. the
  demo world uses `Consulting Hours – Senior` and `Contract Staffing Hours` —
  see [../../DATASET.md](../../DATASET.md)).
- **Worker pay:** gross = hours × `PayRate`. Stablecoin adds a 1% rail fee on
  top (previewed via `make_batch_payment` `dryRun`).
- **Margin identity:** BillRate = 1.3 × PayRate (rounded to whole dollars). So
  for any hours mix, **invoiced total ≈ 1.3 × pay total**: a ~23.1% gross
  margin on revenue (a 30% markup on pay). Report it in the reconcile summary;
  a material deviation means an hours or rate mismatch worth investigating.

  **Example only** (the demo world's last-week hours — use the live numbers):
  Priya 40h @ $40 pay = $1,600 / @ $52 bill = $2,080; Marcus 36h @ $30 =
  $1,080 / @ $39 = $1,404; Elena 40h @ $60 = $2,400 / @ $78 = $3,120 (wire);
  Devon 32h @ $50 = $1,600 / @ $65 = $2,080 (stablecoin).

## Dedupe markers

| Marker | Format | One per |
|---|---|---|
| Invoice | `PWD-PB-INV-{period}-{client-slug}` | client × period |
| Worker bill | `PWD-PB-BILL-{period}-{worker-slug}` | worker × period |

`{period}` = the ISO date of the period's Monday. Slugs are the lowercase
first name token of the DisplayName (extend with the next token on
collision):

| Entity | Slug | | Entity | Slug |
|---|---|---|---|---|
| Thames Fintech Ltd | `thames` | | Priya Raman | `priya` |
| Zurich Dynamics AG | `zurich` | | Marcus Webb | `marcus` |
| Alderbrook Ventures LLC | `alderbrook` | | Elena Sorokina | `elena` |
| Mitsui Digital KK | `mitsui` | | Devon Okafor | `devon` |

Before creating anything, search `search_invoices` for DocNumber
`PWD-PB-INV-{period}-%` and `search_bills` for `PWD-PB-BILL-{period}-%` —
both filters match `DocNumber` **and** `PrivateNote` with `LIKE`. Always
write the full marker string at the **start of `PrivateNote`** as well: QBO
sandboxes without custom transaction numbers may silently replace a custom
DocNumber (verify on the first write — see SKILL.md), in which case dedupe
rides the PrivateNote.

- Invoice `PrivateNote`: `PWD-PB-INV-{period}-{client-slug} — hours {PeriodStart}–{PeriodEnd}: {worker} {hours}h @ ${BillRate}` (one clause per worker line).
- Bill `PrivateNote`: `PWD-PB-BILL-{period}-{worker-slug} — {worker}, week of {period}, {hours}h @ ${PayRate} = ${gross}; Paywhere {rail} ref {paymentId}`.

The bank-side trace uses the same string: ACH `paymentName` and wire
`description` are set to the bill marker, so `query_transactions` with
`descriptionContains: "PWD-PB"` finds them at reconcile time. Stablecoin
items carry no description — match those by amount + date + type.

## Tool signatures (verbatim)

### QuickBooks fork — note the hyphen anomaly on bill/vendor CRUD

- `search_invoices` / `create_invoice` — search filters `DocNumber` and
  `PrivateNote` with `LIKE`; create accepts `DocNumber` + `PrivateNote`.
- `search_bills` / **`create-bill`** (HYPHEN) — same LIKE filters; create
  accepts `DocNumber` + `PrivateNote`. Book against the worker's vendor.
- `create_bill_payment` — pays the marker bill from the QBO bank account
  representing Operating Checking.
- `search_customers` / `create_customer` — clients, matched by DisplayName.
- `search_vendors` / **`create-vendor`** (HYPHEN) — workers as vendors,
  matched by DisplayName. Master data is never deleted.

### Paywhere — `make_batch_payment` (one call pays all workers, mixed rails)

`payments: []` of 1–50 items, each discriminated by `rail`:

- `{rail: "ach", fromAccountNumber, recipientRef, paymentAmount, paymentName}` — **preferred**: the worker is pre-configured, the server fills the recipient. Made AND authorized automatically. **Fallback** (no pre-configured recipient): `{rail: "ach", fromAccountNumber, recipientIdType: "Inline", recipient {name, aba, accountNumber, accountType, emailAddress}, paymentAmount, paymentName}`.
- `{rail: "wire", fromAccountNumber, recipientRef, amount, description?}` — **preferred**. **Fallback**: `{rail: "wire", fromAccountNumber, amount, recipient {name, accountNumber, address1, city, state, postalCode}, recipientBank {name, aba}, purposeOfWire?, description?}` — `recipientBank.aba`, never `routingNumber`. `processDate` is **optional** and defaults to the next business day server-side; set it only to override.
- `{rail: "stablecoin", walletAddress, currency: "USD", accountNumber, amount}` — recipient must be VERIFIED first (`get_stablecoin_recipient {walletAddress}`). Stablecoin has no recipientRef form.

Options: `dryRun: true` validates without moving money — stablecoin items
return the **real 1% fee**, other rails report `validated_not_executed`;
`stopOnError` (default false — continues and reports per item). Returns
`{summary: {requested, attempted, succeeded, failed, validatedOnly, byRail,
totalSucceededAmount}, results: [{index, rail, ok, paymentId?, fee?, status?,
error?}], warning}`.

**NOT idempotent.** On partial failure, re-submit **only the failed items** —
re-submitting the whole batch double-pays everyone who succeeded.

Related: `list_accounts` (discover the source account — never hardcode
account numbers), `get_stablecoin_recipient` / `create_stablecoin_recipient`
(verification), `get_ach_payment_status` / `get_wire_payment_status` /
`get_stablecoin_payment_status` (per-payment polling if needed).

### Paywhere — `query_transactions` (reconcile)

Args used here: `{direction: "debit", dateFrom, dateTo (YYYY-MM-DD,
inclusive), descriptionContains?, types?, status?, amountMin?, amountMax?,
limit?, aggregate?}`. Returns `{accountsQueried, scanned, matched, returned,
truncated, transactions?, aggregate?}`; `truncated: true` ⇒ narrow the date
range.

### QuickBooks — time-activities (the hours) and vendors (the roster)

- `search_time_activities` — returns each time-activity's vendor (worker),
  customer (client), hours, hourly rate, and date. Filter to the period's
  Mon–Sun window and sum hours per worker. This is the only source of hours.
- `search_vendors` — the worker roster: DisplayName, placed client, BillRate,
  PayRate, rail, and recipientRef (per "The worker roster" above).
