---
name: ap-timing
version: 1.0.2
description: >
  Answers "am I paying anyone early, and what should I hold?" for accounts
  payable in one QuickBooks call: every open bill split into due-within-7-days
  and not-yet-due, plus each vendor's 12-month habit (bills paid at least 5
  days before the due date, mean days early, dollars paid early, habitually
  early when 3 or more bills were). Produces a PAY NOW / HOLD / NOT YET DUE
  table with the cash a hold keeps in the account until the due date, and
  checks the pay-now total against the Operating balance. Read-only; hands
  off to pay-bills to stage payments. Use when the owner says "am I paying
  anyone early," "which vendors do I pay earlier than necessary," "what should
  I hold," "what's due this week and what can wait," or "what bills are coming
  due." NOT for staging or paying bills — that is pay-bills.
---

# AP Timing

The question is not "what do I owe" but "when should it leave". One
QuickBooks report answers both: the open bills with days until due, and the
habit — how each vendor's bills were paid against their due dates over the
last year. This skill turns that into a pay / hold table. Nothing is paid
here; [`../pay-bills`](../pay-bills/SKILL.md) stages the approved set.

## Quick start — two calls, one turn

```
User: "am I paying anyone early?"
→ In ONE turn, in parallel:
    get_vendor_payment_timing {}                       (open bills + 12-month habit per vendor)
    list_accounts                                      (Operating balance vs the pay-now total)
→ PAY NOW = dueWithin7Days · HOLD = notYetDue where vendorHabituallyPaidEarly · NOT YET DUE = the rest
→ Reply: the number first, then the table, then "Stage the pay-now set? That's pay-bills."
```

Optional third call, only when the owner asks "is that real at the bank":
`query_transactions {direction: "debit", descriptionContains: "<vendor
stem>", dateFrom: <12 months ago>, limit: 20}` for the **one** vendor with
the largest `dollarsPaidEarly`. Debit dates should sit at or within a
business day of the books' payment dates; if they do not, trust the bank and
say so. Never loop this over vendors.

Never pull a year of `search_bills` or `search_bill_payments` here: the report
already pairs them. Never call `get_aged_payables` here either — the open
bills in the report are the aging.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Read"), then `TaskUpdate`
it to `in_progress` when you begin that step and `completed` when it's done.
This is what drives Cowork's visible progress display — it does not happen
unless you do it explicitly.

## Step 1 — Read (one parallel turn)

Resolve "today" from the actual date. Issue both reads at once:

- **QuickBooks** `get_vendor_payment_timing {}` (defaults: 12 months, every
  vendor). Add `vendor_ref` only when the owner named one vendor. The result
  carries `openBills[]` (`vendor`, `docNumber`, `dueDate`, `balance`,
  `daysUntilDue`), `dueWithin7Days[]`, `notYetDue[]` (each row flagged
  `vendorHabituallyPaidEarly`) and `vendors[]` (`billsPaid`, `paidEarly`,
  `meanDaysEarly`, `dollarsPaidEarly`, `monthsPaidEarly`,
  `habituallyPaidEarly`). Definitions: [`reference/early-payment-method.md`](reference/early-payment-method.md).
- **Paywhere** `list_accounts` → Operating by role (the primary checking,
  never a hardcoded number). Its balance is compared with the PAY NOW total.

Without QuickBooks: **stop** — there is no trustworthy list of what is owed.
Without Paywhere: run the table; omit the balance line and say so.

## Step 2 — Classify every open bill

| Action | Rule (from the report) | Show |
|---|---|---|
| **PAY NOW** | in `dueWithin7Days` (overdue or due within 7 days) | vendor, DocNumber, open balance, due date, days |
| **HOLD** | in `notYetDue` **and** `vendorHabituallyPaidEarly` | due date, days to hold, cash kept until then (= the open balance) |
| **NOT YET DUE** | in `notYetDue`, no early habit | the date it enters PAY NOW (due date − 7 days) |

The habit is the report's: a bill is *paid early* when the payment that
closed it posted **5 or more days before its due date**; a vendor is
*habitually paid early* with **3 or more** such bills in the window;
`meanDaysEarly` averages the early-paid bills only. Use those words. A hold
means pay on the due date — ACH takes 1–3 business days, so pay-bills should
stage a held bill about 2 business days before it is due. Never recommend
paying past the due date; pay-when-due is the recommendation, not late
payment. Tax authorities and subcontractors on due-on-receipt terms are never
hold candidates; if one appears in HOLD, move it to PAY NOW and say why.

## Step 3 — Reply (under 25 lines)

The number first. Then the table. Then the hand-off.

```
Paying early: ${dollarsPaidEarly total} across {n} bills from {k} vendors in the last 12 months —
{top vendor's role, e.g. "a parts supplier"}: {paidEarly} of {billsPaid} bills, {meanDaysEarly} days early
on average ({monthsPaidEarly}). Holding what is not due keeps ${HOLD total} in Operating until {latest HOLD due date}.

Open AP ${sum of balance} · PAY NOW ${} ({n} bills) · HOLD ${} ({n}) · NOT YET DUE ${} ({n})

| Action | Vendor | Bill | Amount | Due | Days | Note |
| PAY NOW | … | {DocNumber} | $ | {date} | due in {n} / {n} overdue | |
| HOLD | … | {DocNumber} | $ | {date} | hold {n} | habitually early: {paidEarly} bills, {mean} days |
| NOT YET DUE | … | {DocNumber} | $ | {date} | enters PAY NOW {date} | |

Operating ${balance} covers PAY NOW ${} with ${} to spare.   (omit without Paywhere)
Stage the pay-now set? That's pay-bills — holds stay held.
```

If no vendor is habitually early, the first line is "Nobody is being paid
early: {n} vendors, {m} bills paid in the last 12 months, {p} of them 5+ days
early, none reaching 3." Then the PAY NOW / NOT YET DUE table. If there are
no open bills, say so in one line and skip the table. When a habit is
seasonal (`monthsPaidEarly` clusters), name the months — that is a real
behaviour, not noise — but do not speculate about the cause.

## Hand-off

"Stage the pay-now set" → [`../pay-bills`](../pay-bills/SKILL.md), which
stages overdue + due-within-7 bills as one batch and prints the bank's
`/confirm` URL. Pass the HOLD list along so pay-bills lists those under "not
yet due" rather than staging them. Nothing in this skill stages, pays or
transfers, and it never says "paid".

## What not to do

- Do not stage or pay anything here; hand off to pay-bills.
- Do not call a vendor habitually early on fewer than 3 early-paid bills, and
  do not recompute the habit from raw bills and payments — the report is the
  definition.
- Do not recommend holding a bill past its due date.
- Do not project receivables, payroll or a minimum balance here; the balance
  line is today's Operating balance against today's PAY NOW total.
- Do not corroborate at the bank per vendor: one optional debit query for the
  largest habit, and only when asked.

## Reference

- [`reference/early-payment-method.md`](reference/early-payment-method.md) — the report's definitions and the hold rule
- [`../pay-bills/SKILL.md`](../pay-bills/SKILL.md) — stages the approved set; honours holds
