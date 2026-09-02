---
name: cash-bridge
version: 1.0.0
description: >
  Reconciles "the books say I made money" with "my bank balance went down":
  a profit-to-cash bridge for the last full month (or the month asked) from
  net income to the change in the operating balance — receivables growth,
  owner distributions, owner estimated taxes, sales-tax sweeps to the
  reserve, equipment and stocking, vendors paid before due, merchant fees,
  payables movement, non-cash items — with a residual line and the top three
  drivers named. Read-only. Use when the owner says "QuickBooks says I made
  money last month, why is my cash lower," "why is my cash declining while
  I'm profitable," "profit vs cash," "where did the profit go," or "bridge
  profit to cash."
---

# Cash Bridge

Profit is an accounting opinion about a month; the operating balance is what
actually cleared and when. The bridge lists every reason the two differ,
with amounts from the source that knows them: the books for income, AR and
AP; the bank for what left the account and when. Nothing here proposes or
moves money.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Pick the month"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

## Step 1 — Pick the month

Default: the last full calendar month, resolved from the actual current
date. If the owner names a month or quotes a profit figure ("I made $9k last
month"), use that month and check their figure against the books in Step 2
— say so if it differs.

## Step 2 — Net income (books)

`get_profit_and_loss` for the month (note the basis; accrual is typical).
Capture net income, and separately: revenue, COGS, depreciation or other
non-cash lines if present, merchant-fee expense.

## Step 3 — Operating cash change (bank)

`list_accounts` → Operating by role. Balances at month end and prior month
end are **derived**, not read: `query_transactions {aggregate: true,
groupBy: "month", dateFrom: <month start>}` on Operating gives each month's
net; closing(M) = current balance − Σ net of every month after M (see
`reference/method.md`). Operating cash change = closing(M) − closing(M−1).
State the current balance and the derivation in one line. Use the same
`groupBy: "month"` pull to list the month's big debits by week if the owner
wants "when".

## Step 4 — Bridge lines

Compute each; a line with nothing behind it is $0, not omitted.

| Line | Source | How |
|---|---|---|
| **ΔAR** (receivables grew = cash not yet received) | books | open AR at month end − open AR at prior month end: `search_invoices` (open balance, by txnDate ≤ each date) less `search_payments` applied by each date. Positive ΔAR reduces cash. |
| **Owner distributions** | bank + books | Operating debits whose descriptor is an owner transfer / distribution (name from the books' equity draw account; `search_transfers`, `search_journal_entries` to equity); equity, never expense. |
| **Owner estimated taxes** | bank | Operating debits with an IRS / estimated-tax stem in the month; not on the P&L. |
| **Sales-tax sweeps to reserve** | bank | Operating debits that are transfers into the Tax Reserve; the tax was never revenue, and the remittance later leaves from the reserve, not Operating. |
| **Equipment / inventory stocking** | books + bank | `search_purchases` / `search_bills` posting to fixed-asset or inventory accounts, plus unusually large parts orders vs the trailing average; capitalized or stocked, so not (fully) in COGS this month. |
| **Vendors paid before due** | books | `search_bill_payments` in the month vs each bill's `dueDate`: dollars paid with the due date after month end = cash that left early. Link `../ap-timing` for the pattern. |
| **ΔAP** (payables grew = cash kept) | books | open AP at month end − prior month end (`search_bills` open). Positive ΔAP adds cash. |
| **Merchant fees netted** | bank vs books | Merchant settlements land net; if the books record deposits gross without fee lines, the difference sits here (see `../month-end-prep`). |
| **Non-cash items** | books | Depreciation, amortization: add back. |
| **Savings sweep / interest** | bank | Transfers to Business Savings out of Operating; interest lands in savings, not Operating. |
| **Residual** | computed | net income − Σ lines − operating cash change; if |residual| > 5% of revenue, look for the missing line before presenting. |

## Step 5 — Present

```
Profit → cash bridge — {Month YYYY}                (books accrual · bank cleared)

Net income (books)                                     +${ni}
  Receivables grew (invoiced, not yet paid)            −${dAR}
  Owner distributions                                   −${dist}
  Owner estimated taxes (from Operating)                −${est}
  Sales-tax swept to the reserve                        −${sweep}
  Equipment / stocking                                  −${equip}
  Vendors paid before due                               −${early}
  Payables grew                                          +${dAP}
  Merchant fees netted at the bank                      −${fees}
  Non-cash (depreciation)                                +${dep}
  Savings sweep                                          −${sav}
  Residual                                               ±${res}
= Operating balance change (bank)                      ${chg}   ({open} → {close})
```

Then one sentence naming the top three drivers by size, and one sentence on
timing: what actually cleared and when — the bank fact — e.g. "the largest
outflow cleared in week 2, before the month's biggest receipt landed in week
4." If a driver is a habit (early vendor payments, skipped sweeps), name the
skill that changes it (`../ap-timing`, `../tax-reserve-check`); if it is
structural (distributions, taxes), say the profit is real but committed.

Example wording (illustrative): *"You did make ~$9k. About $4k of it is
sitting in invoices customers haven't paid yet, $9k went out as a quarterly
distribution, and one equipment bill was paid 18 days before it was due."*

## Degradation

| Missing | Effect |
|---|---|
| quickbooks | Bank-only: show the month's debits grouped by descriptor stem (distributions, taxes, sweeps, equipment vendors) and the balance change; say net income is unavailable. |
| Paywhere | Books-only: show net income vs the books' bank-account movement and label it "per the books, not the bank". |

## Reference

- `reference/method.md` — deriving month-end balances from aggregates; the AR/AP delta queries; residual handling
