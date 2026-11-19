---
name: demo-setup
version: 2.0.1
disable-model-invocation: true
description: >
  Walks the presenter through building their own Nick's HVAC demo bank world
  on the Paywhere demo seeder page, then checks it through the Paywhere
  connector the demo runs on: balances equal the seeder's expected closing
  balances, the saved payees are there, the unbooked check landed. Reports
  the answer-key summary (true available cash, reserve shortfall, largest
  overdue, bills due this week, Friday payroll). Date-aligned to the shared
  read-only QuickBooks books via get_demo_dates. Presenter use only. Use when
  someone says "set up the demo," "reset the demo," "seed the demo world,"
  "rebuild the sandbox," or "/demo-setup."
---

# Demo Setup (Act 0)

Gets the presenter's own demo bank world ready for the **Nick's HVAC**
persona. The world is built by the **Paywhere demo seeder**, a staff web page
(sign in with your Paywhere Google account). The MCP server has no seeding
tools. Everything about the world (roster, amounts, dates, payees, the answer
key) lives in the seeder's code; this skill gets the dates from the books,
tells the presenter what to do on the page, and then checks the result
through the connector. The QuickBooks books are **shared and read-only**
(reseeded server-side daily) and never touched here. What the world contains
is described qualitatively in [`../../DATASET.md`](../../DATASET.md); never
hardcode any of it here: read it back.

**The seeder page:** `https://paywhere-demo-seeder.poc.dev.paywhere.com`
(ask the presenter if they use another one).

Each presenter has **one fixed demo login** on the page (`demo-<name>`,
password shown there). Rebuilding resets that login in place, so a connector
already signed in with it **stays connected**. Other presenters' worlds are
unaffected.

## Quick start

```
"/demo-setup"
→ 1 Preflight: get_demo_dates (quickbooks) → dateModel verbatim; Paywhere connector responds
→ 2 On the seeder page: paste the dateModel, Build (or Rebuild) world, wait for "ready" (≈ 5 min)
→ 3 Connect: the Paywhere connector must be signed in with the page's demo login
→ 4 Presenter pastes the page's setup summary ("Copy setup summary for /demo-setup")
→ 5 Readback through the connector: balances == expectedClosing; saved payees; the unbooked check
→ 6 Report the answer-key summary + point at demo/LIVE-SCRIPT.md
```

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Preflight"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display; it
does not happen unless you do it explicitly.

### 1. Preflight: the books' dates

- **quickbooks:** call `get_demo_dates` (read-only). It is the liveness probe
  and the alignment contract:
  - `{seeded: true, seededAt, dateModel}` → capture `dateModel` **verbatim**.
  - `{seeded: false}` → the books have not been seeded server-side yet (they
    reseed daily, 5am ET). Say so and **stop**: a bank world on unknown book
    dates misaligns every beat.
- **Paywhere:** `list_accounts` must respond (any result is fine).
- Note which optional connectors are present (gmail, google calendar). The
  demo's Gmail/Calendar content is seeded separately and shared, so their
  absence does not block the bank world; mention it in the report.

### 2. Build the world on the seeder page

Tell the presenter, in this order, and show the `dateModel` as a copyable
block:

1. Open the seeder page and sign in with their Paywhere Google account.
2. Under **Nick's HVAC world**, open "Line dates up with QuickBooks" and paste
   the `dateModel` (it wins over the run date).
3. Press **Build world** (first time) or **Rebuild world**. A rebuild wipes
   their own world's accounts and history and seeds a fresh one; the books are
   untouched and the login stays the same.
4. Wait until **Seed progress** shows **ready** (≈ 5 minutes; they can leave
   the page). "done with errors" or "failed" → read the first failures off the
   page and rebuild (see the retry rule below).

Then **wait** for the presenter to say it is ready.

### 3. Connect with the demo login

The Paywhere connector must be signed in with the **demo login the page
shows** (`demo-<name>` and its password), through the bank sign-in screen.
If it was already signed in with that login, nothing to do: rebuilds keep the
login. If not (first time, or another login), the presenter reconnects the
Paywhere connector and signs in with it. If the page's password does not sign
in, the page's **Recreate login** fixes it (then reconnect).

### 4. Get the setup summary

