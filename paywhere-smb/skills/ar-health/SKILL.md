---
name: ar-health
version: 1.0.0
description: >
  Receivables analysis from the books AND the bank: aging buckets, each
  customer's payment-behavior profile derived from 12 months of invoice-to-
  payment lags (prompt, routinely late, occasionally very late, delinquent
  then cured, retainage), the DSO trend, customer concentration, and a
  cash-impact ranking of what is open — with bank credits cross-checked so an
  invoice whose money already landed (a check deposited but not yet applied in
  the books) is never counted as collectible. Reads only; hands off to
  invoice-chase when the owner wants to contact anyone. Use ar-health for
  analysis questions and invoice-chase for action. Use when the owner says
  "who owes me money," "how much do customers owe me," "who consistently pays
  late," "what's my DSO," "is my collections getting better or worse," "AR
  aging," or "who are my slow payers."
---

# AR Health

The receivables picture an owner cannot get from the aging report alone:
who owes what, how each customer *actually* behaves, whether collections are
improving, and how much cash is trapped. Books say what is owed; the bank
says what has already arrived. Both are read; nothing is written or
proposed here. When the owner wants to *do* something about it, hand off to
[`../invoice-chase`](../invoice-chase/SKILL.md).

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Pull AR and history"),
then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

## Quick start

```
User: "who consistently pays late?"
→ get_aged_receivables + search_invoices (open) → aging buckets
→ search_invoices + search_payments (12 months) → per-invoice lag → per-customer profile
→ query_transactions (credits since oldest open invoice) → received-but-unbooked check
→ DSO series from monthly revenue (get_profit_and_loss) and month-end open AR
→ Ranked table: cash impact = open × lateness × profile; concentration; direction
→ "Want drafts for the top two? That's invoice-chase."
```

## Step 1 — Pull AR and history (parallel)

Resolve "today" from the actual current date.

- **quickbooks**: `get_aged_receivables`; `search_invoices` for open invoices
  (open = positive remaining `Balance`, not `TotalAmt`); `search_invoices`
  and `search_payments` for the trailing 12 months (the behavior history);
  `get_profit_and_loss` by month for the trailing 12 months (DSO
  denominator); `search_customers` for notes (referral source, terms) when
  the owner asks about a specific customer; `search_credit_memos` so a
  disputed amount is not counted as owed.
- **Paywhere**: `query_transactions {direction: "credit", dateFrom: <oldest
  open invoice date>, status: ["posted"]}` — the credits that may already
  settle an open invoice. If `truncated: true`, slice the date range.
- Sub-customer jobs roll up to the parent customer for profiles and
  concentration; keep the job name on the invoice line.

If quickbooks is unavailable, stop — there is no AR without the books. If
Paywhere is unavailable, run the analysis and say plainly that the
received-but-unbooked check cannot be performed.

## Step 2 — Aging buckets

Bucket every open invoice by days past due at today: current (not yet
due) / 1–30 / 31–60 / 61–90 / 90+. Show totals per bucket and the share of
open AR in each. Cross-check against `get_aged_receivables`; if they
disagree (unapplied credits, timing), trust the invoice list and say so.

## Step 3 — Behavior profiles (derived, never assumed)

For each customer with ≥ 3 paid invoices in the window, compute the payment
lag per invoice = payment date − invoice **due** date (negative = early), then
mean and spread. Classify with the rules in
[`reference/profiles.md`](reference/profiles.md): **prompt**, **routinely
late**, **occasionally very late**, **delinquent then cured**, **retainage**.
Fewer than 3 observations → "insufficient history", not a guess. Note the
design of good data: a routinely-late customer looks fine for the first
cycle or two; the profile is the pattern over the year, so say how many
invoices it rests on.

Report: profile, mean days late, number of invoices, and the largest single
lag. _E.g. "a property-management customer that pays through an AP-automation
batch: routinely late, mean 14 days, 11 of 11 invoices."_

## Step 4 — Bank cross-check: received but not booked

For each open invoice, look for a posted credit whose amount matches the open
balance within $0.50 and whose descriptor carries the customer or the rail
(`ACH CR <name>`, `MOBILE CHECK DEPOSIT <check#>`, `WIRE IN`). Merchant
settlements (`INTUIT PYMT SOLN DEPOSIT`) are net of fees and grouped, so a
card payment matches on gross − fee, not gross; do not force it.

A match = **received, not booked**: the cash is already in the bank; the books
still show the invoice open. Mark it so, quote the bank row (date, amount,
descriptor, check number if present), **exclude it from collectible AR and from
the chase list**, and narrate the books fix in one line: outside a demo the
payment would be recorded against the invoice and deposited from Undeposited
Funds; the demo books are read-only, so the item will reappear each run until
the nightly reseed.

Ambiguous (two open invoices share the amount) → show both, decide nothing.

## Step 5 — DSO and direction

```
DSO(month) = open AR at month end ÷ (revenue of the trailing 3 months ÷ 90)
```

Build the monthly series for the window and state the direction (improving /
worsening / flat) with the two or three months that explain it (a delinquent
customer, a retainage holdback, a policy change such as deposits on large
jobs visible as deposit invoices). Method details in `reference/profiles.md`.

## Step 6 — Cash-impact ranking and concentration

```
cash impact = open balance × lateness factor × profile factor
```

(factors in `reference/profiles.md`). Rank collectible open invoices; the
top two are the "call first" set. Also report concentration: the top
customer's share of trailing-12 revenue and of open AR; flag above 15%.

## Step 7 — Output

```
AR Health — {date}

Open AR ${x} · overdue ${y} ({n} invoices) · DSO {d} days ({direction} from {d0} in {Mon})
Aging: current ${} · 1–30 ${} · 31–60 ${} · 61–90 ${} · 90+ ${}

Received, not booked (excluded): {customer} ${amt} — bank {descriptor} on {date}

Call-first ranking
| # | Customer | Open | Days late | Profile (n invoices, mean late) | Cash impact | Why |
Concentration: {customer} {share}% of revenue

Next: "draft reminders for the top two" → invoice-chase
```

## What not to do

- Do not assume a customer's profile from its name, size or the roster —
  derive it from lags and say how many invoices it rests on.
- Do not count a received-but-unbooked invoice as collectible.
- Do not draft, send or propose anything here — hand off to invoice-chase.
- Do not treat a retainage holdback as delinquency; it is a contract term.

## Reference

- [`reference/profiles.md`](reference/profiles.md) — profile rules, factors, DSO formula
- [`../invoice-chase/SKILL.md`](../invoice-chase/SKILL.md) — the action skill (drafts only)
- [`../business-pulse/SKILL.md`](../business-pulse/SKILL.md) — where the largest overdue becomes the #1 issue
