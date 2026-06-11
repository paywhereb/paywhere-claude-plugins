---
name: demo-setup-base
version: 0.1.0
description: >
  Resets and seeds the canonical Paywhere SMB demo world: a fresh mock-bank
  user with Operating Checking + Reserve Savings, ~3 months of date-relative
  bank history, and a mirrored QuickBooks sandbox seed for the Meridian
  Staffing & Advisory persona — two matched months, a deliberately incomplete
  current month (two classic reconciliation discrepancies, open AP, last
  week's client receipts), all resolved from today's actual date. Use when
  the owner says "set up the demo," "reset the demo," "set up the sandbox,"
  or "rebuild demo data."
---

# Demo Setup — Base

## Quick start

```
User: "set up the demo"
→ Preflight: paywhere-mock + Paywhere + quickbooks connectors all present
→ Resolve every date token against today (seed/date-tokens.md); render the
  token → date → kept/dropped table + seed plan summary
→ WAIT for approval — nothing is written before this
→ reset_demo (scenario "base", default accounts) → surface the new
  bankUsername/bankPassword PROMINENTLY
→ Seed the bank (seed/bank-manifest.md): 3 chunks ≤25 rows, deposits first
→ Seed QBO (seed/qbo-manifest.md): search-before-create, PWD- DocNumbers
→ Verify totals with query_transactions; report created-vs-existing
```

Everything seeded is governed by three canonical files — read them before
changing anything: [seed/date-tokens.md](seed/date-tokens.md) (the
date-relative convention every demo-setup skill follows),
[seed/persona.md](seed/persona.md) (Meridian Staffing & Advisory LLC — all
names, rates, rails), [seed/bank-manifest.md](seed/bank-manifest.md) and
[seed/qbo-manifest.md](seed/qbo-manifest.md) (the row-level seeds, which tie
out to the penny).

## What this seeds — and what it doesn't

Base gives every demo flow a believable shared world: matched months M-2 and
M-1, and a current month that is bank-complete but QBO-incomplete (the $43.17
interest credit with no QBO counterpart, the $1.20 wire-fee delta, an
unrecorded $8,500 client payment, $13,420 of open AP, and last week's client
receipts on all three inbound patterns). The flow-specific extensions —
`demo-setup-*` for /pay-bills, /pay-and-bill, /pay-commissions — layer their
own artifacts (registers, hour reports, marker history) **on top of** this
base; run base first, then the extension for the flow being demoed.

## Workflow

### 1. Preflight — connectors

Verify all three connectors respond before touching anything:
- **paywhere-mock** (Demo Seeder) — `get_demo_world`
- **Paywhere** (the bank) — `list_accounts`
- **quickbooks** — `get_company_info`

If any is missing, explain which one, what it's needed for, and **stop** — a
partial setup is worse than none (graceful degradation here means refusing to
half-seed).

Warn the user up front: **re-doing OAuth on the Paywhere connector with
different bank credentials reverts the connector to the old world.** After any
re-connect, run this setup again.

### 2. Resolve dates and present the plan — approval gate

Resolve every token in both manifests per
[seed/date-tokens.md](seed/date-tokens.md) (compute today → horizon Sunday →
resolve → clamp → weekend roll-back → drop post-horizon rows). Render:

1. The **resolved date table** — `token → concrete date → kept/dropped` for
   every distinct token used.
2. The **seed plan summary** — per-month row counts and credit/debit totals
   (recomputed from the *kept* rows), the QBO object counts, and anything
   found by the `PWD-%` pre-search (step 5).

**Wait for explicit approval before any write.** This run replaces the
caller's entire demo world — say so plainly.

### 3. Reset the demo world

Call `reset_demo` with `scenario: "base"` and a `summary` you compose
describing what's being seeded (persona name, horizon date, months covered,
the discrepancies, open AP) — this text goes into the Slack reset
notification. Omit `accounts`: the defaults (Operating Checking $50,000
primary + Reserve Savings $75,000) are exactly the persona's accounts.

Then:
- **Surface the returned `bankUsername` / `bankPassword` to the user
  PROMINENTLY** — top of your reply, clearly labeled. They are mock-only
  credentials; Slack/1Password is the bookkeeping home. If `slackNotified` is
  `false`, tell the user explicitly to record them now — they are shown once.
- The reset takes effect on the **next** tool call. Take the new account
  numbers from the `reset_demo` response (or `get_demo_world`) and map them to
  the Operating/Reserve **roles**. Never hardcode account numbers.

### 4. Seed the bank

Follow [seed/bank-manifest.md](seed/bank-manifest.md) exactly: three
`seed_transactions` chunks (M-2, M-1, M0-kept), each ≤25 rows, **all deposits
before all withdrawals within each chunk**, `stopOnError: true`. After every
chunk check `succeeded`/`failed` and **`stoppedAtIndex`**; on a partial stop,
fix the offending row and re-submit only the remaining rows (the tool is not
idempotent). Report per-chunk counts and closing `newBalance` values against
the manifest's closing check.

