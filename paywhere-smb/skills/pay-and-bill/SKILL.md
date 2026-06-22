---
name: pay-and-bill
version: 0.1.0
description: >
  Runs the hours-to-cash cycle for a staffing firm: reads last period's worker
  hours from QuickBooks time-activities, aggregates per worker and per client,
  invoices each client for the hours in QuickBooks, pays each worker over their
  Paywhere rail (ACH / Wire / Stablecoin) in one batch, books a Bill + Bill
  Payment per worker, and reconciles against the bank. Worker rates and rails
  come from the QuickBooks vendor records; recipients are pre-configured at
  setup so a pay step passes a recipientRef + amount. Dedupes with PWD-PB
  markers so re-runs are safe. Use when the owner says "bill clients for hours,"
  "invoice the hours," "pay my contractors," "pay the workers," or "run the
  pay-and-bill cycle."
---

# Pay and Bill

## Quick start

```
User: "run the pay-and-bill cycle"
→ Determine the period (default: the last complete Mon–Sun week)
→ Read last week's hours from QBO time-activities (search_time_activities)
→ Read worker rates + rails from the QBO worker vendors
→ Aggregate: per-worker hours; per-client hours × BillRate — show the math
→ Dedupe: search_invoices / search_bills for PWD-PB-…-{period}-% markers
→ GATE 1: invoice table → approval → create_invoice per client
→ GATE 2: pay table (incl. stablecoin fee from dryRun) → approval
→ ONE make_batch_payment (mixed rails, recipientRef per worker) → per-item results
→ Record: create-bill + create_bill_payment per worker
→ Reconcile: query_transactions (debits) + margin summary (≈ 1.3×)
```

Money moves on three rails and is recorded in two systems. Get the data model
right before running — read [DATA-MODEL.md](DATA-MODEL.md).

## What is the source of truth

- **QuickBooks** is the system of record:
  - **Worker vendors** carry *who* the workers are, the *PayRate* paid and the
    *BillRate* invoiced, the client each is placed at, and the *rail* (ACH /
    Wire / Stablecoin). A worker with no vendor record cannot be invoiced or
    paid — flag and exclude.
  - **Time-activities** carry *how many hours* each worker actually worked the
    period. Hours are read from the books, never invented and never assumed.
  - The client invoice is the revenue; the worker Bill + Bill Payment is the
    cost.
- **Paywhere** is the bank: it disburses worker pay and proves it posted. Each
  worker is **pre-configured as a recipient** at setup, so a pay step passes a
  `recipientRef` + amount — the server fills in the bank/wire details.

## Setup (first run only)

This skill reads what is already in QuickBooks and Paywhere — it does not stand
up its own data. If the QBO worker vendors or last period's time-activities are
missing, help the owner enter them (or, for the demo world, the persona,
vendors, time-activities, and pre-configured recipients are seeded by
`/demo-setup` — see [../../DATASET.md](../../DATASET.md)). Resume `pay-and-bill`
once the vendors and time-activities exist.

## Workflow

### 1. Determine the period

Default: **the last complete week** — the Mon–Sun block ending on the most
recent Sunday on or before today (compute from today's actual date; never
reuse a date from a prior session). Accept an explicit period argument ("week
of June 1", "May 18–24") and normalize it to a Monday-start week. The
**period key** is the ISO date of the Monday — it appears in every marker.

### 2. Read the worker roster from QBO

`search_vendors` for the worker vendors. Each carries the worker's name (the
hour-report join key and the bill vendor), the placed client, the `BillRate`
and `PayRate`, and the `rail` + `recipientRef` (per [DATA-MODEL.md](DATA-MODEL.md)).
A worker missing a rate or a recipientRef → flag and exclude; never guess.

### 3. Read the hours from QBO time-activities

`search_time_activities` for the period (filter by the time-activity date
falling in the Mon–Sun window). Each time-activity ties a worker (vendor) to a
client (customer), an hours figure, and the hourly rate. Sum hours per worker
for the period. A roster worker with **no** time-activity for the period →
flag, exclude from both invoicing and pay, and say so. Never invent hours.

