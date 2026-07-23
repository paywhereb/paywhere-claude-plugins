---
name: pay-and-bill
version: 0.3.0
description: >
  Runs the hours-to-cash cycle for a staffing firm: reads last period's worker
  hours from QuickBooks time-activities, aggregates per worker and per client,
  presents the client invoices (narrating the QuickBooks invoicing that would
  happen outside a demo — the demo books are read-only), pays each worker over
  their Paywhere rail (ACH / Wire / Stablecoin) in one batch, narrates the
  Bill + Bill Payment booking per worker, and reconciles against the bank.
  Worker rates and rails come from the QuickBooks vendor records; a pay step
  passes the worker's name (recipientId) + amount and the bank resolves the
  saved payee. Dedupes on the bank side via the PWD-PB markers carried in each
  payment's description, so re-runs are surfaced. Use when the owner says
  "bill clients for hours," "invoice the hours," "pay my contractors," "pay
  the workers," or "run the pay-and-bill cycle."
---

# Pay and Bill

## Quick start

```
User: "run the pay-and-bill cycle"
→ Determine the period (default: the last complete Mon–Sun week)
→ Read last week's hours from QBO time-activities (search_time_activities)
→ Read worker rates + rails from the QBO worker vendors
→ Aggregate: per-worker hours; per-client hours × BillRate — show the math
→ Dedupe: query_transactions for prior debits carrying PWD-PB-…-{period} markers
→ GATE 1: invoice table → approval → narrate the per-client QBO invoicing
  (outside a demo, create_invoice per client — the demo books are read-only)
→ GATE 2: pay table (incl. stablecoin fee from dryRun) → approval
→ ONE make_batch_payment (mixed rails, recipientId=worker name per item) → per-item results
→ Narrate the booking: outside a demo, a Bill + Bill Payment per worker
→ Reconcile: query_transactions (debits) + margin summary (≈ 1.3×)
```

Money moves on three rails and is recorded at the bank; the QuickBooks side
is narrated (the demo books are read-only). Get the data model right before
running — read [DATA-MODEL.md](DATA-MODEL.md).

## What is the source of truth

- **QuickBooks** is the system of record:
  - **Worker vendors** carry *who* the workers are, the *PayRate* paid and the
    *BillRate* invoiced, the client each is placed at, and the *rail* (ACH /
    Wire / Stablecoin). A worker with no vendor record cannot be invoiced or
    paid — flag and exclude.
  - **Time-activities** carry *how many hours* each worker actually worked the
    period. Hours are read from the books, never invented and never assumed.
  - Outside a demo, the client invoice is the revenue record and the worker
    Bill + Bill Payment is the cost record. The **demo connector is
    read-only** (the shared books reseed server-side daily), so this skill
    narrates those writes instead of performing them.
- **Paywhere** is the bank: it disburses worker pay and proves it posted. A pay
  step passes the worker's **name** (`recipientId`) + amount, and the bank
  resolves it to the worker's saved payee (ACH/wire details).

## Setup (first run only)

This skill reads what is already in QuickBooks and Paywhere — it does not stand
up its own data. The demo world's persona, worker vendors, and time-activities
are seeded server-side in the shared books (reseeded daily), and the saved
payees ride the caller's own bank world via `/demo-setup` — see
[../../DATASET.md](../../DATASET.md). On real books, the owner would enter the
vendors and time-activities in QuickBooks first; resume `pay-and-bill` once
they exist.

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Determine the period"),
then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly, so don't skip it
just because the steps are already numbered here.

### 1. Determine the period

Default: **the last complete week** — the Mon–Sun block ending on the most
recent Sunday on or before today (compute from today's actual date; never
reuse a date from a prior session). Accept an explicit period argument ("week
of June 1", "May 18–24") and normalize it to a Monday-start week. The
**period key** is the ISO date of the Monday — it appears in every marker.

### 2. Read the worker roster from QBO

`search_vendors` for the worker vendors. Each carries the worker's name (the
hour-report join key, the bill vendor, AND the payee name passed as `recipientId`),
the placed client, the `BillRate` and `PayRate`, and the `rail` (per
[DATA-MODEL.md](DATA-MODEL.md)). A worker missing a rate or a rail → flag and
exclude; never guess.

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

### 5. Dedupe — before anything is paid

**The bank is the dedupe signal**: each batch item carries its worker's
`PWD-PB-BILL-{period}-{worker-slug}` marker as the ACH `paymentName` / wire
`description`, so `query_transactions {direction: "debit",
descriptionContains: "PWD-PB-BILL-{period}"}` finds every worker already paid
for this period by a prior run. (The read-only demo books never record this
skill's invoices or bills, so QBO carries no trace of a prior run — don't
search it for markers.) A hit → a **potential duplicate** row: show the prior
debit's evidence (date, amount, paymentId) and ask the owner whether to pay
again (a deliberate rehearsal re-run) or drop the worker from the batch.
Stablecoin items carry no description — match those by amount + date + type.

### 6. GATE 1 — the client billing picture

Present the invoice table and **wait for explicit approval** before moving on
to pay (the billing math prices both sides of the cycle — the owner signs off
on it here):

| Client | Worker(s) | Hours | Bill rate | Invoice total | Status |
|---|---|---|---|---|---|

