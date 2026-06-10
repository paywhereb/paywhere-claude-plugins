---
name: demo-setup-payroll-crunch
version: 0.1.0
description: >
  Seeds the cash-crunch scenario for the /plan-payroll demo on top of
  /demo-setup-base: three backdated one-off bank drains (quarterly estimated
  tax, annual insurance premium, workstation refresh) with fully-booked QBO
  mirrors, calibrated so the projected Friday position lands exactly $6,200
  short of the payroll-week obligations — recoverable by collecting the
  Alderbrook and Mitsui invoices. Use when the owner says "set up the
  payroll-crunch demo" or "seed the cash crunch."
---

# Demo Setup — Payroll Crunch

## Quick start

```
User: "set up the payroll-crunch demo"
→ Preflight: paywhere-mock + Paywhere + quickbooks; verify the base world
  exists (get_demo_world + query_transactions spot-check) — offer
  /demo-setup-base first if it doesn't
→ Resolve the date tokens (render the token → date → kept/dropped table)
→ Show the crunch plan WITH the full shortfall equation re-derived from the
  live balance and live obligations (seed/scenario.md)
→ WAIT for approval — nothing is written before this
→ Seed 3 bank drains (seed_transactions, withdrawals only, balance proof)
→ Seed the matching QBO bills + bill payments (PWD-CRUNCH-…, idempotent)
→ Verify: get_account_balance + obligations ⇒ exactly −$6,200; report the
  expected /plan-payroll verdict and the mid-demo deposit moment
```

All math, drain rows, QBO mirrors, and the recompute formula live in
[seed/scenario.md](seed/scenario.md) — read it before changing anything. The
target verdict, verbatim: **"$6,200 short for Friday's payroll unless two
invoices are collected."**

## What this seeds — and what it doesn't

The base world is deliberately healthy (≈ +$14,372 of headroom against the
$81,920 payroll-week obligations). This extension drains Operating Checking
with three realistic backdated one-offs totaling $20,571.97 (canonical world)
so the projection lands at exactly **−$6,200.00**, while Reserve Savings stays
untouched at ≈ $165,243.75 — the escape hatch /plan-payroll should *surface*,
not take. Every drain gets a matched, booked QBO bill + bill payment, so the
only reconciliation discrepancies remain the base $43.17 and $1.20. It seeds
**no** deposits, no new invoices, no AR changes: the recovery path is the AR
the base already planted (Alderbrook $15,600 + Mitsui $7,020).

## Workflow

### 1. Preflight — connectors and the base world

Verify all three connectors respond:
- **paywhere-mock** — `get_demo_world` (also yields the Operating/Reserve
  account numbers; never hardcode them)
- **Paywhere** — `list_accounts`
- **quickbooks** — `get_company_info`

If any is missing, name it, say what it's needed for, and **stop**.

Then confirm the base world is actually seeded — spot-check, don't assume:
- `query_transactions {descriptionContains: "Hallsten", direction: "credit",
  limit: 5}` — expect the `W-1:Mon` $8,500.00 ACH CR (the base phantom).
- `list_accounts` — Operating in the vicinity of the canonical $96,291.97
  close (deviations are fine; step 3 recomputes).

If the spot-check fails, the base isn't there: offer to run
[/demo-setup-base](../demo-setup-base/SKILL.md) first and stop. Never seed the
crunch into an empty or foreign world.

Also pre-search for a **prior crunch seed** (used in steps 3–5):
- Bank: `query_transactions {descriptionContains: "EFTPS", direction:
  "debit", limit: 5}`.
- QBO: `search_bills` and `search_bill_payments` filtering DocNumber
  `PWD-CRUNCH-%` (LIKE; fall back to `PrivateNote LIKE 'PWD-CRUNCH-%'`).

### 2. Resolve dates

Run the resolution algorithm in
[../demo-setup-base/seed/date-tokens.md](../demo-setup-base/seed/date-tokens.md)
(today → horizon Sunday → resolve → clamp → weekend roll-back) for every token
this scenario uses, and render the table:

| Token | Used for |
|---|---|
| `W-1:Tue`, `W-1:Wed`, `W-1:Fri` | the three posted drains — `W-1` rows never drop |
| `W+0:Fri` | payroll date (due date only) — the Friday strictly after today; on a Friday run, next Friday |
| `W+0:Fri+7` | edge of the obligations window (due date only) |

