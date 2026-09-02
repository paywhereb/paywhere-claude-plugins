---
name: demo-setup
version: 1.0.1
description: >
  Builds the presenter's own Nick's HVAC demo bank world on the Paywhere
  connector's demo-seeder tools (present only on demo deployments):
  preflight, one approval, an ASYNC seed job polled to completion, then a
  readback that asserts balances, saved payees and enrichment through the
  same connector the demo runs on, and reports the answer-key summary (true
  available cash, reserve shortfall, largest overdue, bills due this week,
  Friday payroll). Date-aligned to the shared read-only QuickBooks books via
  get_demo_dates. Presenter use only. Use when someone says "set up the
  demo," "reset the demo," "seed the demo world," "rebuild the sandbox," or
  "/demo-setup."
---

# Demo Setup (Act 0)

Sets up the caller's own demo bank world for the **Nick's HVAC** persona.
Everything about the world — roster, amounts, dates, payees, enrichment, the
answer key — lives in **server code** (`buildWorld(dateModel)` in
paywhere-mcp); this skill makes the calls, waits for the job, checks the
result and reports. The QuickBooks books are **shared and read-only**
(reseeded server-side daily) and are never touched here; their `dateModel` is
read so the bank lands on the same dates. Each presenter gets an isolated
bank world, so parallel demos and re-runs are fine. What the world contains
is described qualitatively in [`../../DATASET.md`](../../DATASET.md); never
hardcode any of it here — read it back.

## Arguments

- `username` (optional) — a label folded into the generated bank login
  (`demo-<label>-<uid>-gN`; sanitized server-side to lowercase
  letters/digits/hyphens, max 20 chars). Labels the caller's own world only.

## Quick start

```
"/demo-setup" (optionally "… username brett")
→ 1 Preflight: seeder tools present on Paywhere; get_demo_dates (quickbooks) → dateModel verbatim
→ 2 Approval gate (replaces the caller's own bank world; books untouched)
→ 3 seed_demo_world {confirm:true, dateModel, username?} → returns at once: jobId, creds, expectedClosing, answerKeySummary
→ 4 Poll get_demo_world every ~20 s until seedJob.state == "done" (≈ 4–6 min)
→ 5 Readback through the demo connector: balances == expectedClosing; payees == recipientsConfigured; enrichment; the unbooked check
→ 6 Report the answer-key summary + point at demo/SCENARIOS.md
```

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Preflight"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. During step 4, update the task's description with the
poll progress ("posted 412 / 1,040, eta 3 min") so Cowork shows movement.
This is what drives Cowork's visible progress display — it does not happen
unless you do it explicitly.

### 1. Preflight — connectors and the books' dates

- **Demo deployment check (no call needed):** the Paywhere connector's tool
  list must include `seed_demo_world` and `get_demo_world`. If absent, this
  is not a demo deployment — **stop**; never try to seed a real connector.
- **quickbooks:** call `get_demo_dates` (read-only). It is the liveness probe
  and the alignment contract:
  - `{seeded: true, seededAt, dateModel}` → capture `dateModel` **verbatim**.
  - `{seeded: false}` → the books have not been seeded server-side yet (they
    reseed daily, 5am ET) — say so and **stop**. A bank world on unknown
    book dates misaligns every beat.
- **Paywhere:** `list_accounts` must respond (any result is fine).
- Note which optional connectors are present (gmail, google calendar); the
  demo's Gmail/Calendar content is seeded separately by the Google seed
  script and is shared, so their absence does not block the bank seed —
  mention it in the report.

### 2. Approval gate

Say plainly: this **replaces the caller's own demo bank world** with a fresh
generation and fresh credentials; the shared books are untouched; other
presenters' worlds are unaffected. Confirm the `username` label if given.
**Wait for explicit approval** (the tool also requires `confirm: true`).

### 3. Kick off the seed — `seed_demo_world {confirm: true, dateModel, username?}`

The call is **asynchronous** and returns immediately with:

```
{ ok, jobId, seedState: "running", bankUsername, bankPassword, generation,
  accounts[], dateModel, dateModelSource, migratedFromSharedDemo, totalRows,
  expectedClosing: {operating, taxReserve, savings}, answerKeySummary,
  recipientsConfigured, enrichmentWritten, beatsReady[], note }
```

- **Surface `bankUsername` / `bankPassword` prominently** at the top of the
  reply (mock-only credentials, shown once; if `slackNotified` is false or
  absent, tell the presenter to record them now).
- `dateModelSource` must be `"provided"`. `"computed"` means the server
  self-computed — treat as a bug in this run and restart from step 1.
- `migratedFromSharedDemo: true` → this caller just moved off the shared
  read-only backdrop onto their own world; say so.
- Keep `expectedClosing`, `recipientsConfigured` and `answerKeySummary` for
  steps 5–6. Payees and enrichment are written synchronously before the call
  returns; only the transaction rows post in the background.

### 4. Poll until done — `get_demo_world`

Call `get_demo_world` every **~20 seconds**. The response carries
`seedJob: null | { jobId, state: "running" | "done" | "failed", total,
posted, failed, etaSeconds, failureSamples[] }` plus `bankUsername`,
`generation`, `accounts[]`, and (when present) `expectedClosing` /
`answerKeySummary`.

- Update the step-4 task description with `posted / total` and the eta on
  every poll. Expect **≈ 4–6 minutes for ≈ 1,000 rows**.