### 5. Seed QuickBooks

Follow [seed/qbo-manifest.md](seed/qbo-manifest.md):
- **Master data is idempotent**: `search_customers` / `search_vendors` /
  `search_items` by DisplayName first; create only what's missing
  (`create_customer`, `create-vendor`, `create_item` — note the hyphen in
  `create-vendor`). Never delete master data.
- **Prior demo transactions**: if the step-2 pre-search (`search_invoices`,
  `search_bills`, `search_payments`, `search_bill_payments`, `search_deposits`
  on DocNumber `PWD-%`) found leftovers, show them and — **only after
  approval** — delete in dependency order: payments → invoices, bill payments
  → bills, then deposits.
- Create in dependency order: invoices → payments → deposits; bills
  (`create-bill`) → bill payments. Apply the manifest's kept/dropped lockstep
  rule — a QBO mirror of a dropped bank row is not created.
- After the **first** invoice, read it back and verify the `PWD-` DocNumber
  persisted (see Edge cases) before creating the rest.

### 6. Verify and report

- `query_transactions` with `groupBy: "month"`: compare `sumCredits` /
  `sumDebits` per month against the totals recomputed from kept rows in step
  2 (full-seed expectations: M-2 credits 127,433.75 / debits 81,850.00; M-1
  credits 127,490.00 / debits 81,850.00; M0 credits 59,763.17 / debits
  14,451.20 — minus whatever the resolved table dropped).
- `list_accounts`: closing balances vs the manifest's closing check
  (full seed: Operating $96,291.97, Reserve $165,243.75).
- Report **created-vs-existing counts** for every QBO object class, and any
  rows dropped at the horizon.
- Close by reminding which flows are ready: the world now supports
  /business-pulse, /month-end-prep and friends out of the box, while
  **/pay-bills, /pay-and-bill, and /pay-commissions each need their own
  `demo-setup-*` extension run on top** of this base.

## Approval gates

- **Gate 1 (step 2):** no `reset_demo`, no seeding, no QBO write of any kind
  before the user approves the resolved date table + seed plan. One approval
  covers one run; changing the plan restarts the gate.
- **Gate 2 (step 5):** deleting prior `PWD-` transactions is approved
  separately and explicitly — show exactly what will be deleted first.
- Master data (customers/vendors/items) is never deleted, with or without
  approval.

## Edge cases — spell these out, don't guess

- **Half-seeded world** (failure between steps 3 and 6): don't patch around an
  unknown state — re-run `reset_demo` (a fresh generation orphans the broken
  world) and re-seed from the top. Cheap by design.
- **`seed_transactions` partial failure**: with `stopOnError: true`,
  `stoppedAtIndex` marks the failure point. Fix that row, re-submit only the
  remainder; re-submitting the whole chunk double-posts everything before the
  stop.
- **QBO sandbox DocNumber caveat**: sandboxes without "custom transaction
  numbers" enabled may silently replace custom DocNumbers. Verify once —
  after the first `PWD-` invoice, read it back; if the DocNumber didn't
  persist, warn the user that idempotency/reset will rely on `PrivateNote
  LIKE 'PWD-%'` instead, and write the `PWD-` id into every `PrivateNote`.
- **Early-month run** (today before the month's first Sunday): the horizon is
  still in the previous month, so **all `M0:dd` rows drop** — including both
  classic discrepancies — and `W-1` resolves into the previous month. The
  W-1 client receipts still seed, so payment-flow demos survive; tell the user
  the reconciliation discrepancies are absent until next week and offer to
  re-run setup then.
- **Mock ACH recipients are global and permanent** — `alreadyExisted: true`
  is normal, never an error. All payment flows use `recipientIdType:
  "Inline"`; nothing in this seed depends on a recipient registry.
- **Live "money just landed" moments** are demo-driven, not seed-driven: the
  demo script posts them mid-demo via `deposit_to_mock_account`
  ([seed/date-tokens.md](seed/date-tokens.md)). Never add such rows here.
- **Re-OAuth reverts the world** (see step 1) — after re-connecting the
  Paywhere connector, run setup again.

## Reference

- [seed/date-tokens.md](seed/date-tokens.md) — token grammar, the seed
  horizon, same-week determinism, the resolution algorithm.
- [seed/persona.md](seed/persona.md) — Meridian Staffing & Advisory LLC:
  accounts, clients, vendors, workers, commission payees, rates.
- [seed/bank-manifest.md](seed/bank-manifest.md) — every bank row, balance
  proofs, chunking mechanics.
- [seed/qbo-manifest.md](seed/qbo-manifest.md) — every QBO object, DocNumber
  scheme, reset procedure, cross-checks.