### 3. Present the crunch plan — approval gate

Re-derive the equation from the **live** world; never trust canonical numbers
blind:

1. `get_account_balance` for Operating → `OperatingNow`.
2. Live obligations: `search_bills` for open bills due on or before
   `W+0:Fri+7` (expect the base open-AP book, $13,420.00 — or $14,700.00
   when /demo-setup-bill-pay has also been seeded: its two extra bills add
   $1,280.00, which this recompute absorbs by flexing the EFTPS drain to
   $12,191.97 against the canonical base balance) + Gusto run
   $11,700.00 + contractor cycle $56,800.00 (both per
   [../demo-setup-base/seed/persona.md](../demo-setup-base/seed/persona.md))
   → `ObligationsNow`.
3. Drain amounts per [seed/scenario.md](seed/scenario.md): if the world
   matches canonical, use the canonical rows (13,471.97 + 5,400.00 + 1,700.00
   = 20,571.97); otherwise apply the recompute formula —
   `DrainTotal = OperatingNow + 6,200.00 − ObligationsNow`, EFTPS flexes,
   insurance/equipment stay fixed — and **show the adjusted numbers**.

Render the full equation with every term, live:

```
OperatingNow − DrainTotal = ProjectedAvailable(W+0:Fri)
ProjectedAvailable − ObligationsNow = −6,200.00
```

plus the recovery line (−6,200.00 + 15,600.00 + 7,020.00 = +16,420.00), the
drain row table, the QBO mirror table, and anything the step-1 pre-search
found. **Wait for explicit approval before any write.** One approval covers
one run; changing the plan restarts the gate.

### 4. Seed the bank drains

One `seed_transactions` call (3 rows, well under the ≤25 chunk ceiling),
**withdrawals only**, `stopOnError: true`, rows exactly as in
[seed/scenario.md](seed/scenario.md) (achRecipient blocks included — the mock
bank requires them for ACH withdrawals; the counterparties are mock values
defined in scenario.md). Check `succeeded` / `failed` / **`stoppedAtIndex`**;
on a partial stop, fix the offending row and re-submit only the remainder
(`seed_transactions` is not idempotent). Verify every returned `newBalance`
is positive and the final one equals the planned
`ProjectedAvailable` (canonical: 96,291.97 → 82,820.00 → 77,420.00 →
75,720.00).

### 5. Seed the QBO mirrors

Per [seed/scenario.md](seed/scenario.md), so the drains create **no new
reconciliation discrepancies**:

- **Vendors** (idempotent): `search_vendors` by DisplayName for
  `United States Treasury`, `Pacific Shield Insurance Co`,
  `Corelink Office Systems`; `create-vendor` (note the hyphen) only what's
  missing. Never delete vendors.
- **Stale crunch rows**: if step 1 found `PWD-CRUNCH-%` leftovers, show them
  and — **only after separate, explicit approval** — delete per the base
  reset procedure's dependency order (bill payments before bills:
  `delete_bill_payment`, then `delete-bill`). This typically means a base
  reset orphaned the old bank world but left QBO rows behind.
- **Bills + bill payments**: `create-bill` then `create_bill_payment` for
  each drain — DocNumbers `PWD-CRUNCH-0001/0002/0003` (bills) and
  `PWD-CRUNCH-1001/1002/1003` (payments), TxnDate = DueDate = payment date =
  the drain's resolved date, amounts identical to the bank rows (including
  the recomputed EFTPS amount if step 3 adjusted it). After the first bill,
  read it back to confirm the DocNumber persisted; if not, rely on
  `PrivateNote LIKE 'PWD-CRUNCH-%'` (same sandbox caveat as the base seed).
- Report **created-vs-existing** for every object class.

### 6. Verify and report

Recompute the verdict from live data — the same way /plan-payroll will:

1. `get_account_balance` (Operating) → expect the planned
   `ProjectedAvailable` (canonical 75,720.00).
2. Obligations from step 3 → render the final equation:
   `75,720.00 − 81,920.00 = −6,200.00` (or the live equivalents — the result
   must be exactly −6,200.00).
