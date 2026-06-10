---
name: demo-setup-bill-pay
version: 0.1.0
description: >
  Seeds the overdue-AP scenario for the /pay-bills flagship demo, layered on
  top of /demo-setup-base: verifies the six canonical open bills are still
  open, restores any that a prior demo run paid or deleted (same DocNumbers,
  approval-gated), adds two extra overdue drama bills, and reports the exact
  aging buckets the presenter will see. Use when the owner says "set up the
  bill-pay demo" or "seed overdue bills."
---

# Demo Setup — Bill Pay

## Quick start

```
User: "set up the bill-pay demo"
→ Preflight: paywhere-mock + Paywhere + quickbooks respond; base world exists
  (offer /demo-setup-base if not)
→ Resolve every date token in seed/bills.md; render the resolved-date table
→ WAIT for approval — nothing is written before this
→ Verify the six base bills (PWD-BILL-0308…0313) are OPEN; restore any a
  prior demo paid/deleted — same DocNumbers, gated
→ Seed the drama bills PWD-BILL-0314/0315 (search-before-create)
→ Report the expected aging buckets ($7,270 overdue / $7,430 coming due) and
  hand off: "run /pay-bills"
```

Everything this skill seeds is defined in [seed/bills.md](seed/bills.md); the
world it layers on is defined by
[../demo-setup-base/SKILL.md](../demo-setup-base/SKILL.md) and its seed files.
Run base first — this extension assumes the Meridian world exists.

## Workflow

### 1. Preflight — connectors and the base world

Verify all three connectors respond:
- **paywhere-mock** — `get_demo_world`
- **Paywhere** — `list_accounts`
- **quickbooks** — `get_company_info`

If any is missing, name it, say what it's needed for, and stop. Then check
the base world is actually seeded: `search_bills` on DocNumber `PWD-BILL-%`
(LIKE; fall back to `PrivateNote LIKE 'PWD-%'`) and confirm the
Operating/Reserve accounts exist by role in `list_accounts`. No base world →
offer to run **/demo-setup-base** first and stop; layering on nothing
produces a demo that contradicts itself.

### 2. Resolve dates and present the plan — approval gate

Resolve every token used in [seed/bills.md](seed/bills.md) per
[../demo-setup-base/seed/date-tokens.md](../demo-setup-base/seed/date-tokens.md)
— the extras' TxnDates (`M-1:10`, `M-1:18`) and due dates (`M-1:25`,
`W-1:Tue`), plus the base bills' due tokens (`W-1:Mon`, `W-1:Fri`, `EOM-1`,
`W+0:Fri`, `W+0:Fri+7`) so the presenter sees the whole aging picture in
concrete dates. Render the `token → concrete date` table. Nothing in this
seed is horizon-dropped: open bills post no bank rows, and due-date fields
are exempt — note this so nobody "fixes" a future due date.

Show the plan (what will be verified, restored, created) and **wait for
explicit approval before any write**.

### 3. Verify the six base bills — restore what a prior demo consumed

`search_bills` DocNumber LIKE `PWD-BILL-03%`; classify 0308–0313:

- **Open at the manifest amount (Balance == the seed/bills.md amount)** —
  the expected state; nothing to do.
- **Paid or partially paid (Balance < the manifest amount, including 0)** —
  a prior /pay-bills run (possibly interrupted) or an applied credit booked
  Bill Payments against it; a partial Balance would silently break the
  $7,270 cheat sheet. Restore by finding the payments
  (`search_bill_payments` per bill, or DocNumber `PWD-BPAY-%` /
  `PrivateNote LIKE 'PWD-%'`) and — **after approval, showing the exact
  list** — `delete_bill_payment` each one. The bill reopens at its full
  amount with its original DocNumber intact.
- **Missing (deleted)** — re-create with `create-bill` using the **SAME
  DocNumber** and the exact row from qbo-manifest.md / seed/bills.md.

**New DocNumbers? NO.** The `PWD-` DocNumbers are the idempotency keys for
the whole demo world: dedupe searches, the base reset procedure, and
/pay-bills' demo-mode detection all key on them. Minting `PWD-BILL-0316+` for
a re-seeded DigitalOcean bill would orphan the reset procedure and
double-count history. Per the base reset order (qbo-manifest.md): **bill
payments before bills**, always gated.

One honest caveat to surface: re-opening bills does **not** erase the prior
run's bank debits — /pay-bills' "already paid at the bank?" check will
rightly flag them. Fine for rehearsal; for a pristine flagship demo,
recommend a fresh /demo-setup-base run first.

### 4. Seed the drama bills — search-before-create

- `search_bills` for `PWD-BILL-0314` and `PWD-BILL-0315` (DocNumber LIKE,
  PrivateNote fallback). Existing and matching → report "existing", skip.