Ask the presenter to press **Copy setup summary for /demo-setup** on the
page and paste it here. It is JSON with `bankUsername`, `dateModel`,
`accounts[]` (role, number, name), `expectedClosing` (`operating`,
`taxReserve`, `savings`), `seedJob` and `answerKeySummary`. Check:

- `seedJob.state` is `"done"` with `failed: 0`. Otherwise rebuild (see the
  retry rule below).
- `dateModel.today` / `dateModel.horizon` equal the books' `dateModel` from
  step 1. A mismatch means the date paste was missed: rebuild with it.

### 5. Readback: assert through the connector the demo will use

Never trust the seeder's own numbers; read them back on the same connector.

1. **Balances.** `list_accounts` (then `get_account_balance` per account).
   Match accounts to the summary's `accounts[]` by account number. Assert
   each balance **equals `expectedClosing`** for that role, to the cent.
   `expectedClosing` already has this week's pending card authorizations
   deducted, exactly as the bank's current balance does.
   Different account numbers altogether → the connector is signed in as
   another login: back to step 3.
2. **Saved payees.** `list_saved_payees`. Assert the count **equals
   `answerKeySummary.counts.recipients`**. Spot-check that the crane subcontractor ("Ironclad
   Crane & Rigging") resolves with `rail: "wire"` and the parts supplier
   ("Johnstone Supply") with `rail: "ach"`. A rail mismatch is exactly what
   makes `pay-bills` misreport a saved wire payee.
3. **The unbooked check.** `query_transactions {direction: "credit",
   descriptionContains: "MOBILE CHECK DEPOSIT", dateFrom: <today − 7
   days>}`. Assert a row exists whose amount equals
   `answerKeySummary.ar.unbookedReceipt.amount` and whose descriptor carries
   `answerKeySummary.ar.unbookedReceipt.checkNumber` (the received-but-
   unbooked check in plan-payroll).

If **any** assertion fails, the world is not ready: say which check failed
(expected vs actual), have the presenter rebuild, and repeat from step 4.

**Retry rule (whole run):** at most **one** rebuild per `/demo-setup` run,
whichever step asked for it. If the world still isn't right after that one
rebuild, report what failed and stop. A payee mismatch is not fixed by a
rebuild (payees come from the connector, not the page): report it, don't
rebuild for it.

### 6. Report

From the pasted summary and the readback (never from memory), report:

- **The demo login** (`bankUsername`; the password stays on the page).
- **Balances by role** with account numbers, confirmed by readback, and the
  pending-authorization total if `answerKeySummary.balances.pendingAuthorizations`
  is present.
- **Alignment:** the books' `seededAt`, and `dateModel.today` /
  `dateModel.horizon`.
- **The answer-key summary**, the numbers the presenter should hear back in
  Act 1:
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
  - `liveSurface` (the staged items) and `counts` (rows, payees)
- **Readback checks:** balances ✓, payees ✓ (count + the two rails),
  unbooked check ✓.
- The pointer: what to type, in order, is
  [`../../../demo/LIVE-SCRIPT.md`](../../../demo/LIVE-SCRIPT.md); setup, the
  FI seat and the injects are [`../../../demo/SCENARIOS.md`](../../../demo/SCENARIOS.md).
- If Gmail or Calendar were not connected in preflight, one line saying the
  Gmail/Calendar beats (1.3 drafts, 1.8 quotes, 3.1 calendar overlay) need
  them.

## Edge cases

- **`get_demo_dates` → `seeded: false`** → books not seeded yet; stop.
- **The presenter can't open the seeder page** (not a Paywhere Google
  account, or no access) → stop; the world can only be built there.
- **Balances off by the same amount on one account** → a live inject from a
  rehearsal is still in the world. Rebuild before the real demo.
- **Signed in with an old login** (a `demo-<uid>-gN` login from before the
  seeder) → those worlds are orphaned; reconnect with the page's login.
- **The books rotated mid-setup** (5am ET reseed between steps 1 and 2): if
  the dates do not match in step 4, rebuild with a fresh `dateModel`.
- **Live injects** are permanent for a world until the next rebuild; after a
  rehearsal with injects, rebuild before the real demo. See
  [`../demo-inject`](../demo-inject/SKILL.md).
