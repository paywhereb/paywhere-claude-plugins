---
name: demo-setup-commissions
version: 0.1.0
description: >
  Layers the /pay-commissions demo onto demo-setup-base: builds the local
  commission register (commission-register.xlsx — Customers, ACH, Wire,
  Stablecoin, PaidLog sheets), confirms last week's qualifying bank credits
  and their QuickBooks payment mirrors, ensures the three commission payee
  vendors and a VERIFIED stablecoin recipient exist, and pre-seeds exactly
  one already-paid marker so the very first /pay-commissions run demos
  dedupe. Use when the owner says "set up the commission demo," "set up
  commissions," or "reset commission data."
---

# Demo Setup — Commissions

## Quick start

```
User: "set up the commission demo"
→ Preflight: paywhere-mock + Paywhere + quickbooks; confirm the base world
  is seeded (get_demo_world, then query_transactions for last week's
  qualifying credits)
→ Resolve the W-1 tokens per ../demo-setup-base/seed/date-tokens.md; show
  the full plan: register contents, payee vendors, the one pre-seeded
  dedupe marker, the stablecoin recipient
→ WAIT for approval — nothing is written before this
→ Build commission-register.xlsx in the session working folder with Bash +
  Python (openpyxl) — search for an existing file first
→ QBO: search_vendors for the 3 payees; create-vendor only what's missing
→ Verify the W-1 QBO payments (PWD-PAY-0301/0302/0303) exist — report,
  never duplicate
→ Pre-seed ONE already-paid marker: a COMM-{id} Bill + Bill Payment plus
  the matching PaidLog row
→ get_stablecoin_recipient for CryptoConsult DAO's wallet; create if
  missing; confirm VERIFIED
→ Report created-vs-existing; close with: run /pay-commissions "last week"
  — a second run demos dedupe
```

## What this layers on the base — and the numbers that must tie out

Run [/demo-setup-base](../demo-setup-base/SKILL.md) **first**: it seeds the
qualifying last-week credits, their QBO payment mirrors, and the three
commission payees as QBO vendors. This skill adds only the
commission-specific artifacts — the local register, the dedupe pre-seed,
and the verified stablecoin recipient. All names, rates, rails, and payee
payment details come from
[../demo-setup-base/seed/persona.md](../demo-setup-base/seed/persona.md)
(the single source of truth — never improvise alternatives).

The demo surface after this skill runs:

| W-1 credit (bank + QBO mirror) | Gross | Rate | Commission | Payee | Rail |
|---|---|---|---|---|---|
| Thames Fintech Ltd wire (PWD-PAY-0301) | $20,800.00 | 5% | $1,040.00 | Jane Doe Referrals | ACH |
| Zurich Dynamics AG wire (PWD-PAY-0302) | $23,400.00 | 10% | $2,340.00 | Acme Sales Partners LLC | Wire |
| Mitsui Digital KK wire, partial 1/2 (PWD-PAY-0303) | $7,020.00 | 10% | $702.00 (+1% fee $7.02) | CryptoConsult DAO | Stablecoin |

Total W-1 commission base: **$1,040 + $2,340 + $702 = $4,082**. The Thames
row is pre-seeded as already paid (step 5), so the **first**
/pay-commissions run shows one "already paid" row and disburses **$3,042**
($2,340 wire + $702 stablecoin, plus the $7.02 stablecoin fee surfaced by
the batch dry-run); a **second** run reports all three "already paid" —
that is the dedupe demo.

Two deliberate negative-space rows — do **not** "fix" either:

- **Hallsten & Berg's $8,500 W-1 credit** is in the bank but has no QBO
  payment and no register row. Over a "last week" range it demos the
  **unmatched-credit** list (credit with no QBO payment); over a prior
  month, where the Hallsten payment (PWD-PAY-0101 / PWD-PAY-0201) *is*
  recorded, it demos the **skip path**
  (matched customer not in the register). Don't record the payment and
  don't add Hallsten to the register.
- **CryptoConsult DAO shares the primary POLY test wallet with worker
  Devon Okafor by design** (persona.md — only a handful of verified test
  wallets exist). Never "deduplicate" the wallet.

## Workflow

### 1. Preflight — connectors and the base world

Verify the three connectors respond:
- **paywhere-mock** (Demo Seeder) — `get_demo_world`
- **Paywhere** (the bank) — `list_accounts`
- **quickbooks** — `get_company_info`

If one is missing, see Graceful degradation below — say exactly what will
be skipped instead of silently half-working.

