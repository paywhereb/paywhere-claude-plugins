---
name: demo-setup
version: 0.2.0
description: >
  Builds the entire canonical Paywhere SMB demo world in TWO tool calls — one to
  the paywhere-mock seeder (bank) and one to the QuickBooks seeder (books) — with
  all orchestration and date math done server-side. Use when the owner says "set
  up the demo," "reset the demo," "set up the sandbox," or "rebuild demo data."
  Replaces the old five demo-setup-* commands.
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
→ Preflight: paywhere-mock + Paywhere + quickbooks connectors all respond
→ Summarize what will happen + WAIT for approval (this REPLACES the demo world)
→ seed_demo_world {confirm:true}            (paywhere-mock)  → bank world + dateModel + creds
→ seed_demo_books {dateModel, confirm:true}  (quickbooks) → books on the same dates
→ VERIFY the Paywhere connector sees the seeded world (cross-connector readback)
→ Report balances, rows seeded, QBO created-vs-existing, open AR/AP, beats ready
```

> **The single most important invariant:** the **paywhere-mock** and **Paywhere**
> connectors must be signed in as the **same bank user**. They are separate OAuth
> connectors with separate tokens, but the bank world *and* the
> `get_transaction_detail` enrichment are keyed by the resolved **userId** (set by
> the bank-login username), not by the token. If the two connectors are signed in
> as different bank users, the seeder builds a world the Paywhere connector cannot
> see — balances read the wrong world and NorthPeak's `detail` comes back `null`.
> Step 5 below actively checks for this; do not skip it.

## Workflow

### 1. Preflight — connectors
Verify all three respond before touching anything; if any is missing, say which
and **stop** (a half-seed is worse than none):
- **paywhere-mock** (Demo Seeder) — e.g. `get_demo_world`
- **Paywhere** (the bank) — e.g. `list_accounts`
- **quickbooks** — e.g. `get_company_info`

Then confirm **paywhere-mock and Paywhere are the same bank user**. Call
`get_demo_world` (paywhere-mock) and `list_accounts` (Paywhere) and check the
**bank username / account numbers line up**. If they don't, **stop** and tell the
presenter to sign **both** connectors in as the *same* bank user before seeding —
seeding into a split pair produces a world the Paywhere connector can't see
(wrong balances, `null` NorthPeak detail). Re-doing OAuth on **either** connector
with different bank credentials reverts that connector to a different world, so
re-run this skill after any reconnect, and reconnect both connectors together.

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

### 5. Verify the Paywhere connector sees the seeded world (cross-connector readback)
**Do not trust the seeder's own numbers — read them back through the connector the
presenter will actually demo on.** `seed_demo_world` returns the world it *built*
(its `accounts[].accountNumber` + `closing` balances); confirm the **Paywhere**
connector reports the *same thing*:

1. Call **`list_accounts` on the Paywhere connector.** Assert the returned account
   numbers and balances **equal `seed_demo_world`'s `accounts` / `closing`** (demo
   accounts look like `9<userId×5><gen×2><seq×2>`, e.g. `9000250101`). A `7…` /
   different number or a wildly different balance (e.g. an inflated Reserve) means
   Paywhere is on a **different bank user** than the seeder.
2. Call **`get_transaction_detail` on the NorthPeak ACH debit** (the beat-3 row,
   ~ -$1,280, `ACH DEBIT NPA*ENRICH 8002231`). Assert `detail` is **non-null**.
   The bank row can be `found:true` while `detail` is `null` — that specifically
   means the connector's userId differs from the seeder's (enrichment is keyed by
   userId), even if the account numbers happen to match.

If **either** check fails, **STOP — do not report `beatsReady`** and tell the
presenter:
> ⚠️ The Paywhere connector is signed in as a different bank user than the seeder
> (it shows `<actual>`, expected `<seeded>`). Sign **both** connectors in as the
> same bank user (`<bankUsername>`) and re-run `/demo-setup` — don't re-auth just
> one.

### 6. Report
From the two responses, report:
- Closing **balances** (Operating ≈ $23k / Reserve ≈ $20k) **and the bank account
  numbers**, confirmed via the step-5 readback (not just the seeder's claim).
- QBO **created-vs-existing** counts, **open AR / AP**, and the DocNumber-persistence note.
- That the NorthPeak `get_transaction_detail` readback returned enrichment (beat 3 ready).
- Which beats are ready (the `beatsReady` list) and the live demo prompts live in
  [`../../../demo/demo-script.md`](../../../demo/demo-script.md).

## Edge cases
- **Split connectors** (step-5 readback mismatch): Paywhere shows different account
  numbers/balances than the seeder, or NorthPeak `get_transaction_detail` returns
  `found:true` but `detail:null`. The two connectors are signed in as different
  bank users → the Paywhere connector can't see the seeded world / enrichment. Sign
  **both** connectors in as the same bank user and re-run from the top. Re-authing
  only one connector (or as a *different* username, e.g. a `demo-<n>-g<m>` reset
  user instead of the original) is what causes this.
- **Half-seeded world** (a call fails midway): don't patch around unknown state —
  re-run `/demo-setup` from the top (a fresh generation orphans the broken world).
- **`seedStoppedAtIndex` is non-null** on `seed_demo_world`: the batch hit its
  time guard — re-run `/demo-setup` (idempotent reset makes this safe).
- **`seed_demo_books` reports `docNumberPersisted: false`**: the sandbox dropped
  custom DocNumbers; reset/dedupe falls back to `PrivateNote LIKE 'PWD-%'`
  (already written) — note it and continue.
- **`errorCount > 0`** on the books seed: report the `errors` sample; usually a
  missing chart-of-accounts ref (bank/income/expense) — confirm the sandbox has
  a checking, an income, and an expense account.