Also show excluded workers. On approval, **narrate the invoicing** — outside
a demo, each client would get a QuickBooks invoice (`create_invoice`):
DocNumber `PWD-PB-INV-{period}-{client-slug}`, TxnDate today, DueDate per the
owner's terms (default net-15 — confirm in the table), one line per worker
(Qty = hours, Rate = BillRate), marker-first `PrivateNote`. The read-only
demo books skip that write; say so in one line and move on.

### 7. GATE 2 — pay the workers

Before the gate:
- `list_accounts` → pay from the primary Operating account (confirm in the
  table if more than one candidate). Never hardcode account numbers.
- For each stablecoin worker, `get_stablecoin_recipient {walletAddress}` —
  must be **VERIFIED**, else flag and exclude that worker from the batch.
- `make_batch_payment` with `dryRun: true` for the full batch — validates
  every item and returns the **real 1% stablecoin fee** for the table.

Present and **wait for explicit approval** (the approval covers the bank
batch; step 8's bookkeeping is narration only):

| Worker | Hours | Pay rate | Gross | Rail | Fee | Status |
|---|---|---|---|---|---|---|

On approval, **ONE** `make_batch_payment` (`dryRun: false`, `stopOnError:
false`), items built per [DATA-MODEL.md](DATA-MODEL.md). **Pay by the worker's
name** for ACH and wire workers — pass `{rail, fromAccountNumber, recipientId:
<worker name>, amount, …}` and the bank resolves it to the worker's saved payee.
**Degrade gracefully:** if a worker has no saved payee (a real worker not yet
onboarded), fall back to the inline recipient block from their vendor record —
ACH with the full `recipient` block, wire with `recipient` + `recipientBank
{name, aba}` — rather than erroring. Stablecoin always uses the stablecoin flow
`{walletAddress, currency: "USD", accountNumber, amount}` (pay-by-name is ACH/Wire
only). ACH
`paymentName` / wire `description` = the worker's bill marker (reconcile trace);
`paymentDate`/`processDate` is **optional and defaults to the next business
day** server-side — set it only to override that default.

Report per-item results from `results[]`. **The tool is not idempotent**: on
partial failure, fix and re-submit **only the failed items** — never the
whole batch.

### 8. Narrate the booking — what would happen in QuickBooks

The workers are paid; the bookkeeping is narration. Say — briefly, per the
run — what would happen next outside a demo: each paid worker would get a
Bill (`create-bill`, DocNumber `PWD-PB-BILL-{period}-{worker-slug}`, amount =
gross, marker-first `PrivateNote` carrying the Paywhere `paymentId`) and a
matching Bill Payment (`create_bill_payment`), booking the cost side of the
cycle. The read-only demo books skip those writes; the dedupe trail lives in
the bank instead — each payment's description already carries its marker
(step 7), which is what step 5 finds on a re-run.

### 9. Reconcile and summarize

- `query_transactions {direction: "debit", dateFrom: <period Monday>,
  dateTo: <today>}` — match each worker payment: ACH/wire by the `PWD-PB`
  marker in the description (`descriptionContains: "PWD-PB"`), stablecoin by
  amount + date + type. Note anything still pending vs posted.
- **Margin summary**: invoiced total vs worker pay total vs the ratio —
  should sit at ≈1.3 (persona rates are exactly 1.3×); flag a material
  deviation.
- Collecting the invoiced hours is **not** this skill's job: outside a demo
  the cash is chased later via `/invoice-chase` and shows up in
  `/plan-payroll` — say so in the close-out.

End with: the billing table as narrated (per-client totals), payments (rail +
Paywhere id), the one-line bookkeeping narration, and the margin line.

## Graceful degradation — say what's skipped, never half-work silently

- **No Paywhere**: run steps 1–4 and 6 only — the billing picture still gets
  presented and narrated — then produce the **drafted payment list** (worker,
  gross, rail, payee name or payment fields) without executing anything. No
  bank batch; tell the owner exactly that.
- **No QuickBooks**: **stop** — QBO is the system of record for both the
  worker roster/rates and the time-activities (the hours). Without it there is
  no source of truth; hours and rates cannot be skipped or faked.
- **A worker with no saved payee**: don't error — fall back to the
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
- **A prior run's payment for the same worker/period** (the demo re-run
  case): caught by the step-5 bank check — surface it as a potential
  duplicate with the prior debit's evidence and let the owner decide; never
  pay a flagged row without that explicit confirmation.

## Approval gates

- **Gate 1 (step 6)** covers the client billing picture; **Gate 2 (step 7)**
  covers the bank batch. Nothing is paid before its gate.
- One approval covers one batch; adding or changing a row after approval
  restarts that gate.
- A step-5 potential-duplicate row is never paid without the owner's explicit
  go-ahead on that specific row.
- Never invent payment details or hours — missing/malformed data is flagged
  and excluded, not guessed.

## Reference

- [DATA-MODEL.md](DATA-MODEL.md) — the QBO worker-vendor and time-activity
  shapes, the invoice/pay/margin math, PWD-PB marker formats, and the verbatim
  MCP tool signatures.
- [../../DATASET.md](../../DATASET.md) — the demo world's persona, worker
  roster, weekly hours (seeded server-side in the shared books), and saved
  payees (seeded by `/demo-setup`).
