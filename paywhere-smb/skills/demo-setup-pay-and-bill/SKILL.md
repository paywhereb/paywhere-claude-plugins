---
name: demo-setup-pay-and-bill
version: 0.1.0
description: >
  Seeds the /pay-and-bill demo on top of the base Meridian world: builds the
  local workers-register.xlsx (4 contractors with rates and ACH/Wire/
  Stablecoin rail details), creates one Drive hour note per worker for the
  last complete week (the W-1 period — hours not yet invoiced anywhere in the
  base seed), verifies the worker vendors and client customers in QuickBooks,
  and checks Devon's stablecoin recipient is verified. Layers on
  /demo-setup-base — run that first. Use when the owner says "set up the
  pay-and-bill demo" or "seed worker hours."
---

# Demo Setup — Pay and Bill

## Quick start

```
User: "set up the pay-and-bill demo"
→ Preflight: paywhere-mock + Paywhere + quickbooks + google drive respond;
  base world exists (get_demo_world + base QBO master data)
→ Resolve the W-1 tokens (seed/date-tokens.md); render token → date table
→ Pre-check: existing register file? existing hour notes? leftover PWD-PB-%?
→ Show the seed plan; WAIT for approval — nothing is written before this
→ Build workers-register.xlsx (4 Workers rows + empty PaidLog)
→ Create 4 Drive hour notes (search first — never duplicate)
→ Ensure worker vendors / client customers in QBO; verify Devon's wallet
→ Report created-vs-existing → "now run /pay-and-bill"
```

Everything seeded here is defined in
[seed/workers.md](seed/workers.md), which mirrors
[../demo-setup-base/seed/persona.md](../demo-setup-base/seed/persona.md)
(canonical names/rates/rails) and resolves dates per
[../demo-setup-base/seed/date-tokens.md](../demo-setup-base/seed/date-tokens.md).
The register schema and marker formats live in
[../pay-and-bill/DATA-MODEL.md](../pay-and-bill/DATA-MODEL.md).

## What this layers on base — and why

`/demo-setup-base` gives the world its bank history, clients, vendors (the 4
workers included), and the prior-cycle invoices. This extension adds only
what `/pay-and-bill` consumes: the **local register** and **last week's hour
reports**. The W-1 hours are deliberately un-invoiced in the base seed
([seed/workers.md](seed/workers.md), "Why these hours don't collide"), so a
first `/pay-and-bill` run creates fresh `PWD-PB-…` documents with no
collisions. No bank rows and no QBO transactions are seeded here — the money
movement *is* the demo, performed live by `/pay-and-bill`.

## Workflow

### 1. Preflight — connectors and the base world

