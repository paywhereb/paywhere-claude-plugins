# DATASET.md — the canonical Meridian demo dataset (single source of truth)

This file documents the demo world that the **server datasets** build — it is
**reference, not data the skills read at runtime**. The persona, numbers, and
recipient map below live ONLY in server code:

- Bank rows + recipients + enrichment: `paywhere-mcp/paywhere-mcp-api/src/demo/bankDataset.ts`
- QBO books: `paywhere-qbo-mcp/src/demo/qboDataset.ts`
- Shared date engine: `src/demo/dates.ts` (both repos; paywhere-mcp authoritative)

The plugin **skills stay business-agnostic**: they read whatever is in
QuickBooks/Paywhere at run time and never hardcode any name or amount below.
This doc carries the numbers that the five deleted `demo-setup-*` manifests used
to hold, scaled to the revamp.

> Setup is now **two tool calls** made by `/demo-setup`:
> 1. `seed_demo_world {confirm:true}` (paywhere-mock) → builds the bank world, returns `dateModel` + creds.
> 2. `seed_demo_books {dateModel, confirm:true}` (quickbooks) → mirrors the books on the same dates.
>
> All date math is server-side; nothing here is hand-resolved.

---

## Persona

**Meridian Staffing & Advisory LLC** — a boutique consulting + staffing firm:
places senior contractors at clients, bills clients for hours, pays the
contractors, runs a small advisory retainer practice. Mock/test bank details
throughout (no real money).

## Scale

Whole business scaled **~0.30×** the old world. Accounts open at:

| Role | Type | Opening balance | At demo time (close) |
|---|---|---|---|
| **Operating Checking** | Checking (primary) | $40,000 | **≈ $23,000** (engineered for the payroll-shortfall beat) |
| **Reserve Savings** | Savings | $20,000 | ≈ $20,138 (interest only) |

