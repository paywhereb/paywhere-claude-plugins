---
name: pay-and-bill
version: 0.1.0
description: >
  Runs the hours-to-cash cycle for a staffing firm: collects worker hour
  reports for a period (Gmail for real data, Drive notes in the demo),
  aggregates per worker and per client, invoices each client for the hours in
  QuickBooks, pays each worker over their Paywhere rail (ACH / Wire /
  Stablecoin) in one batch, books a Bill + Bill Payment per worker, and
  reconciles against the bank. Reads a local workers-register.xlsx (who works
  where, rates, rails) as the source of truth and dedupes with PWD-PB markers
  so re-runs are safe. Use when the owner says "bill clients for hours,"
  "invoice the hours," "pay my contractors," "pay the workers," or "run the
  pay-and-bill cycle."
---

# Pay and Bill

## Quick start

```
User: "run the pay-and-bill cycle"
→ Open workers-register.xlsx (Workers + PaidLog sheets, local Excel)
→ Determine the period (default: the last complete Mon–Sun week)
→ Collect hour reports: Gmail first (real path), Drive notes as the demo fallback
→ Aggregate: per-worker hours; per-client hours × BillRate — show the math
→ Dedupe: search_invoices / search_bills for PWD-PB-…-{period}-% markers
→ GATE 1: invoice table → approval → create_invoice per client
→ GATE 2: pay table (incl. stablecoin fee from dryRun) → approval
→ ONE make_batch_payment (mixed rails) → per-item results
→ Record: create-bill + create_bill_payment per worker; append PaidLog rows
→ Reconcile: query_transactions (debits) + margin summary (≈ 1.3×)
```

Money moves on three rails and is recorded in two systems plus a local
workbook. Get the data model right before running — read
[DATA-MODEL.md](DATA-MODEL.md).

## What is the source of truth

- **`workers-register.xlsx`** (a LOCAL Excel file in the working folder — not
  a Google Sheet) decides *who* works at *which client*, the *BillRate*
  invoiced, the *PayRate* paid, and the *rail + payment details*. A worker
  not in the `Workers` sheet cannot be invoiced or paid — flag and exclude.
- **Hour reports** (Gmail threads, or Drive notes in the demo) are the only
  evidence of hours. Hours are never invented and never assumed.
- **QuickBooks** is the system of record: the client invoice is the revenue,
  the worker Bill + Bill Payment is the cost.
- **Paywhere** is the bank: it disburses worker pay and proves it posted.

## Setup (first run only)

If `workers-register.xlsx` doesn't exist, don't improvise it — either help
the owner create one with their real workers/rates/rails (schema in
[DATA-MODEL.md](DATA-MODEL.md)), or run `/demo-setup-pay-and-bill` to
scaffold the demo register and seed last week's hour notes. Resume
`pay-and-bill` once the register exists.

## Workflow

### 1. Open the register

Locate `workers-register.xlsx` in the session working folder; read both
sheets with Python (`openpyxl`). Missing → Setup above. Multiple candidates →
list them and ask. Build lookups: `Workers` keyed by Worker name; `PaidLog`
as a set of `(PeriodStart, Worker)` already paid.

### 2. Determine the period

