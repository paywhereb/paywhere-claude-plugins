# Bank seed manifest — mock bank via `seed_transactions`

The canonical ~3-month bank history for Meridian Staffing & Advisory LLC.
Every row uses date tokens per [date-tokens.md](date-tokens.md); counterparty
details (achRecipient blocks, inboundWireData) live in
[persona.md](persona.md). Accounts are referred to by **role** (Operating =
Operating Checking, Reserve = Reserve Savings); concrete account numbers come
from `reset_demo` / `get_demo_world` output at run time — never hardcode them.

Conventions:
- Inbound client wires → `type: "DomesticWire"` deposits with `inboundWireData`
  (sender fields per persona.md; `referenceForBeneficiary` = the invoice
  DocNumber shown in the row).
- Inbound ACH-style credits → **`type: "Transfer"`** deposits with an
  `ACH CR <CLIENT>` statement description. **Deposits can never be type
  `ACH`** — the mock bank rejects them per item.
- Vendor debits → `type: "ACH"` withdrawals with the full `achRecipient`
  block from persona.md. Outbound wires → `type: "DomesticWire"` withdrawals.
  Wire fees and interest → `type: "Cash"`. Sweeps → a `Transfer` withdraw
  (Operating) + `Transfer` deposit (Reserve) pair.
- Every row: `status: "posted"`, `postDate` = the resolved token date.

## M-2 — fully matched month (19 rows)

Deposits:

| Token | Account | Direction | Amount | Type | Description | StatementDescription | Extra |
|---|---|---|---|---|---|---|---|
| M-2:03 | Operating | deposit | 8,500.00 | Transfer | Hallsten & Berg AB — advisory retainer | ACH CR HALLSTEN & BERG AB | — |
| M-2:05 | Operating | deposit | 20,800.00 | DomesticWire | Thames Fintech Ltd — consulting hours | WIRE IN THAMES FINTECH LTD | inboundWireData → persona.md; ref `PWD-INV-0101` |
| M-2:06 | Operating | deposit | 23,400.00 | DomesticWire | Zurich Dynamics AG — consulting hours | WIRE IN ZURICH DYNAMICS AG | inboundWireData → persona.md; ref `PWD-INV-0102` |
| M-2:10 | Operating | deposit | 7,020.00 | DomesticWire | Mitsui Digital KK — partial 1 of 2 | WIRE IN MITSUI DIGITAL KK | inboundWireData → persona.md; ref `PWD-INV-0104 PARTIAL 1/2` |
| M-2:24 | Operating | deposit | 7,020.00 | DomesticWire | Mitsui Digital KK — partial 2 of 2 | WIRE IN MITSUI DIGITAL KK | inboundWireData → persona.md; ref `PWD-INV-0104 PARTIAL 2/2` |
| M-2:26 | Operating | deposit | 15,600.00 | Transfer | Alderbrook Ventures LLC — staffing hours | ACH CR ALDERBROOK VENTURES | — |
| M-2:24 | Reserve | deposit | 45,000.00 | Transfer | Monthly sweep from Operating | TRANSFER FROM OPERATING CHECKING | pairs with the M-2:24 sweep-out below |
| M-2:31 | Reserve | deposit | 93.75 | Cash | Interest — monthly | INTEREST PAYMENT | clamp/roll per date-tokens.md |

Withdrawals:

| Token | Account | Direction | Amount | Type | Description | StatementDescription | Extra |
|---|---|---|---|---|---|---|---|
| M-2:01 | Operating | withdraw | 6,800.00 | DomesticWire | Sutter Hill Properties — office rent | WIRE OUT SUTTER HILL PROPERTIES | wire details → persona.md |
| M-2:01 | Operating | withdraw | 45.00 | Cash | Wire transfer fee | WIRE TRANSFER FEE | — |
| M-2:05 | Operating | withdraw | 2,450.00 | ACH | Amazon Web Services Inc — hosting | ACH DEBIT AMAZON WEB SERVICES | achRecipient → persona.md |
| M-2:07 | Operating | withdraw | 480.00 | ACH | Google Workspace | ACH DEBIT GOOGLE WORKSPACE | achRecipient → persona.md |
| M-2:07 | Operating | withdraw | 375.00 | ACH | Slack Technologies | ACH DEBIT SLACK TECHNOLOGIES | achRecipient → persona.md |
| M-2:10 | Operating | withdraw | 1,160.00 | ACH | HubSpot Inc — CRM | ACH DEBIT HUBSPOT INC | achRecipient → persona.md |
| M-2:12 | Operating | withdraw | 640.00 | ACH | DigitalOcean — hosting | ACH DEBIT DIGITALOCEAN | achRecipient → persona.md |
| M-2:13 | Operating | withdraw | 11,700.00 | ACH | Gusto Inc — biweekly payroll | ACH DEBIT GUSTO PAYROLL | achRecipient → persona.md |
| M-2:20 | Operating | withdraw | 1,500.00 | ACH | Grant Henderson CPAs — accounting | ACH DEBIT GRANT HENDERSON CPAS | achRecipient → persona.md |
| M-2:24 | Operating | withdraw | 45,000.00 | Transfer | Monthly sweep to Reserve Savings | MONTHLY SWEEP TO RESERVE | internal pair — no QBO entity |
| M-2:27 | Operating | withdraw | 11,700.00 | ACH | Gusto Inc — biweekly payroll | ACH DEBIT GUSTO PAYROLL | achRecipient → persona.md |

M-2 totals — Operating: credits **$82,340.00**, debits **$81,850.00** (net
+$490.00). Reserve: credits **$45,093.75**.

## M-1 — fully matched month (19 rows)

**Identical to M-2** in every row, with three substitutions:
- All tokens `M-2:dd` → `M-1:dd`.
- Wire references `PWD-INV-01xx` → `PWD-INV-02xx` (same client order).
- Reserve interest row: token **`EOM-1`**, amount **$150.00** (balance grew
  after the M-2 sweep).

M-1 totals — Operating: credits **$82,340.00**, debits **$81,850.00** (net
+$490.00). Reserve: credits **$45,150.00**.

## M0 — current month up to the horizon (14 rows, before drops)

Bank-complete but QBO-incomplete: the freshest activity concentrates in `W-1`
so /pay-commissions "last week" and /pay-and-bill always have matches. Rows
with `M0:dd` tokens after the horizon are dropped per date-tokens.md; `W-1`
rows are never dropped.

Deposits:

| Token | Account | Direction | Amount | Type | Description | StatementDescription | Extra |
|---|---|---|---|---|---|---|---|
| M0:02 | Operating | deposit | 43.17 | Cash | Interest credit · monthly accrual | INTEREST PAYMENT | **DISCREPANCY (a)** — deliberately NO QBO counterpart |
| W-1:Mon | Operating | deposit | 8,500.00 | Transfer | Hallsten & Berg AB — advisory retainer | ACH CR HALLSTEN & BERG AB | received in bank, deliberately NOT recorded in QBO |
| W-1:Tue | Operating | deposit | 20,800.00 | DomesticWire | Thames Fintech Ltd — consulting hours | WIRE IN THAMES FINTECH LTD | inboundWireData → persona.md; ref `PWD-INV-0301` |
| W-1:Wed | Operating | deposit | 23,400.00 | DomesticWire | Zurich Dynamics AG — consulting hours | WIRE IN ZURICH DYNAMICS AG | inboundWireData → persona.md; ref `PWD-INV-0302` |
| W-1:Thu | Operating | deposit | 7,020.00 | DomesticWire | Mitsui Digital KK — partial 1 of 2 | WIRE IN MITSUI DIGITAL KK | inboundWireData → persona.md; ref `PWD-INV-0304 PARTIAL 1/2` |

Withdrawals:

| Token | Account | Direction | Amount | Type | Description | StatementDescription | Extra |
|---|---|---|---|---|---|---|---|
| M0:01 | Operating | withdraw | 6,800.00 | DomesticWire | Sutter Hill Properties — office rent | WIRE OUT SUTTER HILL PROPERTIES | wire details → persona.md |
| M0:01 | Operating | withdraw | 45.00 | Cash | Wire transfer fee | WIRE TRANSFER FEE | — |
| M0:03 | Operating | withdraw | 2,500.00 | DomesticWire | Sutter Hill Properties — buildout deposit | WIRE OUT SUTTER HILL PROPERTIES | wire details → persona.md; QBO books the $2,500 |
| M0:03 | Operating | withdraw | 1.20 | Cash | Wire transfer fee (promo rate) | WIRE TRANSFER FEE | **DISCREPANCY (b)** — QBO books this fee as $0.00 → $1.20 delta |
| M0:05 | Operating | withdraw | 2,450.00 | ACH | Amazon Web Services Inc — hosting | ACH DEBIT AMAZON WEB SERVICES | achRecipient → persona.md |
| M0:07 | Operating | withdraw | 480.00 | ACH | Google Workspace | ACH DEBIT GOOGLE WORKSPACE | achRecipient → persona.md |
| M0:07 | Operating | withdraw | 375.00 | ACH | Slack Technologies | ACH DEBIT SLACK TECHNOLOGIES | achRecipient → persona.md |
| M0:10 | Operating | withdraw | 1,160.00 | ACH | HubSpot Inc — CRM | ACH DEBIT HUBSPOT INC | achRecipient → persona.md |
| M0:12 | Operating | withdraw | 640.00 | ACH | DigitalOcean — hosting | ACH DEBIT DIGITALOCEAN | achRecipient → persona.md |

M0 contains **no** Gusto payroll run, no sweep, and no day-20 CPA debit — the
next payroll is an *upcoming obligation* (due `W+0:Fri`, see persona.md) and
the CPA story lives in the open bills (qbo-manifest.md). That is the
cash-crunch setup, not an omission.

M0 totals (full seed, before drops) — Operating: credits **$59,763.17**,
debits **$14,451.20** (net +$45,311.97).

## Closing check — running balance never goes negative

**Application-order check (the one `seed_transactions` enforces).** Seed in
three chunks (one per month, below), deposits before withdrawals within each
chunk, so at apply time the balance only rises before it falls:

| Chunk | Operating start | after deposits | after withdrawals | min during chunk |
|---|---|---|---|---|
| M-2 | 50,000.00 | 132,340.00 | 50,490.00 | 50,000.00 |
| M-1 | 50,490.00 | 132,830.00 | 50,980.00 | 50,490.00 |
| M0 | 50,980.00 | 110,743.17 | 96,291.97 | 50,980.00 |

Reserve only ever receives deposits: 75,000.00 → 120,093.75 (M-2) →
165,243.75 (M-1). Closing balances (full seed): **Operating $96,291.97,
Reserve $165,243.75**. Dropped M0 rows are almost all debits, so drops only
raise the Operating close.

**Chronological floor (statement realism).** Worst-case date ordering (W-1
late in the month, all M0 debits first) bottoms Operating at **$36,571.97**
after the M0:12 debit — comfortably positive, so the rendered statement never
shows a negative day either. Per-month chronological minimums (nominal
token-day ordering — exact day-end floors shift slightly when weekend
roll-backs collide two tokens onto the same Friday; recompute from resolved
dates if you need the precise floor): ≈$43,155.00 (M-2:01), ≈$43,645.00
(M-1:01), $36,571.97 (M0:12 worst case).

## Seeding mechanics

1. Get the real account numbers for the Operating/Reserve **roles** from the
   `reset_demo` response (or `get_demo_world`). Never hardcode them.
2. Drop post-horizon rows first, per the approved resolved-date table.
3. Seed with `seed_transactions` in **three chunks — M-2 (19 rows), M-1 (19
   rows), M0 (≤14 rows after drops)** — each ≤25 items (the hard chunk
   ceiling). Within each chunk order **all deposits before all withdrawals**
   so no account dips negative at apply time (proof above).
4. Pass `stopOnError: true`. After every chunk check `succeeded`, `failed`,
   and **`stoppedAtIndex`**: if the call stopped early, fix the offending row
   and re-submit **only the remaining rows** — never the whole chunk
   (`seed_transactions` is not idempotent).
5. Report per-chunk results (succeeded/failed counts, final `newBalance`)
   before moving to the QBO seed.