Verify all four connectors respond:
- **paywhere-mock** — `get_demo_world` (also returns the world's accounts)
- **Paywhere** — `list_accounts`
- **quickbooks** — `get_company_info`
- **google drive** — a trivial `search_files` probe

Then check the base world is actually seeded: `get_demo_world` shows the
Operating/Reserve accounts and `search_customers` finds the persona clients
(e.g. Thames Fintech Ltd). If either is missing, offer to run
`/demo-setup-base` first and **stop** — this extension has nothing to layer
onto an empty world. If only Drive is missing, see Edge cases
(inline-paste demo mode).

### 2. Resolve dates — render the table

Resolve `W-1:Mon` … `W-1:Fri` (and the period's Sunday = the horizon) from
today's actual date per
[../demo-setup-base/seed/date-tokens.md](../demo-setup-base/seed/date-tokens.md),
and render the `token → concrete date` table. `W-1` rows are never dropped by
construction. The resolved `W-1:Mon` ISO date is the **period key** used in
filenames and (later, by `/pay-and-bill`) in the `PWD-PB-…` markers.

### 3. Pre-check and present the seed plan — approval gate

Pre-checks (read-only):
- `workers-register.xlsx` already in the working folder? Read it and diff
  its `Workers` rows against [seed/workers.md](seed/workers.md).
- `search_files` for each `Hours - {Worker} - Week of {W-1:Mon}` note.
- `search_vendors` for the 4 workers; `search_customers` for the 4 placement
  clients.
- `get_stablecoin_recipient` for Devon's wallet (address in seed/workers.md).
- `search_invoices` / `search_bills` for `PWD-PB-%` — leftovers from a prior
  `/pay-and-bill` run would make the demo open with "already processed" rows.

Show the plan: the date table, the 4 register rows, the 4 note names, what
already exists, and the expected demo numbers ($18,460 invoiced / $14,200
pay + $27.00 fee, per seed/workers.md). **Wait for explicit approval before
any write.** If `PWD-PB-%` leftovers were found, offer cleanup under its own
separate approval (delete in dependency order: payments → invoices, bill
payments → bills).

### 4. Build `workers-register.xlsx` — idempotent

Write the workbook in the session working folder with Python (`openpyxl`):
`Workers` sheet rows exactly per [seed/workers.md](seed/workers.md), plus an
**empty `PaidLog`** (header row only). If the file already exists: show the
step-3 diff and ask before changing anything — and **never drop existing
`PaidLog` rows** (they are the demo's dedupe history).

### 5. Create the Drive hour notes — never duplicate

For each worker whose note wasn't found in step 3, `create_file` with the
filename and body template from [seed/workers.md](seed/workers.md), dates
resolved per step 2. Notes that already exist are reported as existing and
left untouched.

### 6. Ensure QBO master data

- **Worker vendors**: `search_vendors` by DisplayName for Priya Raman, Marcus
  Webb, Elena Sorokina, Devon Okafor — the base seed normally created them;
  `create-vendor` (note the hyphen) only for any that are missing. Never
  delete master data.
- **Client customers**: `search_customers` for Thames Fintech Ltd, Zurich
  Dynamics AG, Alderbrook Ventures LLC, Mitsui Digital KK. These belong to
  the base seed — if any is missing, **report it and point at
  `/demo-setup-base`** rather than creating it here.

### 7. Verify Devon's stablecoin recipient

`get_stablecoin_recipient` for the wallet in
[seed/workers.md](seed/workers.md): if the record exists and is **VERIFIED**,
done. If missing, `create_stablecoin_recipient` with the wallet/walletOwner
block from seed/workers.md, then re-check status — if not yet verified, tell
the owner `/pay-and-bill` will exclude Devon until it is. Note the design:
this POLY test wallet is **intentionally shared with CryptoConsult DAO**
(persona.md) — one recipient record serves both `/pay-and-bill` and
`/pay-commissions`; whichever flow registered it first owns the display
details, and all either flow needs is VERIFIED.

### 8. Report and hand off

Report **created-vs-existing** for every artifact class: register
(created / diffed / unchanged), each hour note, each vendor, the customer
check, and the recipient status. Close with the expected `/pay-and-bill`
outcome (4 reports → 4 invoices $18,460 → one mixed-rail batch $14,200 +
$27.00 fee → 4 bills) and tell the owner: **run `/pay-and-bill`**.

## Approval gates

- **Gate (step 3)**: no file write, no Drive note, no QBO or Paywhere write
  before the plan is approved. One approval covers one run; changing the
  plan restarts the gate.
- **Cleanup of leftover `PWD-PB-%` transactions** is approved separately and
  explicitly, with the exact list shown first.
- Master data (customers/vendors) is never deleted, with or without approval.

## Edge cases — spell these out, don't guess

- **Drive connector missing**: offer **inline-paste demo mode** — skip the
  notes, seed everything else, and have the demo run `/pay-and-bill` with
  hours pasted inline (that skill echoes pasted hours back for confirmation).
  Say plainly that the Drive path of the demo won't be shown.
- **World reset since last setup**: the register (local file) and the Drive
  notes survive a `reset_demo`; the bank and its account numbers do not, and
  the QBO seed may have been cleaned. Re-run `/demo-setup-base`, then re-run
  this skill — it is idempotent, so surviving artifacts are reported as
  existing, not duplicated. Nothing in the register depends on the world's
  account numbers (the source account is discovered at run time via
  `list_accounts`).
- **Early-month run**: `W-1` can resolve into the previous month — that is
  correct, not a bug; the notes and period key simply carry last week's
  actual dates (same-week determinism per date-tokens.md).
- **Note exists with different hours** (someone edited it): report the
  difference; only overwrite with approval.
- **Leftover `PWD-PB-%` markers**: see step 3 — offer cleanup, or leave them
  and warn that `/pay-and-bill` will (correctly) report that period as
  already processed; the demo can instead target another period.

## Reference

- [seed/workers.md](seed/workers.md) — register rows, hour-note templates,
  the W-1 arithmetic, the no-collision rationale.
- [../pay-and-bill/SKILL.md](../pay-and-bill/SKILL.md) and
  [../pay-and-bill/DATA-MODEL.md](../pay-and-bill/DATA-MODEL.md) — the flow
  this seed feeds.
- [../demo-setup-base/SKILL.md](../demo-setup-base/SKILL.md) and its
  [seed/persona.md](../demo-setup-base/seed/persona.md) /
  [seed/date-tokens.md](../demo-setup-base/seed/date-tokens.md) — the
  canonical world and date convention.
