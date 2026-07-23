---
name: demo-setup
version: 0.4.0
description: >
  Builds the caller's own Paywhere SMB demo bank world in ONE seeding call to
  the Paywhere connector's demo-seeder tools (present only on demo
  deployments), date-aligned to the standing QuickBooks demo books (shared,
  read-only, reseeded server-side daily — no books seeding here). Accepts an
  optional username label for the generated bank login. Use when the owner
  says "set up the demo," "reset the demo," "set up the sandbox," or "rebuild
  demo data."
---

# Demo Setup

Sets up the caller's own demo bank world (the **Meridian Staffing & Advisory**
persona, scaled ~0.30×). Everything — persona, amounts, recipients, date
resolution, the kept/dropped horizon — lives in **server code**, so this skill
just makes the calls and reports what came back. The QuickBooks books are
**shared and read-only**: they reseed server-side daily (5am ET) and are never
touched here — this skill only reads their `dateModel` so the bank world lands
on the same dates. Each runner gets an **isolated bank world**, so parallel
demos and re-runs are both fine. The numbers the seed produces are documented
in [`../../DATASET.md`](../../DATASET.md); do not hardcode any of them here.

## Arguments

- `username` (optional) — a friendly label folded into the generated bank
  username (`demo-<label>-<uid>-gN`). Sanitized server-side to lowercase
  letters/digits/hyphens, max 20 chars. It labels the caller's **own** world
  only — it cannot target anyone else's.

## Quick start

```
User: "set up the demo" (optionally: "… with username brett")
→ Preflight: Paywhere connector has the seeder tools; quickbooks responds
→ get_demo_dates (quickbooks, read-only) → {seeded, seededAt, dateModel}
  — seeded:false ⇒ the books haven't been seeded server-side yet: STOP
→ Summarize what will happen + WAIT for approval (this REPLACES the caller's
  own bank demo world; the shared books are untouched)
→ seed_demo_world {confirm:true, dateModel: <from get_demo_dates>, username?}
  (Paywhere) → bank world + creds; dateModelSource should be "provided"
→ VERIFY the seed landed (post-seed readback)
→ Report balances, bank username, dateModelSource, migratedFromSharedDemo,
  beats ready
```

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Preflight —
connectors"), then `TaskUpdate` it to `in_progress` when you begin that step
and `completed` when it's done. This is what drives Cowork's visible
progress display — it does not happen unless you do it explicitly, so
don't skip it just because the steps are already numbered here.

### 1. Preflight — connectors and the books' dates

First confirm this is a **demo deployment** — a free check, no tool call
needed: the Paywhere connector's tool list must include the demo-seeder tools
(`seed_demo_world` / `get_demo_world`). The seeder tools ride on the Paywhere
connector itself but are only registered on demo deployments. If they are
absent, this is **not** a demo deployment — **stop** and say so; never try to
seed a real Paywhere connector.

Then verify both connectors respond; if either is missing, say which and
**stop**:
- **Paywhere** (the bank) — e.g. `list_accounts`
- **quickbooks** — call **`get_demo_dates`** (read-only). This doubles as the
  liveness probe **and** fetches the alignment contract:
  - `{seeded: true, seededAt, dateModel}` → capture the `dateModel`
    **verbatim** — you pass it to `seed_demo_world` unchanged (this is what
    keeps the bank world on the same dates as the standing books).
  - `{seeded: false, …}` → the books haven't been seeded server-side yet
    (they reseed daily at 5am ET; a fresh deployment may still be on its
    first pass) — tell the user that and **stop**; a bank world seeded
    against unknown book dates would misalign every beat.

### 2. Approval gate

This **replaces the caller's own demo bank world** — a fresh generation with
fresh credentials; the shared QuickBooks books are read-only and untouched,
and other runners' worlds are unaffected. State that plainly and **wait for
explicit approval** before the call. (The tool also requires `confirm:true`.)
You do not need to resolve any dates — step 1's `dateModel` carries them. If
the user supplied a username label, confirm it here.

### 3. Seed the bank — `seed_demo_world {confirm:true, dateModel, username?}`

