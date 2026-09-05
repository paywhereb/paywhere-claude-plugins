---
name: tax-reserve-check
version: 1.0.6
description: >
  Answers "how much of my balance is actually mine" for a business that
  collects sales tax and parks it in a separate reserve account: the sales
  tax inside the payments RECEIVED in the months not yet remitted (one
  QuickBooks cash-basis report, split by tax item) against the Tax Reserve
  balance at the bank, the shortfall, the sweep days that were skipped, true
  available cash (Operating minus the shortfall), and the catch-up transfer
  Operating to Tax Reserve staged as a proposal the owner approves on the
  bank's /confirm page. Four reads in one turn, one staged transfer. Not tax
  advice. Use when the owner says "how much of my balance is actually mine,"
  "how much of my cash is really mine," "what's reserved for taxes," "is my
  tax reserve enough," "am I holding enough for sales tax," "what do I owe on
  the next remittance," or "did I miss a tax sweep." NOT for "show my
  balances" or "what's my balance" — those are one list_accounts call and a
  two-sentence answer, no skill.
---

# Tax Reserve Check

The bank knows how much actually sits in the Tax Reserve today. The books
know how much sales tax was inside the payments that landed. This skill puts
the two together, names the gap, names the sweep days that caused it, and
stages the fix for approval. It owns the full method;
[`reference/true-available.md`](reference/true-available.md) is the short
form other skills link to.

> **Not tax advice.** Rates, jurisdictions and what is taxable are read from
> the books (the tax items on the invoices). Say so in the output; the
> owner's CPA owns the rules.

> `make_batch_payment` **never moves money**: it stages the transfer on the
> owner's open proposal and returns a confirmation URL of the form
> `https://<bank host>/confirm/<id>/<nonce>`. **Print that URL verbatim as
> the approval step**; the owner approves with a passkey, and only then does
> money move. **Never claim money has moved** — say "staged" / "awaiting your
> approval". Internal transfers are staged as a `{rail: "transfer",
> fromAccountNumber, toAccountNumber, amount}` item, **never
> `transfer_funds`**. Full path: [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md).

## Quick start — four reads in one turn, one staged transfer

```
User: "how much of my balance is actually mine?"
→ Round 1 — two reads in parallel, never one after another:
    list_accounts                                                                       (roles + balances + exact unmasked numbers)
    get_sales_tax_collected {date_from:<1st of last month>}                             (tax inside payments RECEIVED; total, byItem, byWeek, byPayment)
→ Round 2 — the moment list_accounts returns, both in parallel:
    query_transactions {accountNumbers:[<Tax Reserve>], direction:"debit",
                        descriptionContains:<remittance stem>, dateFrom:<90 days ago>, limit:5}   (last remittance → remittance day, month last paid)
    query_transactions {accountNumbers:[<Tax Reserve>], direction:"credit",
                        dateFrom:<12 months ago>, status:["posted"], limit:200}         (sweep history → sweep weekday, missed sweeps)
   `query_transactions` takes EXACT unmasked account numbers and reads EVERY account when
   `accountNumbers` is omitted or empty, so a scoped read cannot go in the same round as the
   `list_accounts` that supplies the number. Never guess it and never leave the field empty to
   keep one round: an unscoped read folds the owner's own transfers (tax sweeps, savings moves)
   into the totals, and they do not net out — a transfer out is a debit whether or not it comes
   back somewhere else. If you have already read unscoped, re-read scoped rather than reasoning
   from the wide number, and do not narrate the correction to the owner.
→ Window from the remittance debit · collected = the report cut to the window · shortfall = collected − reserve, floor 0
→ Reply: true available first, the terms, the missed sweep days, ONE transfer line, "Stage the catch-up?"
User: "yes"
→ ONE make_batch_payment {payments:[{rail:"transfer", fromAccountNumber:<Operating>,
                                     toAccountNumber:<Tax Reserve>, amount:<shortfall>}]}   → confirmation_url renders
