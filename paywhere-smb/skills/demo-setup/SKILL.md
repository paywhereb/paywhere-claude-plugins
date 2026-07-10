---
name: demo-setup
version: 0.3.0
description: >
  Builds the entire canonical Paywhere SMB demo world in TWO tool calls — one to
  the Paywhere connector's demo-seeder tools (present only on demo deployments)
  and one to the QuickBooks seeder (books) — with all orchestration and date
  math done server-side. Use when the owner says "set up the demo," "reset the
  demo," "set up the sandbox," or "rebuild demo data." Replaces the old five
  demo-setup-* commands.
---

# Demo Setup

Sets up the shared demo world (the **Meridian Staffing & Advisory** persona,
scaled ~0.30×) end to end. Everything — persona, amounts, recipients, date
resolution, the kept/dropped horizon — lives in **server code**, so this skill
just makes two calls and reports what came back. The numbers it produces are
documented in [`../../DATASET.md`](../../DATASET.md); do not hardcode any of
them here.

## Quick start

```
User: "set up the demo"
→ Preflight: Paywhere (with seeder tools) + quickbooks connectors respond
→ Summarize what will happen + WAIT for approval (this REPLACES the demo world)
→ seed_demo_world {confirm:true}            (Paywhere)   → bank world + dateModel + creds
→ seed_demo_books {dateModel, confirm:true}  (quickbooks) → books on the same dates
→ VERIFY the seed landed (post-seed readback)
→ Report balances, rows seeded, QBO created-vs-existing, open AR/AP, beats ready
```

## Workflow

### 1. Preflight — connectors
First confirm this is a **demo deployment** — a free check, no tool call
needed: the Paywhere connector's tool list must include the demo-seeder tools
(`seed_demo_world` / `get_demo_world`). The seeder tools ride on the Paywhere
connector itself but are only registered on demo deployments. If they are
absent, this is **not** a demo deployment — **stop** and say so; never try to
seed a real Paywhere connector.

Then verify both connectors respond before touching anything; if either is
missing, say which and **stop** (a half-seed is worse than none):
- **Paywhere** (the bank) — e.g. `list_accounts`
- **quickbooks** — e.g. `get_company_info`

### 2. Approval gate
This **replaces the caller's entire demo world**. State that plainly and **wait
for explicit approval** before either call. (Both tools also require
`confirm:true`.) You do not need to resolve any dates — the server does.

### 3. Seed the bank — `seed_demo_world {confirm:true}`
- **Surface the returned `bankUsername` / `bankPassword` PROMINENTLY** at the top
  of your reply — mock-only creds, shown once. If `slackNotified` is false, tell
  the user to record them now.
- **Capture `dateModel` verbatim** from the response — you pass it to the books
  seed unchanged. The rotation takes effect on the next tool call.

### 4. Seed the books — `seed_demo_books {dateModel, confirm:true}`
- Pass the `dateModel` from step 3 **verbatim** (this is what keeps bank and
  books on identical dates). No token or secret is needed.

### 5. Post-seed readback
**Do not trust the seeder's own numbers — read them back through the same
connector the presenter will demo on.** `seed_demo_world` returns the world it
*built* (its `accounts[].accountNumber` + `closing` balances); confirm the
connector reports the *same thing*:

1. Call **`list_accounts`.** Assert the returned account numbers and balances
   **equal `seed_demo_world`'s `accounts` / `closing`** (demo accounts look like
   `9<userId×5><gen×2><seq×2>`, e.g. `9000250101`).
2. Call **`get_transaction_detail` on the NorthPeak ACH debit** (the beat-3 row,
   ~ -$1,280, `ACH DEBIT NPA*ENRICH 8002231`). Assert `detail` is **non-null**
   (the enrichment write is part of the seed).

If **either** check fails, the seed didn't land — **STOP, do not report
`beatsReady`**, and re-run `/demo-setup` from the top (the idempotent reset
makes this safe). If it fails twice in a row, report the mismatch (expected vs
actual accounts/balances, or the `null` NorthPeak detail) instead of retrying
further.

### 6. Report
From the two responses, report:
- Closing **balances** (Operating ≈ $23k / Reserve ≈ $20k) **and the bank account
  numbers**, confirmed via the step-5 readback (not just the seeder's claim).
- QBO **created-vs-existing** counts, **open AR / AP**, and the DocNumber-persistence note.
- That the NorthPeak `get_transaction_detail` readback returned enrichment (beat 3 ready).
- Which beats are ready (the `beatsReady` list) and the live demo prompts live in
  [`../../../demo/demo-script.md`](../../../demo/demo-script.md).

## Edge cases
- **Seeder tools absent from the Paywhere connector** (preflight): not a demo
  deployment — stop; this skill never runs against real accounts.
- **Half-seeded world** (a call fails midway): don't patch around unknown state —
  re-run `/demo-setup` from the top (a fresh generation orphans the broken world).
- **Step-5 readback mismatch**: the seed didn't land (wrong balances/accounts or
  `null` NorthPeak detail) — re-run `/demo-setup`. Note that re-authorizing the
  connector with **old (pre-reset) credentials** points the session at an old
  world; re-run `/demo-setup` after any reconnect.
- **`seedStoppedAtIndex` is non-null** on `seed_demo_world`: the batch hit its
  time guard — re-run `/demo-setup` (idempotent reset makes this safe).
- **`seed_demo_books` reports `docNumberPersisted: false`**: the sandbox dropped
  custom DocNumbers; reset/dedupe falls back to `PrivateNote LIKE 'PWD-%'`
  (already written) — note it and continue.
- **`errorCount > 0`** on the books seed: report the `errors` sample; usually a
  missing chart-of-accounts ref (bank/income/expense) — confirm the sandbox has
  a checking, an income, and an expense account.
