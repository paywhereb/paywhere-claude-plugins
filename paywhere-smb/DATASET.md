# DATASET.md — the Nick's HVAC demo world (reference, not runtime data)

This file describes the world the **server** builds. It is reference for
presenters and reviewers; **no skill reads it at run time, and no skill
hardcodes anything in it**. Skills read whatever is in the bank, the books,
the mailbox and the calendar when they run.

Where the numbers come from:

- **Generator:** `buildWorld(dateModel)` in
  `paywhere-mcp/paywhere-mcp-api/src/demo/world/` (`spec.ts` = the roster,
  vendors and rules from blueprint §3 as data; `generate.ts` = the events;
  `answerKey.ts` = every number derived from the generated ledgers). A
  byte-identical copy lives in `paywhere-qbo-mcp/src/demo/world/` and seeds
  the books; the same module emits the Gmail and Calendar manifests.
- **Answer key:** `answerKey` (shape: `types.ts` → `AnswerKey`). `/demo-setup`
  prints `answerKeySummary` after seeding; the eval suite grades against the
  full key. Nothing in it is hand-entered.
- **Date model:** two anchors, `today` and `horizon` (the most recent
  Sunday), plus a calendar-pinned annual layer (seasonality, stress periods,
  tax calendar) and a horizon-relative live surface (this week's overdue
  invoices, bills, payroll, remittance). Same week ⇒ same rows ⇒ same answer
  key. Blueprint §3.19.
- **Blueprint:** `paywhere-mcp/docs/plans/nicks-hvac-demo-blueprint.md` §3 is
  the authoritative narrative; this file is the short form.

**Where the numbers live.** For a given demo date the full answer key is
checked into paywhere-mcp as
`paywhere-mcp-api/src/demo/world/fixtures/answer-key-<today>.json`
(`answer-key-2026-09-02.json` for the September 2026 run — being
generated); regenerate one with
`buildWorld(computeDateModel("<today>")).answerKey`. At demo time
`seed_demo_world` / `get_demo_world` return `answerKeySummary`, a subset
with the same paths (`balances`, `trueAvailable`, `tax.{reserveBalance,
collectedNotRemitted, shortfall, missedSweeps, nextRemittance}`,
`ar.{aging, largestOverdue, unbookedReceipt, chaseOrder}`,
`ap.{dueThisWeek, earlyPaymentPattern, holdCandidates}`,
`payroll.{nextPayDate, estimatedTotal, headroomAfterPayroll}`,
`subscriptions.monthlyTotal`, `liveSurface`, `counts`). Everything else
(`monthly`, `lows`, `cashBridge`, `forecast13w`, `van`, `whatIf`,
`settlements`, `referrals`, `profitability`) is in the full key only.

> Setup: `/demo-setup` reads the books' `dateModel` (`get_demo_dates`),
> starts the async bank seed (`seed_demo_world`), polls `get_demo_world` to
> completion (≈ 4–6 min for ≈ 1,000 rows), reads the world back through the
> connector and reports the answer-key summary. Books are shared and
> read-only (reseeded 5am ET); the bank world is per presenter. Mail and
> calendar are seeded by `paywhere-qbo-mcp/scripts/seed-google.mjs` into the
> shared `demo-nick@paywhere.com` account.

---

## The business (qualitative)

**Nick's HVAC LLC** — Kansas City metro, HQ on Southwest Blvd in Kansas City
MO, roughly 45% of work across the state line in Johnson County KS. S-corp;
owner **Nick Adler** on salary plus quarterly distributions; two hourly
technicians (Ray Dominguez, Tyler Brooks) paid biweekly through Gusto with
summer/winter overtime and mileage reimbursement (they drive their own
vehicles). ≈ $800k trailing-12-month revenue, 10–12% net margin on paper,
operating cash roughly flat year over year — distributions, owner taxes, AR
growth and equipment absorb the profit. No credit card, no line of credit,
no term debt. Systems: QuickBooks Online, Gusto, QuickBooks Payments, a
field-service app that is not connected, the bank via Paywhere.

**Customers (22, fixed roster):** 13 with monthly service agreements (billed
on the 1st, net 30, +4% at January renewal; three added during the year as
growth), repeat one-off customers, small one-offs, and three project
customers (a warehouse replacement with a 30% deposit, a GC tenant build-out
with 10% retainage held 120 days, a church renovation with a 50% deposit).
Repairs, replacements and projects are sub-customer **jobs** in the books,
so profitability by customer computes from job costing. Referral source
lives in the customer **Notes**.