→ One closing line: staged, nothing has moved.
```

If `list_accounts` does not carry balances, add `get_account_balance` for
Operating and the Tax Reserve to the **same** turn. Nothing else is read: no
balance sheet, no ledger, no calendar, no per-invoice loop, no pending pull.
Budget: about 30 seconds, at most six calls including the stage.

## Sources of truth

- **QuickBooks** (read-only): `get_sales_tax_collected` is the whole books
  side — sales tax on payments *received* in the window, cash basis,
  `collected.total`, `collected.byItem` (one entry per tax item, e.g. per
  jurisdiction), `byWeek[]` (Monday–Sunday by payment date) and
  `byPayment[]`. Never rebuild it from `search_payments` + `read_invoice`.
- **Paywhere**: the reserve balance, the remittance debits (which month was
  last paid, and on what day), the sweep credits (which weekday the owner
  sweeps, and which weeks were skipped), and the staged transfer.

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Read everything at
once"), then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

### 1. Read everything at once

Issue the four reads in the Quick start in **one turn**. Identify accounts by
role, never by number: **Operating** (the primary checking), **Tax Reserve**
(the savings account whose name mentions tax or reserve), **Business
Savings** (any other savings — reported, never touched). If no account reads
as a tax reserve, run the rest as "collected vs nothing set aside" and stage
nothing.

The remittance stem is the revenue agency's name as it appears on the
reserve's debits (try `REVENUE`, then `TAX`; read the rows — a remittance is
a debit to a government payee, not a transfer out). If the owner has told
you the stem, use it. `reference/method.md` lists patterns to try.

### 2. The window and the remittance day

The window is the **months whose tax has not been remitted yet**, never "the
days since the last debit". A remittance on or after day D of month M pays
month M−1, so **the window starts on the 1st of the month the last
remittance debit posted in** and runs to today:

- last debit dated **last month** → window = 1st of last month … today
  (before this month's remittance day);
- last debit dated **this month** → window = 1st of this month … today (on or
  after it).

D = the day-of-month of that debit; the next remittance is day D of the
coming month (or of this month, if today is before D and last month is still
unpaid). No remittance debit in 90 days → use the 1st of last month, take D
as unknown, say so in one clause, and let the owner correct it once.

The report was pulled from the 1st of last month — the widest the window can
be. If the window turns out to start this month, re-total from `byPayment[]`
(`txnDate` on or after the 1st). When the reply needs the per-item split for
that shorter window, one follow-up `get_sales_tax_collected {date_from:<1st
of this month>}` is the fifth read — still within budget.

### 3. Shortfall and the next remittance

```
shortfall = max(0, collected.total (window) − Tax Reserve balance)
```

Show what is due on the next remittance by tax item (`collected.byItem`) and
whether the reserve covers it today. If short, say by how much and how many
days remain to day D.

### 4. Sweep day and missed sweeps

The 12-month reserve **credits** are the sweep history (transfers in — a
descriptor with the reserve's name or `TRANSFER`; ignore interest). The
**sweep weekday** is the weekday most of those credits post on; with fewer
than three credits there is no cadence — list what you found and ask once
which day the owner sweeps. Walk every occurrence of that weekday from the
earliest credit to the last complete week: no credit within one business day
→ a **missed sweep**. Name the dates; do not just count them. For weeks
inside the report window, a sweep well under that week's `byWeek.collected`
is a **short sweep** — note it, it is not a miss. Exclude the current,
incomplete week.

### 5. True available cash

```
true available = Operating balance − shortfall
```

Business Savings is not in the formula. The bank's balance is already net of
pending card authorizations: if the account payload shows a pending or
available figure, name it in one clause; never spend a call on it and never
subtract it. Owner income-tax estimates are paid from Operating, not the
reserve — `../tax-season-organizer` covers them; do not compute them here.

### 6. Propose the catch-up — ONE `make_batch_payment`

If `shortfall > 0`, the reply ends with one line — Operating → Tax Reserve,
amount = shortfall, why (the missed sweep days) — and exactly **"Stage the
catch-up?"** A single internal transfer needs no dry run; the line in the
reply is the gate. On the owner's yes, ONE call:

```json
{ "payments": [ { "rail": "transfer",
                  "fromAccountNumber": "<Operating, exact unmasked from list_accounts>",
                  "toAccountNumber":   "<Tax Reserve, exact unmasked>",
                  "amount": <shortfall> } ] }
```

The bank's card and link render from the result; the reply after it is one
to three lines: `confirmation_title` over `confirmation_url`, the URL in
plain text too, and *"Nothing has moved. Approve on the bank's page with
your passkey; I can verify the transfer posted afterwards."* A rejected call
comes back as `{ error, invalid_items[] }` — fix the line and re-submit once.
Never invent a URL. If `shortfall == 0`, say the reserve is funded and by
how much it exceeds what is owed. Never propose moving money **out** of the
reserve for anything but a remittance; never touch Business Savings here.

### 7. After the owner approves — verify on request

"I approved it" → `query_transactions {accountNumbers:[<Tax Reserve>],
direction:"credit", dateFrom:<today>}` once, match the amount, report what
posted. Never report this before the owner approves.

## Reply template (under 25 lines; the number first)

```
True available today: ${ta}  = Operating ${o} − reserve shortfall ${s}        (not tax advice)

Window {start} … {today} — months not yet remitted (last remittance {date} paid {month}; next due {day D, month})
Collected on RECEIVED payments   {item A} ${x} · {item B} ${y} · total ${t}
Tax Reserve balance              ${r}
Shortfall                        ${s}   ← {n} {weekday} sweeps missed: {dates}
Due {next remittance date}: ${t} — reserve {covers it / short ${s}, {k} days to go}
Business Savings ${b} (not in the formula) · pending authorizations ${p} already netted by the bank

Catch-up: transfer Operating → Tax Reserve ${s}. Stage the catch-up?
```

After the stage, under the card:

```
Staged for approval: Operating → Tax Reserve ${s} — {confirmation_title}
{confirmation_url}
Nothing has moved until you approve this on the bank's page.
```

## Scheduled runs

No owner present: stage the catch-up without asking, print the URL in the run
output, dedupe on the day's output file — see
[`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md). The weekly sweep itself
is [`../tax-sweep-agent`](../tax-sweep-agent/SKILL.md).

## Degradation

| Missing | Effect |
|---|---|
| Paywhere | Stop — no reserve balance, no sweep history, nothing to stage. |
| quickbooks | Report the reserve balance, the sweep history and the next remittance day; say the collected figure cannot be computed; stage nothing. |
| No reserve account | Report collected vs "nothing set aside"; stage nothing; suggest opening one. |

## Approval gates

- **Money moves only on the bank's `/confirm` page with a passkey.** This
  skill stages; it never executes and never says it did.
- **Never `transfer_funds`.** The catch-up is a `transfer` line in
  `make_batch_payment`.
- **Never move money out of the reserve** except a remittance the owner
  asked for; **never touch Business Savings** here.
- **Exact, unmasked account numbers** from `list_accounts`, never typed.

## Reference

- [`reference/method.md`](reference/method.md) — formulas, window rule, descriptor stems, the sweep-day test
- [`reference/true-available.md`](reference/true-available.md) — the short form other skills link to
- [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md) — the approval path in full
- [`../tax-sweep-agent/SKILL.md`](../tax-sweep-agent/SKILL.md) — the scheduled weekly sweep
- [`../tax-season-organizer/SKILL.md`](../tax-season-organizer/SKILL.md) — owner income-tax estimates and 1099s (not sales tax)