Then confirm the base world looks seeded: take the account numbers from
`get_demo_world` (never hardcode them) and run `query_transactions` with
`direction: "credit"`, `status: ["posted"]`, `includeTransactions: true`,
and `dateFrom`/`dateTo` set to the resolved `W-1:Mon`…`W-1:Fri` range
(step 2). Expect the three qualifying wires (Thames $20,800, Zurich
$23,400, Mitsui $7,020) plus the Hallsten $8,500 ACH-style credit. When
day 2 of the current month falls inside W-1, the $43.17 `M0:02` interest
credit (bank-manifest discrepancy (a)) also appears — expected, leave it.

**If the qualifying credits are missing** (base never ran, or the world
was re-reset), offer two paths:
1. **Run /demo-setup-base first** (recommended — it also restores the QBO
   payment mirrors this demo matches against), then re-run this skill.
2. **Top up just the commission-relevant rows** — the four W-1 deposit
   rows from
   [../demo-setup-base/seed/bank-manifest.md](../demo-setup-base/seed/bank-manifest.md)
   (W-1:Mon Hallsten ACH-style credit, W-1:Tue Thames wire, W-1:Wed Zurich
   wire, W-1:Thu Mitsui partial wire) via one `seed_transactions` call
   (≤25 items, deposits only, `stopOnError: true`, check
   `stoppedAtIndex`). **Approval-gated** (Gate 2). Warn that this restores
   the bank side only: if step 4 finds the QBO mirrors missing too, the
   matched-payment demo still needs base's QBO seed.

### 2. Resolve dates and present the plan — approval gate

This skill uses only `W-1:*` tokens (plus `W-1:Fri` for the pre-seeded
marker date). Resolve them per
[../demo-setup-base/seed/date-tokens.md](../demo-setup-base/seed/date-tokens.md)
(today → horizon Sunday → resolve; `W-1` rows are never dropped, so this
demo survives early-month runs). Render the token → concrete date table,
then the full plan:

- the planned register contents (step 3 tables) — or the diff against an
  existing file;
- payee vendors to create vs already existing;
- the one dedupe marker to pre-seed (which payment, DocNumber, amounts);
- the stablecoin recipient to verify or create;
- any bank top-up from step 1.

**Wait for explicit approval before any write** — local file, QBO, or
bank. One approval covers one run; changing the plan restarts the gate.

### 3. Build the local register — `commission-register.xlsx`

Search the session working folder for an existing `commission-register.xlsx`
first (by filename; if several match, list them and ask). The build is
**idempotent**:

- **File exists, config sheets identical** to the plan → leave it
  untouched; report "existing, unchanged". Existing `PaidLog` rows are
  history — never diffed away.
- **File exists, rows differ** → show the diff and ask before overwriting
  (Gate: register overwrite). On approval, rebuild the four config sheets
  and **preserve the existing PaidLog rows** unless the owner explicitly
  asks for a reset.
- **No file** → create it with Bash + Python (openpyxl or an equivalent
  xlsx library; `pip install openpyxl` if absent).

One workbook, five sheets, exact columns per
[../pay-commissions/DATA-MODEL.md](../pay-commissions/DATA-MODEL.md).
Rates and amounts are written as numbers, not strings.

**Sheet `Customers`** — the commission map from persona.md (Hallsten &
Berg deliberately absent):

| Customer | CommissionRate | Payee | Rail |
|---|---|---|---|
| Thames Fintech Ltd | 0.05 | Jane Doe Referrals | ACH |
| Alderbrook Ventures LLC | 0.05 | Jane Doe Referrals | ACH |
| Zurich Dynamics AG | 0.10 | Acme Sales Partners LLC | Wire |
| Mitsui Digital KK | 0.10 | CryptoConsult DAO | Stablecoin |

**Sheet `ACH`** — header `Payee | RecipientName | ABA | AccountNumber |
AccountType | Email`; one row for **Jane Doe Referrals**, values verbatim
from persona.md § Commission payees.

**Sheet `Wire`** — header `Payee | RecipientName | RecipientAccount |
RecipientAddr1 | City | State | PostalCode | BankName | BankABA`; one row
for **Acme Sales Partners LLC**, values verbatim from persona.md
(`BankABA` is the recipient bank's **aba** — the wire API takes `aba`, not
`routingNumber`).

**Sheet `Stablecoin`** — header `Payee | WalletAddress | Chain |
Currency`; one row for **CryptoConsult DAO**: the primary POLY wallet from
persona.md, chain `POLY`, currency `USD`.

**Sheet `PaidLog`** — header only at build time: `Date | Customer |
QBOPaymentId | GrossAmount | Rate | Commission | Payee | Rail |
PaywherePaymentId | QBOBillId`. Step 5 appends exactly one row.

Show the workbook contents you actually wrote in the final report.

### 4. QBO payees and payment history

**Vendors** — `search_vendors` by DisplayName for the three payees (Jane
Doe Referrals, Acme Sales Partners LLC, CryptoConsult DAO). Base seeds all
three, so "existing" is the normal result; **`create-vendor`** (note the
hyphen) only what's missing. Payment details (ABA, account, wallet) live
**only in the register, never on the vendor record**. Vendors are never
deleted.

