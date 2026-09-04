---
name: plan-payroll
version: 1.0.5
description: >
  Answers "am I good for payroll?" from the bank: the live Operating balance
  made reserve-aware (minus the sales-tax reserve shortfall; pending
  authorizations named, never subtracted), the next payroll run read from the
  processor's debit pattern at the bank, every open bill due on or before the
  pay date (not-yet-due bills from habitually-early vendors excluded), and a
  landed-but-unbooked check so a customer whose money already arrived is
  never chased. Six reads in one turn, the headroom equation with every
  number shown, then the recovery options if short: collect named invoices,
  hold what is not yet due, or a Business Savings to Operating top-up staged
  as a transfer line for passkey approval. No verdict without the bank. Use
  when the owner says "am I good for payroll Friday," "can I make payroll,"
  "will payroll clear," "am I good for payroll," or "is payroll covered." NOT
  for "when is payroll" or "what was the last payroll" — those are one bank
  query, no skill.
---

# Plan Payroll

One question, one equation, from cleared cash. The bank says what is in the
account and what payroll costs; the books say what else is due before payday
and what is owed to the business. No unlanded inflow is ever counted.

> Payments and transfers are only ever **staged**: `make_batch_payment`
> returns a `https://<bank host>/confirm/<id>/<nonce>` URL, which is printed
> verbatim as the approval step — the owner approves with a passkey and only
> then does money move. **Never claim money has moved.** A savings top-up is a
> `{rail: "transfer", fromAccountNumber, toAccountNumber, amount}` batch
> item, **never `transfer_funds`**. See
> [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md).

## Quick start — six reads in one turn, one call on yes

```
User: "am I good for payroll?"
→ In ONE turn, in parallel (all six reads at once — never one after another):
    list_accounts                                                                          (Operating, Tax Reserve, Business Savings; balances; exact numbers)
    query_transactions {direction:"debit", dateFrom:<8 weeks ago>, status:["posted"], limit:250}   (all accounts: the processor's runs on Operating + the last remittance debit on the reserve)
    get_sales_tax_collected {date_from:<1st of last month>}                                (reserve shortfall — the books side in one call)
    get_vendor_payment_timing                                                              (open bills with due dates; which vendors are habitually paid early)
    get_aged_receivables                                                                   (open AR — the recovery path, never cash)
    query_transactions {accountNumbers:[<Operating>], direction:"credit", dateFrom:<14 days ago>, status:["posted"]}   (landed-but-unbooked)
→ headroom = Operating − reserve shortfall − next payroll − bills due on/before the pay date
→ Reply: the headroom first, the equation, "Next up", the options if short, "Stage the top-up?"
User: "yes"
→ ONE make_batch_payment {payments:[{rail:"transfer", fromAccountNumber:<Business Savings>,
                                     toAccountNumber:<Operating>, amount:<top-up>}]}   → confirmation_url renders
→ One closing line: staged, nothing has moved.
```

Nothing else is read: no email, no journal entries, no calendar, no forecast.
If `list_accounts` lacks balances, `get_account_balance` joins the same turn.
Budget: about 30 seconds; seven calls at most including the stage.

## Sources of truth

- **Paywhere** says what is in the account, what the last payroll runs cost
  and when they hit, what landed from customers, and stages the top-up.
- **QuickBooks** (read-only) says what is due before payday
  (`get_vendor_payment_timing`), what is owed to the business
  (`get_aged_receivables`) and how much of the reserve is spoken for
  (`get_sales_tax_collected`).

Without Paywhere: **no verdict** — say so in one line, then list what the
books say is due on or before the pay date and stop. Without QuickBooks:
the equation runs with bills = "owner-stated (unconfirmed)" and no reserve
shortfall figure — say both.

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Read everything at
once"), then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

### 1. Read everything at once

Issue the six reads in the Quick start in **one turn**. Accounts by role,
never by number: Operating = primary checking; Tax Reserve = the savings
named for tax or reserve; Business Savings = any other savings. More than one
plausible Operating account → ask which funds payroll, once. If the 8-week
debit pull comes back `truncated`, re-issue it for Operating only with the
processor's stem once you have seen it.

### 2. The payroll number and the pay date

From the Operating debits, the payroll processor is the payee whose debits
recur on a fixed cadence (weekly or every two weeks, same weekday) as a pair
or trio posting within two days — net pay, taxes, sometimes a fee. If the
owner has named the processor, filter on that stem. **Next payroll** = the
last run's total; if the two most recent runs differ by more than about 15%,
use the larger and say why (overtime seasons make the last run the better
guide). **Pay date** = the last debit date plus the cadence, or the date the
owner named. No processor pattern in 8 weeks → ask once for the amount and
date and label the verdict "owner-stated payroll".

### 3. The reserve shortfall

`get_sales_tax_collected` was pulled from the 1st of last month — the widest
the window can be. The window is the months not yet remitted: the reserve's
last remittance debit (in the same 8-week debit pull — a debit to the
revenue agency, not a transfer) tells you which. Debit last month → window
= 1st of last month … today; debit this month → 1st of this month … today,
re-totalled from `byPayment[]` (`txnDate` on or after the 1st). Shortfall =
`collected.total` − Tax Reserve balance, floor 0. Money already owed to a
tax authority is not payroll money. Full method:
[`../tax-reserve-check/reference/true-available.md`](../tax-reserve-check/reference/true-available.md).

### 4. Bills due on or before the pay date