### 4. Aggregate — show the math

- Per worker: total hours for the period (from the time-activities).
- Per client (via the worker's placed-client assignment): one invoice line per
  worker — hours × BillRate — and the invoice total.
- Per worker pay: hours × PayRate.

Show the arithmetic line by line (e.g. `40h × $52 = $2,080`, **example
only — use the live rates**), plus the grand totals and the expected ≈1.3
invoiced-to-pay ratio ([DATA-MODEL.md](DATA-MODEL.md), "The math").

### 5. Dedupe — before anything is written

`search_invoices` for DocNumber `PWD-PB-INV-{period}-%` and `search_bills`
for `PWD-PB-BILL-{period}-%` (both filter DocNumber and PrivateNote with
`LIKE`). Anything already marked → an "already processed" row, excluded from
its gate. A partial prior run (say, invoices created but workers unpaid)
leaves only the missing halves in play — that is the point of two marker
families.

### 6. GATE 1 — invoice the clients

Present the invoice table and **wait for explicit approval**:

| Client | Worker(s) | Hours | Bill rate | Invoice total | Status |
|---|---|---|---|---|---|

Also show: already-invoiced rows (with the existing DocNumber) and excluded
workers. On approval, `create_invoice` per client: DocNumber
`PWD-PB-INV-{period}-{client-slug}`, TxnDate today, DueDate per the owner's
terms (default net-15 — confirm in the table), one line per worker (Qty =
hours, Rate = BillRate, items per [DATA-MODEL.md](DATA-MODEL.md)), and the
marker at the start of `PrivateNote`. After the **first** invoice, read it
back: if the sandbox didn't persist the custom DocNumber, say so and rely on
the PrivateNote marker for dedupe from here on.

### 7. GATE 2 — pay the workers

Before the gate:
- `list_accounts` → pay from the primary Operating account (confirm in the
  table if more than one candidate). Never hardcode account numbers.
- For each stablecoin worker, `get_stablecoin_recipient {walletAddress}` —
  must be **VERIFIED**, else flag and exclude that worker from the batch.
- `make_batch_payment` with `dryRun: true` for the full batch — validates
  every item and returns the **real 1% stablecoin fee** for the table.

Present and **wait for explicit approval** (the approval covers the bank
batch *and* the step-8 QBO bookkeeping for those payments):

| Worker | Hours | Pay rate | Gross | Rail | Fee | Status |
|---|---|---|---|---|---|---|

On approval, **ONE** `make_batch_payment` (`dryRun: false`, `stopOnError:
false`), items built per [DATA-MODEL.md](DATA-MODEL.md). **Prefer
`recipientRef`** for ACH and wire workers — pass `{rail, fromAccountNumber,
recipientRef, amount, …}` and the server fills the bank/wire details (workers
are pre-configured as recipients at setup). **Degrade gracefully:** if a
worker has no pre-configured recipient (a real worker not yet onboarded), fall
back to the inline recipient block from their vendor record — ACH with the full
`recipient` block, wire with `recipient` + `recipientBank {name, aba}` — rather
than erroring. Stablecoin always uses the stablecoin flow `{walletAddress,
currency: "USD", accountNumber, amount}` (recipientRef is ACH/Wire only). ACH
`paymentName` / wire `description` = the worker's bill marker (reconcile trace);
`paymentDate`/`processDate` is **optional and defaults to the next business
day** server-side — set it only to override that default.

Report per-item results from `results[]`. **The tool is not idempotent**: on
partial failure, fix and re-submit **only the failed items** — never the
whole batch.

### 8. Record — QBO markers

For every worker whose payment succeeded, **write the markers immediately**:

1. **`create-bill`** (note the hyphen) against the worker's vendor: DocNumber
   `PWD-PB-BILL-{period}-{worker-slug}`, TxnDate today, amount = gross,
   `PrivateNote` = the marker + worker, period, hours, and the Paywhere
   `paymentId` (format in [DATA-MODEL.md](DATA-MODEL.md)).
2. `create_bill_payment` for the bill, same amount.

**Marker-first discipline:** if the bank payment succeeded but a QBO write
fails, the money already moved — retry the QBO marker and report the partial
state explicitly (worker, gross, Paywhere `paymentId`) so next run's dedupe
still catches it. Never call the run clean until each paid worker has its bill
marker in QBO.

### 9. Reconcile and summarize

- `query_transactions {direction: "debit", dateFrom: <period Monday>,
  dateTo: <today>}` — match each worker payment: ACH/wire by the `PWD-PB`
  marker in the description (`descriptionContains: "PWD-PB"`), stablecoin by
  amount + date + type. Note anything still pending vs posted.
- **Margin summary**: invoiced total vs worker pay total vs the ratio —
  should sit at ≈1.3 (persona rates are exactly 1.3×); flag a material
  deviation.
- Collection of the new invoices is **not** this skill's job: the cash is
  chased later via `/invoice-chase` and shows up in `/plan-payroll` — say so
  in the close-out.

End with: invoices created (DocNumber + id), payments (rail + Paywhere id),
bills + bill payments (ids), and the margin line.

## Graceful degradation — say what's skipped, never half-work silently

- **No Paywhere**: run steps 1–6 only — invoices still go out — then produce
  the **drafted payment list** (worker, gross, rail, recipientRef or payment
  fields) without executing anything. No bank batch, no bills; tell the owner
  exactly that.
- **No QuickBooks**: **stop** — QBO is the system of record for both the
  worker roster/rates and the time-activities (the hours). Without it there is
  no source of truth; invoicing and cost booking cannot be skipped or faked.
- **A worker with no pre-configured recipient**: don't error — fall back to the
  inline recipient details on their vendor record (step 7). If those are also
  missing, flag and exclude that worker.

## Edge cases — spell these out, don't guess

- **Time-activity total looks off** (e.g. duplicate entries for the same
  worker/day, or hours far outside the normal range): surface the rows and the
  delta to the owner before the gate; never silently pick one.
- **Hours but no vendor record**: flag and exclude — there is no rate or rail
  to price either side with. Offer to add the worker vendor first.
- **Worker vendor with no time-activity for the period**: flag and exclude;
  never invent hours.
- **Partial-week hours** (e.g. a day off): perfectly normal — invoice and pay
  the actual hours; note it in the tables.
- **A client invoice for the period already exists *without* our marker**:
  the owner may have invoiced manually — show it and **ask**; never assume
  it covers (or doesn't cover) these hours.
- **Report total ≠ sum of day lines**: ask the owner which is right.
- **Unverified stablecoin recipient**: exclude that worker from the batch and
  fix it with `create_stablecoin_recipient` + verification (the demo world
  seeds this — see [../../DATASET.md](../../DATASET.md)); never pay an
  unverified wallet.
- **Batch partial failure**: re-submit only the failed `results[]` items —
  `make_batch_payment` is not idempotent.
- **Bank success, QBO failure**: marker-first discipline (step 8) — retry the
  marker, report partial state.
- **DocNumber not persisted** (sandbox without custom transaction numbers):
  detected on the first invoice read-back; dedupe rides the PrivateNote
  marker instead.

## Approval gates

- **Gate 1 (step 6)** covers QBO invoice creation; **Gate 2 (step 7)** covers
  the bank batch and its matching bills/bill payments. Nothing is written or
  paid before its gate.
- One approval covers one batch; adding or changing a row after approval
  restarts that gate.
- Anything that fails dedupe is shown as "already processed", never re-done.
- Never invent payment details or hours — missing/malformed data is flagged
  and excluded, not guessed.

## Reference

- [DATA-MODEL.md](DATA-MODEL.md) — the QBO worker-vendor and time-activity
  shapes, the invoice/pay/margin math, PWD-PB marker formats, and the verbatim
  MCP tool signatures.
- [../../DATASET.md](../../DATASET.md) — the demo world's persona, worker
  roster, weekly hours, and pre-configured recipients (seeded by `/demo-setup`).