**Payment history** — `search_payments` for the W-1 mirrors seeded by
base's [qbo-manifest.md](../demo-setup-base/seed/qbo-manifest.md):
`PWD-PAY-0301` (Thames), `PWD-PAY-0302` (Zurich), `PWD-PAY-0303` (Mitsui)
— DocNumber `LIKE`, falling back to `PrivateNote LIKE` where DocNumbers
didn't persist. Record each QBO Payment **Id** (the entity id — the
dedupe key). **Report found-vs-missing; never create payments here** — if
any is missing, the fix is re-running /demo-setup-base's QBO seed, not
duplicating it from this skill.

### 5. Pre-seed the dedupe marker — one "already paid" row

So the **first** /pay-commissions run already demos dedupe. The chosen
row is **Thames Fintech Ltd / PWD-PAY-0301** ($20,800 × 5% = $1,040 to
Jane Doe Referrals) — deliberately the ACH row, so the Wire and Stablecoin
rails (including the 1% fee preview, the batch dry-run showpiece) stay
live for the first run.

After Gate 1 approval:

1. Take `{qboPaymentId}` = the QBO Payment Id discovered for PWD-PAY-0301
   in step 4 (never hardcoded — Ids change on every base re-seed).
2. **Idempotency check**: `search_bills` for `DocNumber LIKE 'COMM-%'`.
   - A marker for this Id already exists → report "existing", skip
     creation.
   - **Stale markers** (COMM- Ids matching no current PWD-PAY payment —
     leftovers from a previous world generation) → list them and offer a
     separately approved cleanup (Gate 3): `delete_bill_payment` first,
     then **`delete-bill`**.
3. **`create-bill`** against vendor Jane Doe Referrals: TxnDate = the
   resolved `W-1:Fri`; one line of **$1,040.00** to a commission-expense
   account (`search_accounts`; ask the owner which if ambiguous);
   `DocNumber: COMM-{qboPaymentId}`; `PrivateNote: Commission on QBO
   payment {qboPaymentId} for Thames Fintech Ltd @ 0.05 — Paywhere ACH ref
   DEMO-SEED (pre-seeded by /demo-setup-commissions; no bank
   disbursement)` — the format from
   [../pay-commissions/DATA-MODEL.md](../pay-commissions/DATA-MODEL.md),
   with the sentinel `DEMO-SEED` where a real Paywhere payment id would
   go. **No money moves for the pre-seed** — the bank manifest has no
   matching debit, and that is correct.
4. `create_bill_payment` paying that bill in full, same date.
5. Append the matching `PaidLog` row to the xlsx (skip if a row for this
   `QBOPaymentId` is already present):
   `{resolved W-1:Fri} | Thames Fintech Ltd | {qboPaymentId} | 20800.00 |
   0.05 | 1040.00 | Jane Doe Referrals | ACH | DEMO-SEED | {billId}`.

Both dedupe signals (QBO marker + PaidLog) now agree, exactly as a real
/pay-commissions run would have left them.

### 6. Stablecoin recipient — must be VERIFIED

/pay-commissions refuses to pay an unverified wallet, so verify now:

1. `get_stablecoin_recipient` with the `WalletAddress` from the register's
   Stablecoin sheet (CryptoConsult DAO — the primary POLY wallet per
   persona.md).
2. If missing, `create_stablecoin_recipient` (covered by Gate 1):
   `wallet: {address: <that wallet>, chain: "POLY", currency: "USD"}`,
   `walletOwner: {type: "Business", name: "CryptoConsult DAO", address:
   <any plausible mock US business address — e.g. 548 Market St, San
   Francisco, CA 94104; mock-only>}`, `description: "Commission payee —
   CryptoConsult DAO (demo)"`.
3. Re-check with `get_stablecoin_recipient` and confirm **VERIFIED**. An
   already-existing recipient is normal — the wallet is shared with Devon
   Okafor, so /demo-setup-pay-and-bill may have registered it first.

If verification is still pending, see Edge cases.

### 7. Verify and report

- Re-run the step-1 `query_transactions` check and confirm the three
  qualifying credits total **$51,220** gross → **$4,082** commission base.
- Report **created-vs-existing** per artifact: register file
  (created / updated / unchanged), each payee vendor, the marker Bill +
  Bill Payment, the PaidLog row, the stablecoin recipient (+ its
  verification status), and any bank top-up rows.
