---
name: tax-season-organizer
version: 1.0.3
description: >
  Prepares owner income-tax materials as markdown deliverables for the
  accountant, not tax advice. Two modes: (1) quarterly estimated-tax
  calculation — YTD net income from QuickBooks, estimates already paid read
  from the bank's IRS debits, liability and next payment computed with every
  assumption stated for the tax year the owner names; (2) year-end 1099-NEC
  prep — vendor payments from QuickBooks cross-checked against bank ACH/wire
  debits for contractors paid but never booked, with a missing-W-9 list.
  Three calls for the estimate, six for the 1099 list. Owner estimates are
  paid from Operating and are NOT covered by the sales-tax reserve.
  Sales-tax questions (reserve balance, what is due on the 20th, missed
  sweeps, the catch-up transfer) go to tax-reserve-check instead. Use when
  the owner says "quarterly taxes," "estimated tax payment," "how much should
  I set aside for income tax," "1099s," "1099-NEC," "W-9s," "year-end tax
  prep," or "handing materials to my accountant."
---

> **Sales tax is not this skill.** Reserve balance, sales tax collected but
> not remitted, the remittance due, missed sweeps and the catch-up transfer
> are [`../tax-reserve-check`](../tax-reserve-check/SKILL.md). This skill is
> the owner's income-tax estimates and 1099s.

# Tax Season Organizer

> **Framing:** This skill produces prep material for a CPA, not tax advice.
> Say so early and state every assumption explicitly so the accountant can
> adjust. Every year-specific figure (brackets, wage base, due dates) is
> looked up for **the tax year the owner names** and stated in the output —
> nothing in this skill hard-codes a year.

## Quick start

```
User: "what do I owe for estimated taxes this quarter?"
→ In ONE turn, in parallel (3 calls):
    get_profit_and_loss {Jan 1 of the tax year → last day of the last completed quarter}
    list_accounts                                                       (Operating by role)
    query_transactions {accountNumbers:[Operating], direction:"debit",
                        descriptionContains:"IRS", dateFrom:<Jan 1 of the tax year>}   (estimates already paid; also try EFTPS / USATAXPYMT)
→ Compute SE tax + federal estimate − payments made ÷ quarters remaining
→ write_file tax/estimate-{YYYY}-Q{n}.md
→ Reply: "Estimated Q{n} payment due {date}: $X — assumptions in the file."

User: "I need to send out 1099s"
→ In ONE turn, in parallel (5 calls):
    search_vendors                                                      (is1099 flag, EIN on file)
    search_bill_payments {tax year}   search_purchases {tax year}       (what the books say was paid, per vendor)
    query_transactions {direction:"debit", dateFrom:<Jan 1>, dateTo:<Jun 30>}   (bank ACH/wire out, first half)
    query_transactions {direction:"debit", dateFrom:<Jul 1>, dateTo:<Dec 31>}   (second half — a year does not fit in one result)
→ Optional 6th: get_transaction_detail on ONE unmatched counterparty if the descriptor is unreadable
→ Aggregate per payee, apply the $600 threshold, W-9 status
→ write_file tax/1099-prep-{YYYY}.md
→ Reply: candidate count, missing W-9 count, bank-only payees, the file path.
```

## Determine mode

Read the owner's message to decide which path applies:

- **Quarterly estimate** — keywords: estimated payment, quarterly taxes, how much to set aside for income tax, safe harbor, Q1/Q2/Q3/Q4
- **Sales tax** (reserve, collected-not-remitted, "due on the 20th", sweeps) — not here: route to `../tax-reserve-check` and stop.
- **Year-end 1099 prep** — keywords: 1099, 1099-NEC, year-end, contractors, W-9, send 1099s, file 1099s
- **Combined** — "year-end summary" needs both. Run 1099 prep first (it drives the most action items), the estimate second.

If the ask is ambiguous, ask once: "Are you looking at your estimated tax payment for this quarter, or are you preparing 1099s for your contractors — or both?" Also confirm the **tax year** if it is not obvious from the date (a January "1099s" ask means last year).