- `state: "done"` → continue. `failed > 0` with `state: "done"` → report the
  `failureSamples` and treat the readback in step 5 as the arbiter (a few
  failed rows will show up as a balance mismatch).
- `state: "failed"` → report `failureSamples`, then re-run from step 1 once
  (the reset is idempotent). Twice failed → stop and report.
- Do not start the readback before `done`: balances are moving.

### 5. Readback — assert through the connector the demo will use

Never trust the seeder's own numbers; read them back on the same connector.

1. **Balances.** `list_accounts` (then `get_account_balance` per account).
   Identify the three accounts by role (primary checking = Operating; the
   savings account named for tax = Tax Reserve; the other savings = Business
   Savings). Assert each balance **equals `expectedClosing`** for that role
   (to the cent). Pending authorizations are excluded from `expectedClosing`
   by design.
2. **Saved payees.** `list_saved_payees`. Assert the count **equals
   `recipientsConfigured`**. Spot-check that the crane subcontractor
   ("Ironclad Crane & Rigging") resolves with `rail: "wire"` and the parts
   supplier ("Johnstone Supply") with `rail: "ach"` — a rail mismatch is
   exactly what makes `pay-bills` misreport a saved wire payee.
3. **Enrichment.** `query_transactions {direction: "debit",
   descriptionContains: "ANGI LEADS", limit: 1}` → take that row →
   `get_transaction_detail`. Assert `detail` is **non-null** (the
   subscription-audit beat depends on it).
4. **The unbooked check.** `query_transactions {direction: "credit",
   descriptionContains: "MOBILE CHECK DEPOSIT", dateFrom: <today − 7
   days>}`. Assert a row exists whose amount equals
   `answerKeySummary.ar.unbookedReceipt.amount` and whose descriptor carries
   `answerKeySummary.ar.unbookedReceipt.checkNumber` (the received-but-
   unbooked beat in invoice-chase and plan-payroll).

If **any** assertion fails, the seed did not land — **do not report
`beatsReady`**. Re-run from step 1 once; on a second failure report the
mismatch (expected vs actual per check) and stop.

### 6. Report

From the responses (never from memory), report:

- **Credentials** (`bankUsername`, password shown once) and the generation.
- **Balances by role** with account numbers, confirmed by readback, and the
  pending-authorization total if `answerKeySummary.balances.pendingAuthorizations`
  is present.
- **Alignment:** `dateModelSource: "provided"`, the books' `seededAt`, and
  `dateModel.today` / `dateModel.horizon`.
- **The answer-key summary** — the numbers the presenter should hear back in
  Act 1 (field paths are the same as `AnswerKey` in
  `paywhere-mcp-api/src/demo/world/types.ts`):
  - `trueAvailable.amount` (+ `formula`) — beat 1.1
  - `tax.reserveBalance`, `tax.collectedNotRemitted.total`, `tax.shortfall`,
    `tax.missedSweeps`, `tax.nextRemittance` — beat 1.6 / 3.5
  - `ar.largestOverdue` and `ar.unbookedReceipt` — beats 1.1, 1.3
  - `ap.dueThisWeek` (with rails) and `ap.holdCandidates` — beat 1.4. The
    list is the three staged bills plus any generated bill whose due date
    falls in the window (e.g. a smaller Trane bill); read it, do not assume
    three lines.
  - `payroll.nextPayDate`, `payroll.estimatedTotal`, `payroll.headroomAfterPayroll` — beat 1.5
  - `subscriptions.monthlyTotal` — beat 1.7
  - `liveSurface` (the staged items) and `counts` (rows, payees, enrichment)
  - The summary is a subset (`balances`, `trueAvailable`, `tax`, `ar`, `ap`,
    `payroll`, `subscriptions.monthlyTotal`, `liveSurface`, `counts`); the
    full key for a given date lives in paywhere-mcp at
    `paywhere-mcp-api/src/demo/world/fixtures/answer-key-<today>.json`.
- **Readback checks:** balances ✓, payees ✓ (count + the two rails),
  enrichment ✓, unbooked check ✓.
- **Beats ready** (`beatsReady`) and the pointer: the run-of-show with exact
  prompts is [`../../../demo/SCENARIOS.md`](../../../demo/SCENARIOS.md); the
  presenter kit is [`../../../demo/presenter-kit.md`](../../../demo/presenter-kit.md).
- If Gmail or Calendar were not connected in preflight, one line saying the
  Gmail/Calendar beats (1.3 drafts, 1.8 quotes, 3.1 calendar overlay) need
  them.

## Edge cases

- **Seeder tools absent** → not a demo deployment; stop.
- **`get_demo_dates` → `seeded: false`** → books not seeded yet; stop.
- **Shared backdrop** (`get_demo_world` → `sharedEnvWorld: true`, or a
  demo-mutating tool refusing) → this skill is the fix; expect
  `migratedFromSharedDemo: true`.
- **Poll shows no progress for > 2 minutes** (`posted` unchanged) → keep
  polling to 10 minutes total, then report and re-run once.
- **Re-authorizing the connector with old credentials** points the session at
  an old world; balances will not match `expectedClosing` — re-run.
- **The books rotated mid-setup** (5am ET reseed between steps 1 and 3): if
  the report's dates look off by a day, re-run so a fresh `dateModel` is used.
- **Username label rejected** → re-run with a simpler label or none.
- **Live injects** (`deposit_to_mock_account`, `withdraw_from_mock_account`)
  are permanent for a world; after a rehearsal with injects, re-run this
  skill before the real demo. See [`../demo-inject`](../demo-inject/SKILL.md).