- Pass the step-1 `dateModel` **verbatim**, and the `username` label if the
  user gave one.
- **Surface the returned `bankUsername` / `bankPassword` PROMINENTLY** at the top
  of your reply — mock-only creds, shown once. If `slackNotified` is false, tell
  the user to record them now.
- Check `dateModelSource` in the response: it should be `"provided"` (the
  books' dates were used). `"computed"` means the server self-computed —
  possible only if no dateModel was passed; treat it as a bug in this run and
  re-run from step 1.
- Note `migratedFromSharedDemo`: `true` means this user had been browsing the
  shared read-only backdrop and now has their own world — worth a line in the
  report. The rotation takes effect on the next tool call.

### 4. Post-seed readback

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
3. Call **`list_saved_payees`.** Assert its count **equals
   `seed_demo_world`'s `recipientsConfigured`**, and spot-check
   **"Sutter Hill Properties"** comes back with `rail: "wire"` — a
   mismatch here is exactly the failure mode that makes `/pay-bills`
   misreport a saved wire payee as unresolved.

If **any** check fails, the seed didn't land — **STOP, do not report
`beatsReady`**, and re-run `/demo-setup` from the top (the idempotent reset
makes this safe). If it fails twice in a row, report the mismatch (expected vs
actual accounts/balances, the `null` NorthPeak detail, or the saved-payee
count/rail mismatch) instead of retrying further.

### 5. Report

From the responses, report:
- Closing **balances** (Operating ≈ $23k / Reserve ≈ $20k) **and the bank account
  numbers**, confirmed via the step-4 readback (not just the seeder's claim).
- The **bank username** (with the caller's label folded in, if supplied).
- **`dateModelSource: "provided"`** — the bank world is date-aligned to the
  standing books (quote `seededAt` from step 1 so the presenter knows how
  fresh the books are).
- **`migratedFromSharedDemo`**, if true: the caller just moved off the shared
  read-only backdrop onto their own world.
- That the NorthPeak `get_transaction_detail` readback returned enrichment (beat 3 ready).
- That the `list_saved_payees` readback matched `recipientsConfigured` (beat 4 ready).
- Which beats are ready (the `beatsReady` list) and the live demo prompts live in
  [`../../../demo/demo-script.md`](../../../demo/demo-script.md).

## Edge cases

- **Seeder tools absent from the Paywhere connector** (preflight): not a demo
  deployment — stop; this skill never runs against real accounts.
- **`get_demo_dates` says `seeded: false`**: the standing books haven't been
  seeded server-side yet — stop and say so (they reseed daily at 5am ET;
  check again later or ask whoever runs the QBO demo deployment). Never seed
  the bank against unknown book dates.
- **Demo-mutating tools refuse before the first seed** (e.g.
  `deposit_to_mock_account` erroring, or `get_demo_world` reporting
  `sharedEnvWorld: true`): the caller is still on the shared read-only
  backdrop — running this skill (their first `seed_demo_world`) is exactly
  the fix; the response will show `migratedFromSharedDemo: true`.
- **Username label rejected** (nothing sanitizable to lowercase
  letters/digits/hyphens ≤20 chars): re-run with a simpler label or none —
  the label is cosmetic; the world seeds the same without it.
- **Half-seeded world** (the call fails midway): don't patch around unknown state —
  re-run `/demo-setup` from the top (a fresh generation orphans the broken world).
- **Step-4 readback mismatch**: the seed didn't land (wrong balances/accounts,
  `null` NorthPeak detail, or a saved-payee count/rail mismatch) — re-run
  `/demo-setup`. Note that re-authorizing the connector with **old (pre-reset)
  credentials** points the session at an old world; re-run `/demo-setup` after
  any reconnect.
- **`seedStoppedAtIndex` is non-null** on `seed_demo_world`: the batch hit its
  time guard — re-run `/demo-setup` (idempotent reset makes this safe).
- **The books rotated mid-setup** (a 5am ET reseed between step 1 and step 3):
  vanishingly rare, but if the report's dates look off by a day, re-run from
  step 1 so a fresh `dateModel` is fetched.