---

## Path 1: Quarterly estimated tax (3 calls)

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Read the books and the
bank"), then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

### 1. Read the books and the bank in ONE turn

- `get_profit_and_loss` from January 1 of the tax year through the last day
  of the most recently completed quarter. Capture **total income**, **total
  expenses**, **net ordinary income**. Note the accounting basis if the
  report states it.
- `list_accounts` → Operating (primary checking, by role).
- `query_transactions {accountNumbers: [Operating], direction: "debit",
  descriptionContains: "IRS", dateFrom: <Jan 1 of the tax year>}` → the
  estimates already paid. If nothing matches, one retry with `EFTPS` or
  `USATAXPYMT` is allowed (that is the fourth call — say so). List the
  debits found and confirm them with the owner.

Say plainly where the money comes from: **owner estimated taxes are paid
from Operating and are not covered by the sales-tax reserve**, which holds
sales tax only. If QuickBooks is not connected, ask the owner to paste the
P&L's three numbers; if Paywhere is not connected, ask how much has been
paid this year. Field names in
[reference/connector-queries.md](reference/connector-queries.md).

### 2. Calculate the estimated liability

Full math and the assumptions table in
[reference/calculation-assumptions.md](reference/calculation-assumptions.md).
Short version:

1. **Entity check** — an S-corp owner on payroll has withholding on wages
   and no SE tax on them; distributions are not wages. State the entity type
   you assumed (the books' equity accounts hint at it) before step 2.
2. **SE tax** = net profit × 0.9235 × 0.153, the Social Security portion
   capped at the tax year's wage base; half of it is deductible.
3. **Adjusted net** = net profit − (SE tax ÷ 2).
4. **Federal income tax** = adjusted net × the assumed effective rate
   (default 22% unless the owner states a bracket; say so).
5. **Total annual liability** = federal income tax + SE tax, annualized from
   YTD (state the annualization).
6. **Quarterly payment** = (total annual liability − payments made) ÷
   quarters remaining, due on the tax year's next estimated-tax date.
7. **Safe harbor** — note that total payments should reach 100% of the prior
   year's tax (110% if prior-year AGI exceeded the threshold in force for
   that year).

### 3. Write `tax/estimate-{YYYY}-Q{n}.md` (`write_file`, markdown)

Sections, in order:

1. **Header** — "Estimated tax summary — Q{n} {YYYY}"; subline: prepared
   date, "For review by your accountant — not tax advice."
2. **YTD snapshot** — YTD net profit with the date range, annualized net
   profit, assumed entity type (flagged as assumed).
3. **Self-employment tax** — the calculation and the deductible half.
4. **Federal income tax estimate** — adjusted net, assumed rate, the estimate.
5. **Total estimated annual liability**.
6. **Quarterly payment** — liability − payments made (listed, from the bank)
   ÷ quarters remaining, the amount and the due date for the tax year.
7. **Safe harbor note**.
8. **Assumptions** — every one: tax year and where its figures came from,
   rate, entity, annualization, state taxes excluded, deductions not applied
   (QBI, home office, vehicle, depreciation, retirement, health insurance).

Reply in under ten lines: the amount, the due date, the file path, the two
assumptions most likely to move the number.

---

## Path 2: Year-end 1099 prep (≤ 6 calls)

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Read payments from
both sources"), then `TaskUpdate` it to `in_progress` when you begin that
step and `completed` when it's done. This is what drives Cowork's visible
progress display — it does not happen unless you do it explicitly.

### 1. Read payments from both sources in ONE turn

Payments **for services** to individuals or businesses in the tax year; not
goods, refunds or internal transfers.

**QuickBooks (read-only):** `search_vendors` (the `is1099` flag and whether a
tax id is on file), `search_bill_payments` and `search_purchases` for the tax
year. Sum per vendor; keep services (subcontractors, professional fees,
referral partners, rent).