- Close with the run instructions: tell the owner to run
  **`/pay-commissions "last week"`** — expect two payable rows ($2,340
  wire + $702 stablecoin with the $7.02 fee), one "already paid" row
  ($1,040 Thames), and Hallsten's $8,500 in the unmatched-credits list —
  and that **a second run demos dedupe** (all three rows report "already
  paid"). Date-dependent extras (both legitimate, identical Mon–Fri of
  the same week): when day 2 of the month falls inside W-1, the $43.17
  interest credit joins the unmatched list; on an early-month run, see
  the "Early-month run" edge case — a third payable row appears.

## Approval gates

- **Gate 1 (step 2):** no register write, QBO write, or stablecoin
  recipient creation before the owner approves the resolved-date table +
  full plan. One approval covers one run; changing the plan restarts the
  gate.
- **Gate 2 (step 1):** topping up missing bank credits via
  `seed_transactions` is approved separately and explicitly.
- **Gate 3 (step 5):** deleting stale `COMM-` markers is approved
  separately — show exactly what will be deleted first.
- **Register overwrite (step 3):** an existing file with different rows is
  never overwritten without showing the diff and getting a yes.
- Vendors (and all QBO master data) are never deleted, with or without
  approval.

## Edge cases — spell these out, don't guess

- **Register file already exists with different rows** — show a
  sheet-by-sheet diff (planned vs found) and ask. Overwrite rebuilds the
  config sheets only; PaidLog history is preserved unless the owner asks
  for a reset. Multiple matching files → list and ask, never pick one
  silently.
- **Stablecoin verification pending** — everything else still seeds; tell
  the owner the stablecoin rail is blocked until the recipient shows
  VERIFIED, to re-check later with `get_stablecoin_recipient` (or re-run
  this step), and that /pay-commissions will refuse that row — not the
  whole run — in the meantime.
- **World was reset after setup** — the local register survives, but the
  bank credits and (after a base re-seed) the QBO history do not, and the
  new PWD-PAY Ids differ. Re-run /demo-setup-base, then this skill: it
  detects the stale `COMM-{oldId}` markers (step 5.2) and offers cleanup,
  re-seeds the marker against the new Id, and appends a fresh PaidLog row.
  Old PaidLog rows referencing dead Ids are harmless to dedupe but
  misleading — flag them and offer a PaidLog reset rather than deleting
  silently (the log is append-only by contract).
- **`COMM-` markers are not swept by base's reset** — base's reset
  procedure searches `PWD-%` only, so this skill owns the `COMM-`
  lifecycle (step 5.2 / Gate 3).
- **W-1 QBO payments missing in step 4** — never fabricate them here;
  point at /demo-setup-base. A bank-only top-up (step 1, path 2) is not a
  substitute for the QBO mirrors.
- **Early-month run** — `W-1` rows never drop
  ([date-tokens.md](../demo-setup-base/seed/date-tokens.md)), so the
  qualifying credits always exist. But before the month's first Sunday,
  W-1 resolves into the previous month and overlaps base's late-`M-1`
  rows: "last week" then also captures the Alderbrook `M-1:26` credit
  ($15,600 × 0.05 = a **third payable row of $780**, total disbursed
  $3,822 + $7.02 fee — genuinely owed in-world, not a bug) and the
  `EOM-1` Reserve interest ($150) as a **second unmatched credit**. Tell
  the presenter, or scope the demo range to the three wire days.
- **openpyxl missing** — install it (`pip install openpyxl`) or use any
  equivalent xlsx library; the workbook format is the contract, not the
  library.

## Graceful degradation

- **No paywhere-mock** — cannot top up missing bank credits; the register,
  QBO artifacts, and stablecoin verification still proceed. If step 1
  found the credits missing, say plainly that the demo is incomplete until
  base re-runs.
- **No Paywhere** — skip the credit verification (step 1) and the
  stablecoin recipient work (step 6); build the register and QBO artifacts
  only, and warn that /pay-commissions needs the Paywhere connector to
  match and pay anything.
- **No quickbooks** — build the register only; vendors, payment-history
  verification, and the dedupe pre-seed are all skipped. Say exactly which
  steps were skipped — never silently half-seed.

## Reference

- [../demo-setup-base/seed/persona.md](../demo-setup-base/seed/persona.md)
  — commission payees (rails + full payment details) and the commission
  map; the single source of truth for every value in the register.
- [../demo-setup-base/seed/date-tokens.md](../demo-setup-base/seed/date-tokens.md)
  — token grammar, horizon, same-week determinism.
- [../demo-setup-base/seed/bank-manifest.md](../demo-setup-base/seed/bank-manifest.md)
  — the W-1 credit rows (the top-up source).
- [../demo-setup-base/seed/qbo-manifest.md](../demo-setup-base/seed/qbo-manifest.md)
  — PWD-PAY-0301/0302/0303 and the PWD- DocNumber scheme.
- [../pay-commissions/DATA-MODEL.md](../pay-commissions/DATA-MODEL.md) —
  register sheet schemas, dedupe markers, tool signatures.