- For each missing one: confirm the vendor exists by DisplayName
  (`search_vendors` — HubSpot Inc and Google Workspace are base master data;
  `create-vendor` only if genuinely absent, and report it), then
  `create-bill` per the seed/bills.md row with the resolved dates, the `PWD-`
  DocNumber, and the `PWD-` id at the start of `PrivateNote`.
- After the first create, read the bill back (`get-bill`) and verify the
  DocNumber persisted — same sandbox caveat as base; if it didn't, warn that
  dedupe and reset will rely on `PrivateNote LIKE 'PWD-%'`.
- **Report created-vs-existing** for every bill and vendor touched.

### 5. Verify due dates survived the sandbox

QBO sandboxes have been seen rewriting or clamping **future** due dates.
Read back one coming-due bill (`get-bill` on PWD-BILL-0311, due `W+0:Fri`)
and one freshly created extra. Compare carefully — `W+0:Fri` is
**today-anchored** (date-tokens.md), so the stored date depends on the day
base ran, not the day this setup runs:

- Stored DueDate is a valid `W+0:Fri` resolution **for some day since base
  was seeded** (this week's or that week's Friday) → fine, no sandbox fault.
- Stored coming-due DueDate is in the **past** → not a clamp either — the
  base world is **stale** (seeded in a prior week); recommend re-running
  /demo-setup-base, and note the default selection has grown to $10,200.
- Stored date matches **no** valid resolution (e.g. snapped to today or to
  the TxnDate) → that is a sandbox rewrite: **warn the presenter**, show
  exactly what the sandbox stored (a clamped 0311 could appear overdue,
  inflating the default selection by $2,450) so the demo script can adapt.

### 6. Report the expected demo

Close with the presenter's cheat sheet, straight from
[seed/bills.md](seed/bills.md):

- **Aging buckets**: OVERDUE **$7,270.00** (0308, 0309, 0310, 0314, 0315) /
  coming due **$7,430.00** (0311, 0312, 0313) / total **$14,700.00**.
  Note /pay-bills renders coming-due as TWO buckets (due this week / due
  later), so early in the week the presenter sees the $7,430 split (e.g.
  $2,930 + $4,500), and the Slack bill migrates buckets mid-week — totals
  unchanged.
- **Default /pay-bills selection**: the five overdue bills — $7,270.00 as
  four ACH items + one wire — projected post-batch balance ≈ **$89,021.97**
  against the full-seed close (the live number comes from
  `get_account_balance` at demo time, never from this file).
- **Next step: run /pay-bills.** For a "money just landed" moment mid-demo,
  post a live deposit with `deposit_to_mock_account` — demo-driven, never
  seeded, per date-tokens.md hard rule 3.

## Approval gates

- **Gate 1 (step 2)**: no write of any kind before the resolved-date table
  and plan are approved.
- **Gate 2 (step 3)**: deleting bill payments (and re-creating deleted bills)
  is approved separately, with the exact object list shown first.
- Master data (vendors) is never deleted, with or without approval.
- One approval covers one run; changing the plan restarts the gate.

## Edge cases — spell these out, don't guess

- **Bill exists but the amount (or vendor) differs** from the manifest: show
  the diff and ask — keep it as-is (then **recompute and re-state the bucket
  totals**, since $7,270/$14,700 no longer hold), or fix it (`update-bill`,
  or `delete-bill` + re-create with the same DocNumber), gated either way.
  Never silently overwrite.
- **Sandbox clamps future due dates** — step 5 catches it; warn, don't
  retry-loop the sandbox.
- **DocNumber didn't persist** — fall back to the `PWD-` id in `PrivateNote`
  everywhere, as in base.
- **Prior-run residue at the bank** (debits from an earlier /pay-bills):
  expected after a restore — see the step-3 caveat; pristine demo ⇒ fresh
  base reset.
- **Early-month run**: nothing here drops at the horizon, and the extras'
  due dates use past tokens (`M-1:25`, `W-1:Tue`) so they are overdue on any
  run day. The OVERDUE bucket is safe all month; the base bills' coming-due
  rows are only fresh within the week base was seeded — once a week boundary
  passes without a fresh base run, 0311/0312 fall overdue and the default
  selection grows to $10,200 (recompute and tell the presenter).
- **Re-OAuth on the Paywhere connector reverts the world** (base caveat) —
  after any re-connect, re-run base, then this.

## Reference

- [seed/bills.md](seed/bills.md) — the scenario manifest: bill set, vendor
  rail table, expected demo numbers, determinism note.
- [../demo-setup-base/SKILL.md](../demo-setup-base/SKILL.md) and
  [../demo-setup-base/seed/qbo-manifest.md](../demo-setup-base/seed/qbo-manifest.md)
  — the base world and the canonical six open bills + reset procedure.
- [../pay-bills/SKILL.md](../pay-bills/SKILL.md) — the flagship flow this
  setup exists for.