**Payment behavior (the AR engine):** profiles, not labels — prompt (0–5
days), routinely late (10–20 days; includes the largest customer, a
property manager paying through an AP-automation system), occasionally very
late (30–60 days on about one invoice in four), delinquent-then-cured (one
gym customer whose card autopay fails and who is materially late Oct–Jan,
cured after a payment plan), retainage. Late payers do not look problematic
on day one; the pattern emerges over 3–4 cycles. DSO ≈ 31 in September,
worsens to ≈ 41 in November, improves to ≈ 28 by July after deposits are
required on jobs over $10k (a March policy change visible in the data).

**How customers pay (D6):** QuickBooks Payments card/pay-by-link (≈ 35%,
netted daily settlements — `INTUIT PYMT SOLN DEPOSIT`, gross in the books
with a negative merchant-fee line), direct ACH credits from customers' own
banks or AP systems (≈ 30%, `ACH CR <CUSTOMER>`), mobile check deposits
(≈ 25%, `MOBILE CHECK DEPOSIT <check#>`), wires for project milestones
(≈ 10%, `WIRE IN` + a $15 fee).

**Vendors (≈ 30, real brands):** parts on statement (ACH on the 28th),
equipment suppliers on net 30 (**paid 12–18 days early Sep–Apr, on the due
date May–Aug** — the discoverable AP-timing habit), subcontractors paid on
receipt (one by wire), Gusto debits (net pay + taxes biweekly, monthly fee),
rent and utilities, insurance (GL annual in January, WC and auto monthly),
≈ $1,380/month of recurring software, telecom and service debits — 11
descriptors, `subscriptions.items`, including phones, internet and uniforms
alongside the software (a lead-gen subscription with zero attributed jobs,
an orphaned design-tool seat and a duplicate seat are the flags), marketing, a CPA, fuel on a debit card, three referral
partners paid on the 10th, and the tax authorities. **Every vendor,
subcontractor, partner and tax authority is a saved payee** (ACH for all;
wire details as well for the crane subcontractor and one equipment
supplier), so payments by name work from the bare connector.

**Payroll:** 26 biweekly runs; per run `ACH DEBIT GUSTO NET PAY` +
`ACH DEBIT GUSTO TAX`; a Gusto-style journal entry per run in the books; a
Gusto payroll-summary email per run in Gmail with the register attached.

**Taxes and the reserve (simplified rules — not tax advice):** Kansas taxes
parts and labor on commercial repair/maintenance (install labor exempt);
Missouri taxes parts and equipment only. Explicit tax line items post to
per-state liability accounts (`Sales Tax Payable - KS/MO`); remittances on
the 20th debit the **Tax Reserve**. Nick's rule is a manual **Friday
sweep**: the sales tax included in that week's *received* payments moves
Operating → Tax Reserve. He skips three Fridays in the cash-tight Oct–Nov
stretch and once sweeps on invoiced rather than received amounts; on the
live surface the last two Fridays are missed, so the reserve is short. Owner
quarterly estimates and the KC earnings tax are paid from **Operating**, not
the reserve.

**Seasonality and stress periods (calendar-pinned):** index Jan 1.05 · Feb
0.85 · Mar 0.80 · Apr 0.85 · May 0.95 · Jun 1.20 · Jul 1.35 · Aug 1.30 ·
Sep 1.00 · Oct 0.80 · Nov 0.85 · Dec 1.00, ±8% deterministic jitter. Four
stress periods, all present in every 12-month window: **A** slow
receivables (Oct–Nov), **B** poor AP timing (Apr, equipment paid early
before project receipts), **C** the timing collision (Jan–Feb: the Hartford
annual premium + Q4 owner estimate + December sales tax + payroll + a parts
statement before Metro Auto and Westport pay), **D** seasonal investment
(May–early June stocking + a recovery machine + OT ramp). Operating cash
oscillates ≈ $14k–$80k across the year; **which low is the twelve-month
minimum depends on the window** (`lows[]`, with the period letter and the
mechanism) — for a September demo it is mid-February (C) at exactly
$14,000. Nick is never insolvent; the reserve is never raided.