From `get_vendor_payment_timing`: every `openBills[]` row with `dueDate` on
or before the pay date, plus everything overdue. `notYetDue[]` rows are not
obligations this week — and a not-yet-due bill from a vendor flagged
`habituallyPaidEarly` is exactly the kind the owner would normally pay early;
name it under "hold" so it stays out of the equation. Bills due in the seven
days after payday go under **Next up**, dated, not subtracted.

### 5. Landed but not booked

Match the 14-day Operating credits against `get_aged_receivables` open
balances by amount (± $0.50) and counterparty in the descriptor. A match is
money that already landed: it is already inside the Operating balance, so it
is **not** added to cash, but it is crossed out of collectible AR and the
QuickBooks payment application is narrated in one line (the connector is
read-only). **Never chase a customer who paid this week.** Ambiguous match →
show both candidates, do not decide.

### 6. Verdict

```
Operating balance (cleared)                     $A
− tax-reserve shortfall                          $R    ← owed to the tax authority, not yours
= spendable                                      $S
− next payroll (net + taxes) on <pay date>       $W    ← last processor run
− bills due on/before <pay date>                 $B    ← open bills, holds excluded
= headroom after payroll                         $S − $W − $B

Next up (NOT in the headroom): {bills, remittance, other dated debits in the 7 days after payday}
```

Pending card authorizations are already netted by the bank — name them if
the account payload shows them, never subtract. Business Savings is backstop
capacity, reported separately, never counted; the Tax Reserve is never a
source. If the headroom is positive: say so, show the number, and ask
whether to chase outstanding AR anyway. If negative, rank the options:

- **(a) Collect named invoices** — the genuinely outstanding invoices (step
  5) that would close the gap, by amount and days late; reminder **drafts**
  via [`../invoice-chase`](../invoice-chase/SKILL.md) if the owner wants them
  (Gmail `create_draft` only; the owner sends). Lead with this.
- **(b) Hold what is not yet due** — the not-yet-due bills the owner would
  normally pay this week (step 4) and what holding them to the due date
  keeps in the account.
- **(c) Business Savings → Operating top-up** — quote the savings balance and
  the exact amount that brings the headroom to zero (or the owner's cushion).
  End the reply with exactly **"Stage the top-up of $X from savings?"**

### 7. Stage — ONE `make_batch_payment`

On the owner's yes: `{payments:[{rail:"transfer", fromAccountNumber:<Business
Savings, exact unmasked>, toAccountNumber:<Operating, exact unmasked>,
amount}]}`. A single internal transfer needs no dry run; the line in the
reply is the gate. The bank's card and link render from the result, so the
reply after it is one to three lines: `confirmation_title` over
`confirmation_url`, the URL in plain text too, and *"Nothing has moved —
open the link and approve with your passkey."* A rejected call comes back
as `{ error, invalid_items[] }` — fix the line and re-submit once. Never
invent a URL. Never from the Tax Reserve; never `transfer_funds`.

## Reply template (under 25 lines; the number first)

```
Headroom after payroll on {pay date}: ${H}   ({covered / short ${-H}})

Operating (cleared)                 ${A}
− tax-reserve shortfall             ${R}   (owed to the tax authority)
= spendable                         ${S}
− payroll {pay date} (last run)     ${W}
− bills due on/before {pay date}    ${B}   {n} bills: {vendor ${x} due {d}, …}
= headroom                          ${H}

Held (not yet due, normally paid early): {vendor ${y} due {d}, …}
Already landed, not yet booked: {customer ${z} on {d}} — not chased, not double-counted
Next up (not in the headroom): {item ${v} on {d}, …}
Business Savings ${bs} · pending authorizations ${p} already netted by the bank

If short: (a) collect {invoice, customer, ${amt}, {days} late} … (b) hold {…} keeps ${…}
          (c) transfer Business Savings → Operating ${X}. Stage the top-up of ${X} from savings?
```

## Edge cases

- **"Check again" / money just landed** → one `get_account_balance` on
  Operating (and one 1-day credit query if the owner names the payer);
  recompute the equation and say what changed in one sentence.
- Payday on a weekend or holiday → the processor debits earlier; use the
  last run's actual weekday and say so.
- Multiple Operating accounts → confirm which fund payroll; sum only those.
- A credit matching two invoices → show both, ask.
- Nothing outstanding but still short → options (b) and (c) only; say
  collections cannot close it.
- The processor's debit lands *on* payday (same-day debit) → the pay date is
  the deadline; the cash must be there the night before.

## Gates

- **Transfers are staged, never executed here** — a transfer line in
  `make_batch_payment`, URL printed, passkey on the bank. Never
  `transfer_funds`; never from the Tax Reserve.
- **Drafts only** — if invoice-chase is used, Gmail `create_draft`; never send.
- **No QuickBooks writes** — narrate the payment application.
- **No unlanded inflow in the verdict** — outstanding AR is the recovery
  path, never cash.
- **No verdict without the bank.**

## Reference

- [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md) · [`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md)
- [`../tax-reserve-check/reference/true-available.md`](../tax-reserve-check/reference/true-available.md) — the reserve shortfall, short form; [`../tax-reserve-check/SKILL.md`](../tax-reserve-check/SKILL.md) in full
- [`../invoice-chase/SKILL.md`](../invoice-chase/SKILL.md) — reminder drafts for option (a) · [`../ap-timing/SKILL.md`](../ap-timing/SKILL.md) — vendor payment habits behind option (b)
