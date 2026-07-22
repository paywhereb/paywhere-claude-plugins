# Pay-and-bill data model

Three concerns, three homes — all in QuickBooks + Paywhere, no local files:

| Concern | Home | Why |
|---|---|---|
| (a) Who works where, at what rates, paid by which rail | **QBO worker vendors** | The vendor record carries the worker's client, BillRate, PayRate, and rail; the worker's name is the payee name |
| (b) How many hours were actually worked | **QBO time-activities** | Evidence in the books. Hours are read, never invented |
| (c) Bill and pay once and only once | **Bank-side markers** (`PWD-PB-…` in each payment's description) | The dedupe signal — the read-only demo books never record a run |

QuickBooks is **read** for the roster and the hours; the demo connector is
**read-only** (the shared books reseed server-side daily), so the *client
invoices* (revenue) and the *worker cost* (a Bill + Bill Payment per worker
per period) that would be written outside a demo are narrated, not created.
Paywhere is the bank that actually pays the workers; the pay step passes the
worker's **name** (`recipientId`) + amount, and the bank resolves it to the
worker's saved payee.

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
| `DisplayName` (again) | For ACH/Wire workers, the worker's name is the payee name passed as `recipientId` |
| `WalletAddress` | Stablecoin workers only — the wallet to pay and the key for `get_stablecoin_recipient` |

**Pay by name vs inline:** for ACH/Wire workers the pay step passes only the
worker's name (`recipientId`) + amount, and the bank resolves it to the saved
payee. If a worker has **no** saved payee (a real worker not yet onboarded),
fall back to the inline recipient block from their vendor record rather than
erroring (see "Tool signatures"). Stablecoin never uses pay-by-name — it always
uses the stablecoin payment flow.

The demo world's concrete worker roster, rates, and rails are documented in
[../../DATASET.md](../../DATASET.md) (seeded server-side in the shared books;
the matching saved payees ride the caller's bank world via `/demo-setup`).

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

The markers live at the **bank**: ACH `paymentName` and wire `description`
are set to the worker's bill marker when the batch is built, so
`query_transactions` with `descriptionContains: "PWD-PB-BILL-{period}"` finds
every worker a prior run already paid (the dedupe check, before the gates)
and `descriptionContains: "PWD-PB"` finds them again at reconcile time.
Stablecoin items carry no description — match those by amount + date + type.
The read-only demo books never record a run, so QBO carries no marker rows —
don't search it for them.

The invoice marker names the per-client invoice the narration describes;
outside a demo both markers would also be written into QBO (DocNumber +
the start of `PrivateNote`):

- Invoice `PrivateNote`: `PWD-PB-INV-{period}-{client-slug} — hours {PeriodStart}–{PeriodEnd}: {worker} {hours}h @ ${BillRate}` (one clause per worker line).
- Bill `PrivateNote`: `PWD-PB-BILL-{period}-{worker-slug} — {worker}, week of {period}, {hours}h @ ${PayRate} = ${gross}; Paywhere {rail} ref {paymentId}`.

## Tool signatures (verbatim)

### QuickBooks fork — read-only on the demo connector

The shared demo connector advertises **only read tools** (`get_*` /
`search_*` / `read_*`); the create/update/delete tools do not exist there.

- `search_invoices` — filters `DocNumber` and `PrivateNote` with `LIKE`
  (useful for spotting a manually created invoice for the period).
- `search_bills` — same LIKE filters.
- `search_customers` — clients, matched by DisplayName.
- `search_vendors` — workers as vendors, matched by DisplayName.

Outside a demo, the narrated writes would be `create_invoice` (accepts
`DocNumber` + `PrivateNote`), **`create-bill`** (HYPHEN — the fork's naming
anomaly on bill/vendor CRUD) against the worker's vendor, and
`create_bill_payment` from the QBO bank account representing Operating
Checking.

### Paywhere — `make_batch_payment` (one call pays all workers, mixed rails)

`payments: []` of 1–50 items, each discriminated by `rail`:

- `{rail: "ach", fromAccountNumber, recipientId: <worker name>, paymentAmount, paymentName}` — **preferred**: the bank resolves the name to the worker's saved payee. Made AND authorized automatically. **Fallback** (no saved payee): `{rail: "ach", fromAccountNumber, recipient {name, aba, accountNumber, accountType, emailAddress}, paymentAmount, paymentName}`.
- `{rail: "wire", fromAccountNumber, recipientId: <worker name>, amount, description?}` — **preferred**. **Fallback**: `{rail: "wire", fromAccountNumber, amount, recipient {name, accountNumber, address1, city, state, postalCode}, recipientBank {name, aba}, purposeOfWire?, description?}` — `recipientBank.aba`, never `routingNumber`. `processDate` is **optional** and defaults to the next business day; set it only to override.
- `{rail: "stablecoin", walletAddress, currency: "USD", accountNumber, amount}` — recipient must be VERIFIED first (`get_stablecoin_recipient {walletAddress}`). Stablecoin has no pay-by-name form.

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
- `search_vendors` — the worker roster: DisplayName (also the payee name),
  placed client, BillRate, PayRate, and rail (per "The worker roster" above).