**Paywhere (cross-check):** `query_transactions {direction: "debit",
dateFrom: <Jan 1>, dateTo: <Jun 30>}` and the same for July–December — a
full year rarely fits one result; two halves do. Keep ACH and wire debits;
drop card, payroll-processor and internal-transfer rows. The counterparty is
the descriptor stem (`ACH DEBIT <PAYEE>`, `WIRE OUT <PAYEE>`); call
`get_transaction_detail` on at most **one** row whose descriptor cannot be
read. Then:

- **Bank line matches a QuickBooks vendor** → confirms the record; spot-check the total.
- **Bank line has no QuickBooks vendor** → "possible contractor payment not in the books" for the accountant. Common cause: a contractor paid by wire and never booked.

A bank does not issue 1099-Ks; the bank rows are for completeness. The
1099-NEC obligation lives with the business.

### 2. Aggregate by payee

Sum across sources per payee. Do not auto-merge similar names ("J. Smith"
vs "John Smith LLC") — flag likely duplicates for review.

### 3. Apply the $600 threshold

- **1099-NEC**: any payee paid ≥ $600 for services.
- **1099-MISC**: any payee paid ≥ $600 for rent, attorney fees, prizes.
- **Near threshold**: $400–$599 — flag for the accountant.

Corporations generally do not receive a 1099-NEC — note it, never
auto-exclude (attorneys and some entities are exceptions).

### 4. Check W-9 status

Per flagged payee: **on file** (tax id recorded in QuickBooks), **missing**
(collect before filing), **unknown** (bank-only payee, no vendor record).

### 5. Write `tax/1099-prep-{YYYY}.md` (`write_file`, markdown)

Sections, in order:

1. **Header** — "1099 prep list — {YYYY}"; subline: prepared date, "For
   review by your accountant — not tax advice."
2. **Summary** — payees paid, 1099-NEC candidates, missing W-9s (filing
   deadline: January 31 of the following year), near-threshold count,
   bank-only payees.
3. **1099-NEC candidates table** — payee, total paid, sources (books / bank
   ACH / bank wire), W-9 status, notes.
4. **Missing W-9 action list**.
5. **Near-threshold table**.
6. **Bank reconciliation note** — every counterparty paid from the bank with
   no vendor record in the books.
7. **Next steps checklist** — collect W-9s, confirm unknowns, review
   near-threshold, confirm corporation exemptions, book the bank-only
   payments, file 1099-NEC and the 1096 transmittal by January 31.

Reply in under ten lines: the counts, the bank-only payees by name, the file
path.

---

## Output location

Markdown only, written with `write_file` to the working folder:
`tax/estimate-{YYYY}-Q{n}.md` and `tax/1099-prep-{YYYY}.md`. Nothing is
emailed or filed.

## Guardrails

- **Not tax advice.** Open every deliverable with "Prepared for review by
  your accountant — not tax advice." In the document header, not just in chat.
- **State every assumption**, including the tax year and where its brackets,
  wage base and due dates came from.
- **Don't merge payees automatically.** Flag likely duplicates.
- **Don't file anything.** The output is prep material.
- **Don't move money.** Paying an estimate is a payment the owner stages and
  approves on the bank's page ([`../pay-bills`](../pay-bills/SKILL.md));
  this skill only computes.
- **Corporation exemption is a judgment call.** Note it; don't auto-exclude.
- **Stay within the call budget**: three calls for the estimate, six for the
  1099 list. Never pull a full year of bank debits in one call.

## Reference files

- [reference/calculation-assumptions.md](reference/calculation-assumptions.md) — SE tax and federal estimate math, relative due dates, the assumptions list
- [reference/connector-queries.md](reference/connector-queries.md) — exact calls per mode and the paste-in fallback
- [reference/gotchas.md](reference/gotchas.md) — Good / Bad patterns for common failure modes
- [reference/examples/quarterly-estimate.md](reference/examples/quarterly-estimate.md) — worked quarterly estimate (year-relative)
- [reference/examples/year-end-1099.md](reference/examples/year-end-1099.md) — worked 1099 prep (year-relative)