The $40,000 is the account's *opening* balance six months ago; gentle monthly
drawdown + current-cycle one-offs land Operating at exactly **$23,000** by the
horizon (verified by `paywhere-mcp-api`'s `npm test`). That sets up a believable
small shortfall against Friday's ≈ $23,730 of obligations.

## Date model (6 months, ending the most recent Sunday)

The canonical dataset uses only **M-5…M-1 month tokens** and **W-1 weekday
tokens** for posted rows — all of which always resolve on/before the horizon —
so the posted-row set (and the closing balances) is **identical every day of the
week** (Mon–Sat of the constant-horizon window; it rolls on the next Sunday).
Due dates use `W+0:Fri(+N)` and shift with the run day by design. Full token
grammar lives in the header of `src/demo/dates.ts`.

- **M-5 … M-1** — five standard recurring months.
- **Current cycle (W-1)** — last complete week; the demo surface (freshest
  receipts, the unrecognized vendor, the one-off drains).

---

## Clients (QBO customers) — standard month ≈ $25,200

| Client | Pays by | Monthly | Personality |
|---|---|---|---|
| Thames Fintech Ltd | Wire | $6,400 | prompt |
| Zurich Dynamics AG | Wire | $7,200 | prompt |
| Alderbrook Ventures LLC | ACH-style | $4,800 | **slow — the overdue-AR payer** |
| Mitsui Digital KK | Wire | $4,200 | **partial — two $2,100 halves** |
| Hallsten & Berg AB | ACH-style | $2,600 | **the unrecorded "phantom" credit** |

Wire receipts seed as `DomesticWire` deposits with `inboundWireData`; ACH-style
credits seed as `Transfer` deposits with an `ACH CR <CLIENT>` statement
description (the mock bank can't post ACH *deposits*).

## Workers (contractors) — pay = bill ÷ 1.3

| Worker | Placed at | Monthly pay | Rail |
|---|---|---|---|
| Priya Raman | Thames | $4,920 | ACH |
| Marcus Webb | Alderbrook | $3,690 | ACH |
| Elena Sorokina | Zurich | $5,540 | Wire |
| Devon Okafor | Mitsui | $3,230 | Stablecoin |

Monthly contractor run total = **$17,380** (the recurring Friday obligation in
beat #5). Seeded as historical monthly bank debits (the "old processor"
baseline) and as paid QBO bills against worker-vendors.

**Pay-and-bill weekly hours** (phase-2 B; last week, whole-dollar hours×rate,
bill = pay×1.3 exactly), seeded as QBO **time-activities**:

| Worker | Hours | Pay rate | Weekly pay | Bill rate | Weekly bill |
|---|---|---|---|---|---|
| Priya Raman | 40 | $40 | $1,600 | $52 | $2,080 |
| Marcus Webb | 36 | $30 | $1,080 | $39 | $1,404 |
| Elena Sorokina | 40 | $60 | $2,400 | $78 | $3,120 |
| Devon Okafor | 32 | $50 | $1,600 | $65 | $2,080 |

## Vendors (AP) — standard month

ACH: AWS $760 · Gusto biweekly $3,600 (×2 = $7,200/mo) · Google Workspace $150 ·
Slack $120 · HubSpot $360 · Grant Henderson CPAs $470 · DigitalOcean $200.
Wire: **Sutter Hill Properties** rent $2,100 + $45 wire fee.

All vendors + the ACH/Wire workers + the ACH/Wire commission payees are
**seeded as saved payees at seed time**, so a pay step passes only the payee's
**name** (`recipientId`) + amount and the bank resolves the bank details. The
match is forgiving on minor name variations (suffix/spacing/case); the payee
name is the same name that appears on the QuickBooks vendor/worker record.

## Commission map (server-side; phase-2 C)

| Client | Rate | Payee | Rail | Commission (full month) |
|---|---|---|---|---|
| Thames Fintech | 5% | Jane Doe Referrals | ACH | $320 |
| Alderbrook | 5% | Jane Doe Referrals | ACH | $240 |
| Zurich Dynamics | 10% | Acme Sales Partners LLC | Wire | $720 |
| Mitsui Digital | 10% | CryptoConsult DAO | Stablecoin | $420 (half: $210) |
| Hallsten & Berg | — | — | — | **deliberately absent → "skipped, not in register"** |

All gross × rate are whole dollars by design.

---

## The six Phase-1 beats (what each one shows)

1. **Show balances** — Operating ≈ $23,000, Reserve ≈ $20,138.
2. **Categorize spending (6 months)** — reads the bank; contractor labor, payroll
   (Gusto), rent, cloud/SaaS, the NorthPeak charge.
3. **Investigate + reconcile NorthPeak** — ONE distinctive ACH debit of
   **$1,280**, dated `W-1:Tue`, with a deliberately cryptic statement line
   `ACH DEBIT NPA*ENRICH 8002231` (a processor passthrough — neither the vendor
   name nor anything that auto-matches the books; `8002231` echoes contract
   NP-2231). `get_transaction_detail` (or the Gmail invoice) reveals: NorthPeak
   Analytics LLC, 220 Kearny St Ste 600, San Francisco CA; memo "Data enrichment
   subscription — annual, billed in arrears (contract #NP-2231)"; category
   "Software & Subscriptions"; ref "NP-INV-4471"; and that it **auto-renewed at a
   higher rate ($1,200 → $1,280)**, signed by M. Webb 11 months ago.
   **Reconciliation:** the matching QBO bill `PWD-BILL-0601` is still the OLD
   **$1,200** rate and is **OPEN/unpaid** — the bank payment never matched
   (wrong amount + unrecognizable descriptor). The agent's fix: update the bill to
   $1,280 and record the bill payment against this charge. (The bill's due date is
   `W+0:Fri+7`, out of the beat-4 window, so it never appears in "pay bills due
   this week"; the agent resolves it here in beat 3.)
4. **Pay bills due this week (ACH + Wire, saved payees)** —
   overdue ≈ **$1,840** (DigitalOcean $300 ACH due `W-1:Mon`, Sutter Hill $560
   **wire** due `EOM-1`, Grant Henderson $980 ACH due `W-1:Fri`) + due-this-week
   ≈ **$910** (AWS $760 + Google Workspace $150, both ACH due `W+0:Fri`).
5. **Payroll shortfall** — Operating closes ≈ $23,000 at seed; after the beat-4
   bills clear (~$2,750) it sits at ≈ **$20,250**. Friday obligations ≈
   Gusto $3,600 + contractor cycle $17,380 = **$20,980** → a believable ~$730
   shortfall. Collectible AR =
   Alderbrook $4,800 + Mitsui half $2,100 = **$6,900** comfortably covers the gap
   → the natural move is "chase Alderbrook," **not raid the Reserve**. **Hallsten's
   $2,600 `W-1:Mon` bank credit is unrecorded in QBO (phantom) and must be excluded
   from collectible AR.**
   - **Mid-demo:** the presenter posts Alderbrook's live $4,800 deposit via
     `deposit_to_mock_account`, then "check again."
6. **Move money (closer)** — once payroll is secured, a modest **checking →
   savings** sweep (~$3,000): after Alderbrook, Operating ≈ $25,050 → ≈ $22,050,
   still clearing the ≈ $20,980 Friday payroll run. Placed AFTER the payroll beat
   on purpose — an earlier savings→checking transfer would erase the shortfall;
   moving surplus INTO the Reserve reinforces "the Reserve is for saving, not a
   payroll backstop."

## Reconciliation (standing discrepancies — keeps month-end-prep honest)

- **NorthPeak amount mismatch (beat #3):** the bank auto-debited the **renewed
  $1,280** annual rate under a cryptic descriptor, but QBO bill `PWD-BILL-0601`
  is still the **old $1,200** and **open/unpaid** (the payment never matched).
  This is the *fixable* reconciliation the agent demonstrates: update the bill to
  $1,280 and record the payment. Because it's an open bill, it adds **$1,200 to
  open AP** — so QBO **open AP seeds at $3,950** ($2,750 due-this-week + the
  $1,200 NorthPeak item). It is dated out of the beat-4 window and is resolved in
  beat 3, so the pay-bills ($2,750) and payroll beats are unaffected.
- **Interest credit (a):** a small current-week Reserve interest credit
  ($13.40) in the bank with **no QBO counterpart**.
- **Wire fee (b):** a tiny promo wire fee ($1.20) in the bank that QBO books as
  $0.00.
- The **Hallsten $2,600 phantom** is a deliberate, *large* discrepancy
  (received in bank, not recorded in QBO) — the bookkeeping beat, not "drama."

Per month: invoiced = payments received = bank client credits; bills paid = bank
debits. The current cycle is intentionally incomplete in QBO (Alderbrook open,
Hallsten unrecorded), which is the demo surface.

## Bank vs books scope (a documented compromise)

The **bank** carries a full **6 months** (so "categorize spending" is rich); the
**books** carry the current cycle in full plus `QBO_HISTORY_MONTHS` (2) recent
matched months — enough for month-end-prep, business-pulse, open AR/AP, and the
discrepancies — to keep the one-shot `seed_demo_books` within a sane number of
QBO API calls. See `paywhere-mcp/DEMO-COMPROMISES.md`. Bump `QBO_HISTORY_MONTHS`
for deeper books.

---

## Verification

`paywhere-mcp/paywhere-mcp-api` ships `npm test`
(`scripts/verify-demo.mjs`): the date engine against the worked example
(clamps, weekend roll-backs, drops, same-week determinism) and dataset
reconciliation (Operating closes at exactly $23,000 on many run dates, Reserve
≈ $20k, deposits precede withdrawals, posted rows byte-identical across the
week). Run it after any number change here.