3. Report the expected /plan-payroll verdict: **"$6,200 short for Friday's
   payroll unless two invoices are collected"** — Alderbrook PWD-INV-0303
   $15,600.00 + Mitsui PWD-INV-0304 balance $7,020.00; the Hallsten $8,500.00
   is the phantom (already in the bank, excluded from recovery); Reserve
   ≈ $165,243.75 is the transfer escape hatch /plan-payroll should surface.

Close by reminding the presenter of the **mid-demo moment**: post Alderbrook's
$15,600.00 live via `deposit_to_mock_account` (exact call sketch in
[seed/scenario.md](seed/scenario.md)), then re-run /plan-payroll ("check
again") — settlement detection flips the verdict to **+$9,400.00** with Mitsui
still open. This is demo-driven, never part of the seed.

## Approval gates

- **Gate 1 (step 3):** no bank write, no QBO write before the user approves
  the resolved date table + the live shortfall equation + the drain plan.
- **Gate 2 (step 5):** deleting stale `PWD-CRUNCH-` rows is approved
  separately and explicitly — show exactly what will be deleted first.
- Vendors (master data) are never deleted, with or without approval.

## Edge cases — spell these out, don't guess

- **Balance lower than canonical** (other demos spent money, early-month base
  drops, partial prior runs): the step-3 recompute handles it. If
  `DrainTotal ≤ 7,100.00` (EFTPS would be ≤ 0) or any step of the balance
  walk would go negative, the world cannot reach exactly −6,200.00 by
  draining — **say so plainly** and offer the choices: (a) re-run
  /demo-setup-base for a clean world (recommended), or (b) scale the scenario
  to the shortfall the world *can* produce and state the new number the demo
  will show instead of $6,200.
- **Crunch already seeded** (step-1 pre-search finds the EFTPS debit and/or
  `PWD-CRUNCH-` rows in the *current* world): report what exists and the
  verdict it already produces — **never double-drain**. Offer a full
  base-reset + reseed if the presenter wants a clean slate.
- **Stale QBO rows, fresh bank world** (`PWD-CRUNCH-` in QBO but no EFTPS
  debit in the bank): a prior generation's leftovers — gated delete (step 5),
  then seed normally.
- **Early-month base run** (all `M0` base rows dropped): the recompute yields
  a larger EFTPS drain (worked example in [seed/scenario.md](seed/scenario.md):
  27,880.00 from a 110,700.00 start). The crunch still lands at exactly
  −6,200.00 because the drains ride `W-1` tokens, which never drop.
- **`seed_transactions` partial failure**: `stoppedAtIndex` marks the failure;
  fix that row and re-submit only the remainder — re-submitting the whole
  chunk double-drains.
- **Open AP differs from $13,420.00** (e.g. /pay-bills demo already paid the
  overdue bills): the live `ObligationsNow` absorbs it via the recompute.
  Note in the summary that the demo narration ("$81,920 of obligations")
  should quote the live number.
- **Other demo extensions**: seed this extension **last** (or on a fresh
  base) — anything that moves Operating money **or changes the open-AP /
  obligations book** after this seed un-calibrates the −6,200. The concrete
  trap: /demo-setup-bill-pay moves no money, but seeding it AFTER the crunch
  adds $1,280.00 of obligations and silently turns the verdict into −$7,480.
  Seeded BEFORE the crunch, the recompute absorbs it (verdict stays exactly
  −$6,200).

## Reference

- [seed/scenario.md](seed/scenario.md) — the worked shortfall math, drain
  rows, QBO mirrors, recompute formula, mid-demo deposit sketch.
- [../demo-setup-base/SKILL.md](../demo-setup-base/SKILL.md) — the base world
  this layers on; run it first.
- [../demo-setup-base/seed/date-tokens.md](../demo-setup-base/seed/date-tokens.md)
  — token grammar, horizon, same-week determinism.
- [../demo-setup-base/seed/persona.md](../demo-setup-base/seed/persona.md) —
  payroll and contractor-cycle amounts; client payment personalities.
- [../demo-setup-base/seed/qbo-manifest.md](../demo-setup-base/seed/qbo-manifest.md)
  — the open AR/AP this scenario's recovery math rides on; reset procedure.
