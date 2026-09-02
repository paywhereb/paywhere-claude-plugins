---
name: tax-prep
version: 1.0.0
description: >
  Prepares owner income-tax materials for the accountant — the quarterly
  estimated-tax calculation from YTD net income, or year-end 1099-NEC prep
  from vendor payments cross-checked against bank ACH/wire debits — as a
  handoff packet, not tax advice. Sales tax is NOT here: for the reserve
  balance, collected-not-remitted, the 20th remittance, missed sweeps and the
  catch-up transfer use tax-reserve-check. Accepts optional mode and year
  arguments. Use when the owner says "tax stuff," "estimated taxes," "what do
  I owe the IRS this quarter," "1099s," "year-end tax prep," or "my
  accountant needs…".
---

> **For sales tax** (reserve balance, collected-not-remitted, the 20th
> remittance, missed Friday sweeps, the catch-up transfer) use
> [`../tax-reserve-check`](../tax-reserve-check/SKILL.md). This skill is for
> the owner's income-tax estimates and 1099s.

Run the tax prep workflow using the `tax-season-organizer` skill. Act
immediately — the owner asked for tax prep, so skip discovery.

Parse arguments:
- `--mode` (default: infer from date — Q1–Q3 → `quarterly`, Oct–Jan →
  `both`) — `quarterly`, `1099`, or `both`
- `--year` (default: current year, resolved from the actual date)

**Framing:** open every deliverable with "Prepared for review by your
accountant — not tax advice."

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Determine mode"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

## Step 1 — Determine mode

If `--mode` was not given, infer from the current date and confirm in one
line: "Based on the time of year I'll prepare {mode} — want something
different?"

## Step 2 — Quarterly estimate (mode includes quarterly)

1. `get_profit_and_loss` YTD (Jan 1 → last completed quarter). If QuickBooks
   is not connected, ask for net income or a CSV.
2. **Payments already made this year come from the bank**: `query_transactions`
   on Operating, `direction: "debit"`, `descriptionContains: "IRS"` (or
   `EFTPS` / `USATAXPYMT`), `dateFrom: Jan 1`. Confirm the list with the
   owner; if Paywhere is not connected, ask.
3. Calculate per `tax-season-organizer/reference/calculation-assumptions.md`
   (entity type matters — an S-corp owner on payroll has withholding, not
   SE tax on wages; state the assumption).
4. Note the funding source plainly: **owner estimates are paid from
   Operating and are not covered by the sales-tax reserve** — the reserve
   holds sales tax only. Show the next due date (from the calendar if
   present) and the effect on true available cash.
5. Deliver the estimate with every assumption listed.

## Step 3 — 1099 prep (mode includes 1099)

1. `search_vendors` + `search_bill_payments` / `search_purchases` for the
   year → payments per vendor for services; flag `is1099` vendors.
2. Bank cross-check: `query_transactions {direction: "debit", dateFrom: Jan 1}`
   for ACH / wire debits to counterparties with no vendor record (subcontractors
   paid by wire and never booked are the classic miss).
3. Aggregate by payee; flag likely duplicates for review, never auto-merge.
4. Apply the $600 threshold; flag $400–$599 as near-threshold; note that
   corporations are usually exempt (accountant confirms).
5. W-9 status per flagged payee from the vendor record.
6. Deliver the candidate list, the missing-W-9 list and the bank-only payees.

## Guardrails

- **Not tax advice** — in every header.
- **State every assumption** — bracket, entity type, exclusions.
- **Never merge payees automatically.** **Never file anything.**
- **Never move money.** If the owner wants to pay the estimate, hand off to
  `../pay-bills` (it stages a proposal for passkey approval on the bank's
  page); this skill only computes.

## Output

Files go to the working folder (`tax/estimate-{YYYY}-Q{n}.md`,
`tax/1099-prep-{YYYY}.md`). End with the accountant's checklist: W-9s to
collect, assumptions to verify, deadlines.
