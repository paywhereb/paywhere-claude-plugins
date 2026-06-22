---
name: demo-setup
version: 0.1.0
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
→ Report balances, rows seeded, QBO created-vs-existing, open AR/AP, beats ready
```

## Workflow

### 1. Preflight — connectors
Verify all three respond before touching anything; if any is missing, say which
and **stop** (a half-seed is worse than none):
- **paywhere-mock** (Demo Seeder) — e.g. `get_demo_world`
- **Paywhere** (the bank) — e.g. `list_accounts`
- **quickbooks** — e.g. `get_company_info`

Warn: re-doing OAuth on the Paywhere connector with different bank credentials
reverts the connector to the old world — re-run this after any reconnect.

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

### 5. Report
From the two responses, report:
- Closing **balances** (Operating ≈ $23k / Reserve ≈ $20k) and rows seeded/dropped.
- QBO **created-vs-existing** counts, **open AR / AP**, and the DocNumber-persistence note.
- Which beats are ready (the `beatsReady` list) and the live demo prompts live in
  [`../../../demo/demo-script.md`](../../../demo/demo-script.md).

## Edge cases
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