Default: **the last complete week** — the Mon–Sun block ending on the most
recent Sunday on or before today (compute from today's actual date; never
reuse a date from a prior session). Accept an explicit period argument ("week
of June 1", "May 18–24") and normalize it to a Monday-start week. The
**period key** is the ISO date of the Monday — it appears in every marker.

### 3. Collect hour reports

- **Gmail first — the real path.** `search_threads` for the subject
  convention `Hours - {Worker} - Week of {period}` (per
  [DATA-MODEL.md](DATA-MODEL.md)); `get_thread` to read each report.
- **Drive fallback — the demo path.** If Gmail has no reports (or no Gmail
  connector), `search_files` for notes named with the same convention
  (seeded per
  [../demo-setup-pay-and-bill/seed/workers.md](../demo-setup-pay-and-bill/seed/workers.md));
  `read_file_content` to read them.

Parse day lines and the `Total:` line; if they disagree, ask the owner.
**State explicitly which path supplied each worker's hours.** A register
worker with no report → flag, exclude from both invoicing and pay, and say
so. Never invent hours.

### 4. Aggregate — show the math

- Per worker: total hours for the period.
- Per client (via the register's `Client` assignment): one invoice line per
  worker — hours × BillRate — and the invoice total.
- Per worker pay: hours × PayRate.

Show the arithmetic line by line (e.g. `40h × $130 = $5,200`), plus the
grand totals and the expected ≈1.3 invoiced-to-pay ratio
([DATA-MODEL.md](DATA-MODEL.md), "The math").

### 5. Dedupe — before anything is written

`search_invoices` for DocNumber `PWD-PB-INV-{period}-%` and `search_bills`
for `PWD-PB-BILL-{period}-%` (both filter DocNumber and PrivateNote with
`LIKE`). Cross-check `PaidLog` for `(PeriodStart, Worker)` rows. Anything
already marked → an "already processed" row, excluded from its gate. A
partial prior run (say, invoices created but workers unpaid) leaves only the
missing halves in play — that is the point of two marker families.

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
false`), items built from the register per [DATA-MODEL.md](DATA-MODEL.md):
ACH with `recipientIdType: "Inline"` and the full recipient block; wire with
`recipient` + `recipientBank {name, aba}`; stablecoin with `{walletAddress,
currency: "USD", accountNumber, amount}`. ACH `paymentName` / wire
`description` = the worker's bill marker (reconcile trace);
`paymentDate`/`processDate` = today.

Report per-item results from `results[]`. **The tool is not idempotent**: on
partial failure, fix and re-submit **only the failed items** — never the
whole batch.

### 8. Record — QBO markers and PaidLog

For every worker whose payment succeeded, **write the markers immediately**:

1. **`create-bill`** (note the hyphen) against the worker's vendor: DocNumber
   `PWD-PB-BILL-{period}-{worker-slug}`, TxnDate today, amount = gross,
   `PrivateNote` = the marker + worker, period, hours, and the Paywhere
   `paymentId` (format in [DATA-MODEL.md](DATA-MODEL.md)).
2. `create_bill_payment` for the bill, same amount.
3. Append the `PaidLog` row to the xlsx: `PeriodStart | PeriodEnd | Worker |
   Hours | PayRate | GrossPay | Rail | PaywherePaymentId | QBOBillId |
   QBOInvoiceIds`.

**Marker-first discipline:** if the bank payment succeeded but a QBO write
fails, the money already moved — append the `PaidLog` row immediately, retry
the QBO marker, and report the partial state explicitly so next run's dedupe
still catches it. Never call the run clean until each paid worker has a
marker in at least one system (PaidLog at minimum).

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
bills + bill payments (ids), PaidLog rows appended, and the margin line.

## Graceful degradation — say what's skipped, never half-work silently

- **No Paywhere**: run steps 1–6 only — invoices still go out — then produce
  the **drafted payment list** (worker, gross, rail, full payment fields)
  without executing anything. No bank batch, no bills, no PaidLog rows; tell
  the owner exactly that.
- **No Gmail AND no Drive**: ask the owner to paste each worker's hours
  inline, **echo the parsed hours back and get an explicit confirmation**
  before using them.
- **No QuickBooks**: **stop** — QBO is the system of record; invoicing and
  cost booking cannot be skipped or faked.

## Edge cases — spell these out, don't guess

- **Gmail and Drive disagree for the same worker**: prefer Gmail (the real
  path), but surface both numbers and the delta to the owner before the gate.
- **Hours but no register row**: flag and exclude — there is no rate or rail
  to price either side with. Offer to add the worker to the register first.
- **Register worker with no report**: flag and exclude; never invent hours.
- **Partial-week hours** (e.g. a day off): perfectly normal — invoice and pay
  the actual hours; note it in the tables.
- **A client invoice for the period already exists *without* our marker**:
  the owner may have invoiced manually — show it and **ask**; never assume
  it covers (or doesn't cover) these hours.
- **Report total ≠ sum of day lines**: ask the owner which is right.
- **Unverified stablecoin recipient**: exclude that worker from the batch and
  point at `/demo-setup-pay-and-bill` (demo) or
  `create_stablecoin_recipient` + verification (real); never pay an
  unverified wallet.
- **Batch partial failure**: re-submit only the failed `results[]` items —
  `make_batch_payment` is not idempotent.
- **Bank success, QBO failure**: marker-first discipline (step 8) — PaidLog
  now, retry the marker, report partial state.
- **DocNumber not persisted** (sandbox without custom transaction numbers):
  detected on the first invoice read-back; dedupe rides the PrivateNote
  marker instead.

## Approval gates

- **Gate 1 (step 6)** covers QBO invoice creation; **Gate 2 (step 7)** covers
  the bank batch and its matching bills/bill payments/PaidLog rows. Nothing
  is written or paid before its gate.
- One approval covers one batch; adding or changing a row after approval
  restarts that gate.
- Anything that fails dedupe is shown as "already processed", never re-done.
- Never invent payment details or hours — missing/malformed data is flagged
  and excluded, not guessed.

## Reference

- [DATA-MODEL.md](DATA-MODEL.md) — register schema, hour-report conventions,
  the invoice/pay/margin math, PWD-PB marker formats, and the verbatim MCP
  tool signatures.
- [../demo-setup-pay-and-bill/seed/workers.md](../demo-setup-pay-and-bill/seed/workers.md)
  — the demo register rows and hour-note templates this skill consumes in
  demo mode.