**Profit vs cash runs both ways.** In the slow months cash falls while the
P&L is positive; in the month after the summer peak cash rises by *more*
than profit because June–July receivables are collected (`cashBridge.deltaAR`
negative). For a September demo the bridge month is August:
`cashBridge.netIncome` ≈ +$15k, `operatingCashChange` ≈ +$41k. Beat 1.2 is
worded neutrally for that reason (see `demo/SCENARIOS.md`).

**The vehicle decision:** a cargo van quote, a lender term sheet and an
insurance quote in Gmail; the dealer appointment on the calendar; the
mileage-reimbursement offset in payroll. The data supports: one van,
financed, is comfortable; paying cash pushes the 13-week minimum below the
payroll cushion (`van.cashPurchaseMinBalanceAfter`); the safest and risky
months are computed from month-end closes (`van.safestPurchaseMonths`,
`van.riskyMonths` — Aug/Mar/Jun vs Jan/Jul/Dec for a September 2026 start);
a second before next summer is not without better collections, no early
payments, or a line of credit (`van.secondVanVerdict`).

**Growth:** H2 ≈ +11% vs H1 (three new agreements, the January price
increase, more summer replacements, OT up), ≈ $60k of open estimates.

---

## The fixed figures (never change with the date model)

| Item | Value |
|---|---|
| Opening balances (12 months ago) | Tax Reserve **$3,200** and Business Savings **$12,000** are fixed. Operating Checking is **calibrated per window** so the twelve-month chronological low is exactly **$14,000** (`OPERATING_OPENING_BASE` 38,000 shifted by the window's uncalibrated minimum, rounded to $100 — ≈ $44,200 for a 2026-09-02 start); read the actual opening from the world's `accounts[]`, never assume 38,000 |
| Business Savings | $250/month sweep + interest; never touched |
| Owner calendar | Quarterly distributions **$9,000** on the 25th of Feb / May / Aug / Nov · owner estimated taxes **$6,500** on Jan 15 / Apr 15 / Jun 15 / Sep 15 (from Operating; `tax.ownerEstimates`) · The Hartford GL annual **$4,800** on Jan 13 |
| Agreements (monthly) | Westport Commons $2,400 · Fairway Medical Plaza $1,900 · Overland Park Office Suites $1,600 · Metro Auto Group $1,250 · Riverside Tap House $1,050 · Blue Line Fitness $780 · Crossroads Brewing $690 · Prairie Ridge Dental $650 · Sunflower Childcare $560 (from March) · St. Anselm $520 · Union Hill Apartments $460 (from August) · Liberty Storage $440 (from April) · Heartland Vet $380 |
| Staged live surface (horizon-relative) | Westport Commons **$7,200** (`ar.largestOverdue`; due horizon − 17 days, so ≈ 18–20 days late by demo day — the largest amount, not `liveSurface.overdueInvoices[0]`, which is sorted by days late) · Trane Supply **$11,400** due horizon + 18 days (≈ 15 days from a midweek `today`; the early-payment temptation → `ap.holdCandidates[0]`) · bills due this week: Johnstone Supply **$6,850** (ACH), Voltage Electric **$2,150** (ACH), Ironclad Crane & Rigging **$1,900** (wire) — `ap.dueThisWeek` may also carry a generated bill that falls due in the window (Trane $3,860 on 2026-09-06 for the September run) · St. Anselm check **#4471** deposited this week, not yet applied in the books — the **$520** agreement, invoiced at **$590.01** with the January +4% renewal and KS tax (`ar.unbookedReceipt.amount`) · Angi Leads **$349** recurring debit (zero attributed jobs) · 2 pending card authorizations (`liveSurface.pendingAuthorizations`) · 3 merchant settlements booked at gross (`liveSurface.unreconciledSettlements`) |
| Reserve on the live surface | short by the last two Friday sweeps — `tax.shortfall` (≈ $2.8k for the September 2026 run, not a fixed figure); `tax.missedSweeps` also lists the three Oct–Nov Fridays skipped in the cash-tight stretch |
| Van | $58,500 all-in; finance option $10,000 down on $48,500 at 8.25%, 60 months → **$989.22/mo** (`van.financing.monthlyPayment`); +$165 insurance, +$320 fuel/maintenance (`van.addedMonthlyCost` 485); mileage offset $825/mo → `van.netMonthlyCashImpact` ≈ $316 |
| What-if levers | 7 (`whatIf[]`): revenue −10%, largest customer pays 30 days late, hire a third tech, lose the largest agreement, collect 15 days faster, stop paying vendors early, van financed (989/mo + running costs) |
| Bank fees | Service charge $25/mo; wires $30 out / $15 in |
| Merchant fees | 2.99% + $0.30 card; 1% capped at $10 ACH; netted from settlements |
| Engineered imperfections | three recent merchant settlements booked at gross (fee line missing: $71.56, $58.10, $102.30 short at the bank); one duplicate card charge refunded ($650); one failed card autopay; ≈ 5% of recent debit-card rows unrecorded in the books; one referral fee paid on an uncollected retainage invoice |

Everything else — balances at demo time, monthly totals, DSO, aging, the
bridge, the forecast, the lows, the payroll estimate (≈ $11,148 next run for
September 2026), the true-available figure — is generated and lands in the
answer key. Quote paths, not numbers, when writing a beat.

## Bank accounts (mock bank)

| Account | Type | Purpose |
|---|---|---|
| Operating Checking (primary) | Checking | Everything operational |
| Tax Reserve | Savings | Sales tax only; funded by the Friday sweep; the 20th remittances debit it |
| Business Savings | Savings | The cushion Nick does not touch |

The mock bank supports Checking and Savings only and its transaction record
has seven fields, so **statement descriptors carry the rail**: `POS DEBIT …`,
`RECURRING DEBIT …`, `ACH DEBIT …`, `ACH CR …`, `MOBILE CHECK DEPOSIT <n>`,
`WIRE IN …` / `WIRE OUT …`, `INTUIT PYMT SOLN DEPOSIT`, `TRANSFER TO TAX
RESERVE`, `SERVICE CHARGE`, `INTEREST PAID`. ≈ 100 rows/month, ≈ 1,000–1,200
over 12 months across the three accounts, plus a handful of `pending` card
authorizations in the current week. ≈ 200 targeted enrichment records
(`get_transaction_detail`) cover settlements, remittances, referral fees and
the recurring debits; enrichment is best-effort and may be `null`.

## What reconciles across the four sources

| Event | Bank | QuickBooks | Gmail / Calendar |
|---|---|---|---|
| Agreement invoice paid | ACH CR / check deposit / merchant settlement | Invoice → Payment → Deposit | — |
| Project milestone | WIRE IN + $15 fee | Invoice + Payment + Deposit | Contract email; milestone on the calendar |
| Payroll run | GUSTO NET PAY + GUSTO TAX | Journal entry | Payroll-summary email; payday on the calendar |
| Sales tax | Friday TRANSFER TO TAX RESERVE; 20th DEPT OF REVENUE debits from the reserve | Tax lines → liability accounts; Transfer; remittance Purchase | 20th deadline + Friday sweep events |
| Owner estimates / distributions | IRS debit; owner transfer, from Operating | Equity draws | Quarterly estimate dates |
| Vendor bill paid | ACH DEBIT / WIRE OUT | Bill → BillPayment | Vendor invoice email |
| Debit-card purchase | POS DEBIT | Purchase (≈ 5% recent ones missing) | — |
| Referral fee | ACH DEBIT on the 10th | Bill with per-customer memos | Agreement + monthly statement emails |
| Merchant settlement | INTUIT PYMT SOLN DEPOSIT (net) | Deposit (gross − fee; 3 recent missing the fee) | — |
| Subscription | RECURRING DEBIT | Purchase | Renewal email |
| Vehicle | — | Estimates, mileage in payroll JEs | Quote, term sheet, insurance emails; dealer appointment |

## Verification

`paywhere-mcp-api` ships `npm test` (`scripts/verify-demo.mjs`): the world
closes deterministically within a week, answer-key balances equal the running
sums, deposits precede withdrawals per account, the operating balance never
goes negative, the fixture deep-equals `buildWorld(fixture.dateModel)` in
both repos, and the reserve/tax invariants hold. `/demo-setup`'s readback
asserts the same closings through the connector.

## Frozen: Meridian Staffing (D9)

The previous world (Meridian Staffing & Advisory, six months, one payroll
squeeze) is kept for reference and not maintained; its books are no longer
reseeded, and its `pay-and-bill` / `pay-commissions` skills left the plugin
package in 1.0.8 (git history before that). The old
generator is `paywhere-mcp-api/src/demo/legacy/meridianBankDataset.ts`.
