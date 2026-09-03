---
name: subscription-audit
version: 1.0.5
description: >
  Finds every recurring debit in 12 months of bank descriptors — no
  counterparty field needed — normalizes the statement text, groups it into
  vendors, totals the monthly run-rate, and flags what deserves a look:
  zero-attribution lead-gen or marketing spend (no customer traces to it),
  orphaned subscriptions (no vendor record, nobody claims it), duplicate seats
  or overlapping tools, and price creep. Also answers the single-row question
  "what is this debit?" with bank enrichment, the books' vendor and any
  renewal email. Read-only; cancels nothing. Use when the owner says "what's
  this $349 ANGI LEADS debit" (or any "what's this [amount] [descriptor]
  debit," "what is this charge"), "what subscriptions am I paying," "what
  recurring charges do I have," "what am I paying for every month," or "find
  recurring debits."
---

# Subscription Audit

The bank has 12 months of descriptors and nothing else — no counterparty, no
category. That is enough: a recurring debit is a stem that repeats at a
steady interval for a steady amount. Pull once, normalize, group, then
enrich the interesting rows with the books and the inbox. Nothing here moves
money or cancels anything; the output is a list the owner acts on.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Pull 12 months of
debits"), then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

## Two entry points

- **"What is this debit?"** (an amount and/or a descriptor fragment) → do
  Step 0 first, answer in one paragraph, then offer the full audit.
- **"What subscriptions am I paying?"** → Steps 1–5.

## Step 0 — The single row

1. `list_accounts` → Operating (primary checking; never a hardcoded number).
2. `query_transactions {direction: "debit", descriptionContains: <fragment>,
   amountMin: <amount − 1>, amountMax: <amount + 1>, dateFrom: <12 months
   ago>}` — every occurrence, not just the latest. Months seen, amount
   history, first seen.
3. `get_transaction_detail` on the latest row — enrichment may name the
   counterparty, memo, category or a document ref; it may also be `null`.
   Say which.
4. Books: `search_vendors` on the stem / enrichment name; `search_purchases`
   or `search_bills` for that vendor in the last 90 days → is it recorded,
   and to which expense account.
5. Inbox: `search_threads` on the vendor name (`newer_than:1y`) → renewal,
   receipt, price-change or auto-renew notice; quote the subject and date.
6. Attribution check for lead-gen/marketing vendors: `search_customers` and
   read Notes / referral-source fields for the vendor's name; count
   customers (and revenue via `get_customer_sales` if any). Zero is a
   finding, stated plainly: "no customer in the books names this source".

Answer: what it is, who set it up if the inbox says, how long it has run,
what it has cost in total, and whether anything in the business points back
to it. Then: "Want the full recurring-charges audit?"

## Step 1 — Pull 12 months of debits (bank)

`query_transactions {direction: "debit", dateFrom: <today − 12 months>,
dateTo: <today>, status: ["posted"]}` on Operating. There is **no groupBy
counterparty**; you are pulling rows. If `truncated: true`, slice by quarter
(four calls) and merge. Exclude obvious non-vendor rows before grouping:
payroll processor debits, tax remittances, internal transfers, owner
distributions, wire/ACH payments to saved payees that vary in amount (those
are bills, handled by `../ap-timing`).

## Step 2 — Normalize and group

Apply `reference/normalization.md`: strip the rail prefix (`POS DEBIT`,
`RECURRING DEBIT`, `ACH DEBIT`), store numbers, city/state suffixes, dates,
trailing reference ids and `*`-separated processor codes; keep the vendor
stem. Group rows by stem.

## Step 3 — Decide what is recurring

A stem is **recurring** when it has ≥ 3 occurrences, the gaps between
consecutive debits are ~monthly (25–35 days; also accept ~weekly, quarterly
or annual patterns, labelled as such) and the amount is stable (±10%) or
steps up once. Everything else is spend, not subscription — leave it out of
the total but keep fuel/consumable stems in an appendix count so the owner
sees the boundary.

**Recurring is not the same as subscription.** Split the recurring stems
into two classes and total them separately:

- **Subscriptions** — the audit's headline total. Software and SaaS, phone
  and internet, cloud storage, e-sign, website hosting, uniform and service
  contracts, directory listings and fixed-fee lead-gen plans (an "Angi
  Leads" or "Yelp" plan): anything on a plan that renews by itself and can
  be cancelled with a click or a call.
- **Other fixed monthly commitments** — listed for context, never inside
  the subscription total. Rent, utilities, insurance premiums, the payroll
  processor's fee, loan and lease payments, the accountant's retainer, bank
  service charges, and pay-per-click ad spend (Google Ads) that recurs by
  habit rather than by plan.

When the owner asks "what subscriptions am I paying for in total," the
answer is the subscription total, stated on its own line; give the
fixed-commitments total as a second number, clearly labelled, never merged
into the first.

## Step 4 — Enrich and flag

For each recurring stem: latest amount, cadence, months seen, 12-month
total, `get_transaction_detail` on the latest row (may be null), the books'
vendor (`search_vendors`) and expense account, and the **last recorded
purchase**: one `search_purchases` call per recurring stem, filtered by the
vendor's QuickBooks Id on the Purchase entity's vendor field —
`{params: {criteria: [{field: "EntityRef", value: "<vendor Id>"},
{field: "TxnDate", operator: ">=", value: "<6 months ago>"}], limit: 5}}`
(a Purchase's vendor is `EntityRef`; there is no `VendorRef` and no
`vendor_ref` parameter — an unknown parameter is ignored and the tool returns
an unfiltered list). Read `EntityRef.name` in the rows: if they name other
vendors, the filter did not apply — fix the call, never treat those rows as
this vendor's purchases. The cell holds the latest `TxnDate` or the word
"none", and is never filled in from the vendor list. A vendor record is not
evidence the charge is booked; a vendor record with no purchase in 6 months
is the commonest orphan (someone set it up, nobody books it). Then any inbox
thread. Then flag — **mechanically, from the tests below**: a stem whose
last-recorded-purchase cell reads "none" is flagged orphaned, with no
"not confident enough" caveat. Orphaned means nobody *books* it, not nobody
*uses* it; a $23 PDF tool someone may still open is orphaned when a year of
bank debits has no purchase in the books.

| Flag | Test |
|---|---|
| **zero attribution** | A lead-gen / advertising / directory subscription with no customer whose Notes or referral source names it (`search_customers`), or with zero revenue traced to it |
| **orphaned** | Last recorded purchase = "none" (no purchase in 6 months, whether or not a vendor record exists), no vendor record at all, or the inbox shows it was set up by someone no longer with the business |
| **duplicate** | Two stems serving the same function (two file-sync tools, two phone lines for one person) or a second seat of the same product |
| **price creep** | Amount stepped up during the window; show old → new and the annualized delta |
| **unknown** | Nothing in the books or inbox explains it — ask the owner |

## Step 5 — Output

```
Recurring charges — {date} (12 months of bank debits, Operating)

| Vendor (stem) | Amount | Cadence | Months seen | 12-mo total | Vendor in books? | Last recorded purchase | Flag |
|---|---|---|---|---|---|---|
| … | … | monthly | 12 | … | yes / no | zero attribution |

Subscriptions — monthly run-rate: ${subs}   ·   Annualized: ${subs × 12}
Cancel / review candidates: {n} items, ${x}/month (${y}/year)
  • {vendor} — {flag}: {one-line evidence}

Other fixed monthly commitments (not subscriptions): ${fixed}/month
| Vendor (stem) | Amount | Cadence | What it is |
|---|---|---|---|
| … | … | monthly | rent / utility / insurance / payroll fee / CPA / bank fee / ad spend |

Not counted: {n} variable stems (fuel, consumables, saved-payee bills)
```

Close with what the owner can do (cancel, downgrade, reassign a seat) and
say clearly that this skill changes nothing itself. If the owner wants to
stop a charge, that happens with the vendor; if the vendor is paid by ACH
from a saved payee, the payee stays until the owner removes it.

## Degradation

| Missing | Effect |
|---|---|
| Paywhere | Stop — the descriptor history is the whole method. |
| quickbooks | Skip "in books" and attribution columns; flags limited to duplicate / price creep / unknown. |
| gmail | Skip email evidence; say so. |

## Reference

- `reference/normalization.md` — stem rules, spacing test, examples
