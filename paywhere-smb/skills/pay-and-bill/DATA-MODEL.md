# Pay-and-bill data model

Three concerns, three homes:

| Concern | Home | Why |
|---|---|---|
| (a) Who works where, at what rates, paid by which rail | **`workers-register.xlsx`** `Workers` sheet | Business policy — owner-editable, not a QBO concept |
| (b) How many hours were actually worked | **Hour reports** — Gmail threads (real path) or Drive notes (demo path) | Evidence. Hours are read, never invented, and never cached in the register |
| (c) Bill and pay once and only once | **QBO marker DocNumbers** + register `PaidLog` | Two independent dedupe signals; QBO is the system of record |

QuickBooks records the *client invoices* (revenue) and the *worker cost* (a
Bill + Bill Payment per worker per period). Paywhere is the bank that actually
pays the workers. The register holds policy and rail details only.

## The workers register — a LOCAL Excel workbook

`workers-register.xlsx` is a **local Excel file in the session working
folder** — read and written with Bash + Python (`openpyxl`), **not** a Google
Sheet. Locate it by filename in the working directory; if it is missing or
more than one candidate exists, ask the owner (see SKILL.md Setup). Two
sheets: `Workers` and `PaidLog`.

### Sheet `Workers` — (a) one wide row per worker

**Schema decision — wide columns, not separate rail sheets:** pay-commissions
uses rail tabs because many customers share one payee; here each worker is
exactly one payee on exactly one rail, so a join would add sheets without
removing any duplication.

One row per worker. Only the columns for the row's `Rail` are filled; a blank
required cell for that rail ⇒ flag the worker and exclude — never guess.

| Column | Rail | → Paywhere field (`make_batch_payment` item) |
|---|---|---|
| `Worker` | all | `recipient.name` (ach/wire); also the QBO vendor DisplayName and the hour-report join key |
| `Client` | all | — (the QBO customer DisplayName the hours are invoiced to) |
| `BillRate` | all | — ($/hour billed to Client) |
| `PayRate` | all | — ($/hour paid to Worker) |
| `Rail` | all | the item's `rail` discriminator: `ACH` / `Wire` / `Stablecoin` |
| `AchABA` | ACH | `recipient.aba` (9 digits) |
| `AchAccountNumber` | ACH | `recipient.accountNumber` |
| `AchAccountType` | ACH | `recipient.accountType` (`Checking` / `Savings`) |
| `Email` | ACH | `recipient.emailAddress` |
| `WireAccountNumber` | Wire | `recipient.accountNumber` |
| `WireAddr1` / `WireCity` / `WireState` / `WirePostalCode` | Wire | `recipient.address1` / `.city` / `.state` / `.postalCode` |
| `WireBankName` | Wire | `recipientBank.name` |
| `WireBankABA` | Wire | `recipientBank.aba` — **the field is `aba`, NOT `routingNumber`** |
| `WalletAddress` | Stablecoin | `walletAddress`; also the key for `get_stablecoin_recipient` |
| `Chain` | Stablecoin | used at recipient-creation time (e.g. `POLY`) |
| `Currency` | Stablecoin | `currency` — `USD` (the only supported value) |

The demo register's concrete rows mirror
[../demo-setup-pay-and-bill/seed/workers.md](../demo-setup-pay-and-bill/seed/workers.md),
which in turn mirrors
[../demo-setup-base/seed/persona.md](../demo-setup-base/seed/persona.md).

### Sheet `PaidLog` — (c) append-only audit + dedupe

One row per worker per period paid. Never edit or delete prior rows.

`PeriodStart | PeriodEnd | Worker | Hours | PayRate | GrossPay | Rail | PaywherePaymentId | QBOBillId | QBOInvoiceIds`

`PeriodStart`/`PeriodEnd` are the period's Monday/Sunday (ISO).
`QBOInvoiceIds` is the comma-separated id list of the invoice(s) that billed
this worker's hours for the period — normally exactly one.

## Hour reports — where the hours come from

A **period** is a Mon–Sun week; its key is the **ISO date of its Monday**
(e.g. week Mon 2026-06-01 – Sun 2026-06-07 ⇒ period `2026-06-01`).

- **Gmail — the real path.** Workers mail in hours with the subject
  convention **`Hours - {Worker} - Week of {YYYY-MM-DD}`** (the period
  Monday). Find them with `search_threads`, read with `get_thread`.
- **Drive — the demo path.** Gmail here is drafts/labels/search only — there
  is no way to inject inbound demo mail — so the demo seeds hour reports as
  Drive notes named with the **same** convention (filenames and bodies per
  [../demo-setup-pay-and-bill/seed/workers.md](../demo-setup-pay-and-bill/seed/workers.md)).
  Find with `search_files`, read with `read_file_content`.

Report bodies carry one line per weekday (0 for a day off) plus a `Total:` line. If the
total line disagrees with the sum of the day lines, ask the owner — never
silently pick one. Always state which path supplied each worker's hours. A
worker with no report for the period is flagged and excluded; hours are never
invented.

## The math

- **Invoice (per client):** one invoice per client per period; one line per
  assigned worker — Qty = hours, Rate = `BillRate`, line amount =
  hours × BillRate. Use the base seed's service items
  ([../demo-setup-base/seed/qbo-manifest.md](../demo-setup-base/seed/qbo-manifest.md)):
  `Consulting Hours – Senior` (Thames, Zurich) / `Contract Staffing Hours`
  (Alderbrook, Mitsui).
- **Worker pay:** gross = hours × `PayRate`. Stablecoin adds a 1% rail fee on
  top (previewed via `make_batch_payment` `dryRun`).
- **Margin identity:** per persona.md, BillRate = 1.3 × PayRate (rounded to
  whole dollars — exact for all four demo workers). So for any hours mix,
  **invoiced total ≈ 1.3 × pay total**: a ~23.1% gross margin on revenue (a
  30% markup on pay). Report it in the reconcile summary; a material
  deviation means an hours or rate mismatch worth investigating.

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

- `{rail: "ach", fromAccountNumber, recipientIdType: "Inline", recipient {name, aba, accountNumber, accountType, emailAddress}, paymentAmount, paymentDate (YYYY-MM-DD), paymentName}` — made AND authorized automatically. **Always `recipientIdType: "Inline"`** (mock recipients are global/permanent, so DisplayName is ambiguous).
- `{rail: "wire", fromAccountNumber, amount, processDate, recipient {name, accountNumber, address1, city, state, postalCode}, recipientBank {name, aba}, purposeOfWire?, description?}` — `recipientBank.aba`, never `routingNumber`.
- `{rail: "stablecoin", walletAddress, currency: "USD", accountNumber, amount}` — recipient must be VERIFIED first (`get_stablecoin_recipient {walletAddress}`).

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

### Gmail (real-data path) — drafts/labels/search only

`search_threads` (find hour-report mail by subject), `get_thread` (read it).
Gmail **cannot send or inject inbound mail** — which is exactly why the demo
seeds hour reports in Drive instead.

### Google Drive (demo path)

`search_files` (find hour notes by name), `read_file_content` (read them).

### Local workbook mechanics

Read/write `workers-register.xlsx` with Bash + Python (`openpyxl`): load the
workbook, read `Workers` rows into memory, and **append** `PaidLog` rows
(never rewrite existing ones) at record time.
