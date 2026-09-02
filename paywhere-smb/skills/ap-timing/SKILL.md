---
name: ap-timing
version: 1.0.0
description: >
  Pay-when-due analysis for payables: what is due this week, what is not yet
  due, and which vendors the owner habitually pays earlier than the terms
  require — derived from 12 months of bill dates vs bill-payment dates in the
  books, corroborated by the bank debits — with the dollars and days that
  early habit costs, a hold/pay/defer recommendation per open bill, and the
  effect on the next four weeks' minimum operating balance if everything is
  paid on its due date instead. Reads only; hands off to pay-bills to stage
  payments. Use when the owner says "what's due this week," "am I paying
  anyone early," "what bills are coming due," "which vendors do I pay earlier
  than necessary," "what if I pay on the due date," or "can I safely defer."
---

# AP Timing

The question is not "what do I owe" but "when should it leave". Open bills
come from the books; the *habit* comes from comparing each bill's due date to
the date it was actually paid, and the bank confirms the debits. The output
is a pay / hold / defer table and the cash it keeps in the window. Nothing
is paid here — [`../pay-bills`](../pay-bills/SKILL.md) stages the approved
set.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Open bills"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

## Quick start

```
User: "what's due this week, and am I paying anyone early?"
→ search_bills (open) + get_aged_payables → due-this-week / overdue / not-yet-due
→ search_bills + search_bill_payments (12 months) → days early per vendor, $ paid early, months
→ query_transactions debits by vendor stem → the habit is real at the bank
→ Table: PAY NOW (due ≤ 7 days) · HOLD (not due, habitually-early vendor) · DEFER candidates
→ 4-week minimum operating balance: pay-early habit vs pay-when-due
→ "Stage the pay-now set? That's pay-bills."
```

## Step 1 — Open bills (parallel)

Resolve "today" from the actual date.

- **quickbooks**: `search_bills` (open = positive `Balance`), `get_aged_payables`,
  `search_vendors` (terms). Bucket each bill: **overdue**, **due within 7 days**,
  **not yet due** (with days until due).
- **Paywhere**: `list_accounts` → operating account and `get_account_balance`;
  `list_saved_payees` once (rail per vendor, for the hand-off table).
- **google calendar** (optional): `list_events` next 30 days for dated
  obligations outside AP (payroll, remittance, estimates) — the same window
  the minimum-balance projection uses.

If quickbooks is unavailable, stop: there is no trustworthy list of what is
owed. If Paywhere is unavailable, the analysis still runs; the bank
corroboration and the balance projection are marked n/a.

## Step 2 — Early-payment history per vendor

For the trailing 12 months, pair each paid bill with its bill payment
(`search_bills` with `paidByRef` / `search_bill_payments` applied bills):

```
days early = bill due date − bill payment date   (positive = paid early)
```

Per vendor: count of bills, mean days early, dollars paid early (sum of bill
totals paid ≥ 5 days early), and the months in which the habit shows.
Corroborate with `query_transactions {direction: "debit", descriptionContains:
"<vendor descriptor stem>"}` — the bank debit dates should match the payment
dates; if they do not, trust the bank and say so. Full method and
thresholds: [`reference/early-payment-method.md`](reference/early-payment-method.md).

Call a vendor **habitually paid early** when mean days early ≥ 7 over ≥ 3
bills. Note whether the habit is seasonal (e.g. only in certain months) —
that is a real behavior, not noise. _E.g. "an equipment supplier: 9 bills,
paid a mean of 14 days early from autumn through spring, on the due date in
summer — about $41k left the account two weeks before it had to."_

## Step 3 — Recommend per open bill

| Action | Rule | Show |
|---|---|---|
| **PAY NOW** | overdue, or due within 7 days | vendor, amount, due date, rail (from saved payees) |
| **HOLD** | not due for > 7 days **and** vendor is habitually paid early | days to hold, due date, cash kept in the window |
| **NOT YET DUE** | not due for > 7 days, no early habit | when it will enter PAY NOW |
| **DEFER CANDIDATE** | due soon but discretionary (subscriptions, marketing, non-critical) — only if the owner asked about deferring | what deferring buys and the risk (late fee, relationship) |

Subcontractors paid on receipt and tax authorities are never hold or defer
candidates; say so if they appear.

## Step 4 — Effect on the minimum balance (4 weeks)

Simple direct projection from the operating balance: subtract PAY NOW amounts
in the week they are due, subtract calendar obligations (payroll, remittance)
in their weeks, add nothing for receivables (that is
[`../cash-flow-snapshot`](../cash-flow-snapshot/SKILL.md)'s job). Run it
twice: (a) with HOLD bills paid this week (the habit); (b) with HOLD bills
paid on their due dates. Report the two minimum balances and the date of
each. The difference is what pay-when-due is worth this month.

## Step 5 — Output

```
AP Timing — {date}

Open AP ${x} · overdue ${} · due in 7 days ${} · not yet due ${}

| Action | Vendor | Amount | Due | Days | Rail | Note |
| PAY NOW | … | | | | ACH/wire | |
| HOLD | … | | {date} | hold {n} | | habitually paid {m} days early ({k} bills) |

Early-payment habit (12 months): {vendor} mean {n} days early, ${} across {k} bills, {months}
Minimum operating balance next 4 weeks: pay-early ${a} on {date} → pay-when-due ${b} on {date}

Next: "stage the pay-now set" → pay-bills (holds stay held)
```

## What not to do

- Do not stage or pay anything here; hand off to pay-bills.
- Do not call a vendor habitually early on fewer than 3 bills.
- Do not recommend holding a bill past its due date ("defer") unless asked;
  pay-when-due is the recommendation, not late payment.
- Do not project receivables here.

## Reference

- [`reference/early-payment-method.md`](reference/early-payment-method.md)
- [`../pay-bills/SKILL.md`](../pay-bills/SKILL.md) — stages the approved set; honors holds
- [`../cash-flow-snapshot/SKILL.md`](../cash-flow-snapshot/SKILL.md) — the full 13-week view with receivables
