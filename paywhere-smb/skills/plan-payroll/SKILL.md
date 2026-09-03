---
name: plan-payroll
version: 1.0.4
description: >
  Answers "am I good for payroll?" from the bank first: the live operating
  balance made reserve-aware (minus the sales-tax reserve shortfall and
  pending authorizations), the next payroll estimated from the processor's
  last two debits and corroborated by the payroll-summary email and the
  payroll journal entries, every bill due on or before payroll day, and
  settlement detection so a customer whose money already landed is never
  chased. Shows the headroom equation, then ranked recovery options —
  collect named invoices (drafts), hold habitually-early bills, or a savings
  top-up staged as a transfer line for passkey approval — and a cheap "check
  again" re-run when money lands mid-conversation. Falls back to a labeled
  forecast without the bank. Use when the owner says "am I good for payroll
  Friday," "can I make payroll," "will payroll clear," "am I good for
  payroll," or "is payroll covered." NOT for "when is payroll" or "what was
  the last payroll" — those are a calendar or one bank query, no skill.
---

# Plan Payroll

Two mechanisms for one question. **Mode A** (bank connected) is a live
verdict from cleared cash. **Mode B** (no bank) is a modeled forecast from the books, labeled as an estimate.
Always say which one the owner is getting.

> Payments and transfers are only ever **staged**: `make_batch_payment`
> returns a `https://<bank host>/confirm/<id>/<nonce>` URL, which is printed
> verbatim as the approval step — the owner approves with a passkey and only
> then does money move. **Never claim money has moved.** A savings top-up is a
> `{rail: "transfer", fromAccountNumber, toAccountNumber, amount}` batch
> item, **never `transfer_funds`**. See
> [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md).

## Quick start

```
User: "am I good for payroll Friday?"
→ list_accounts → Mode A. get_account_balance (operating, tax reserve, savings)
→ Reserve shortfall (true-available method) + pending → what is actually spendable
→ Next payroll: last two processor debits (net + tax rows) ⇄ payroll-summary email ⇄ journal entry
→ Bills due on/before payroll date: search_bills; the week after listed separately (calendar: remittance, estimates)
→ Settlement detection: unrecorded bank credits × open invoices → landed vs outstanding
→ Verdict equation. If short: collect (drafts) · hold early-pay bills · top-up (staged, URL)
→ "check again" → re-pull balance + credits, say what changed
```

## Arguments

- `--payroll-date` (default: the next Friday strictly after today, from the
  actual date; the processor's calendar, if the payroll email or calendar
  shows a different payday, wins).
- `--horizon` (default `30`) — Mode B window and Mode A's "after payroll"
  context.

## Mode selection

`list_accounts` responds → **Mode A** (QuickBooks still needed for bills and
AR). Missing → **Mode B**, and say what is lost without the bank: no live
balance, no settlement detection, bands instead of a verdict.

**Progress tracking:** once the mode is decided, call `TaskCreate` once per
sub-step in that mode's section (subject = the sub-step's name, e.g.
"A1. Real-time position"), then `TaskUpdate` it to `in_progress` when you
begin that sub-step and `completed` when it's done. This is what drives
Cowork's visible progress display — it does not happen unless you do it
explicitly. Don't create tasks for the mode you did not enter.

## Mode A — bank connected

### A1. Real-time position, reserve-aware

- `list_accounts` → operating (primary checking), tax reserve (savings named
  for tax), business savings — by name/type/`isPrimary`, never by number.
  More than one plausible operating account → ask which funds payroll.
- `get_account_balance` on each.
- **Spendable** = Operating − sales-tax reserve shortfall (pending card authorizations are already netted out of the bank balance; name them, do not subtract them)
  authorizations, per
  [`../business-pulse/reference/true-available.md`](../business-pulse/reference/true-available.md)
  (the full method is [`../tax-reserve-check`](../tax-reserve-check/SKILL.md)).
  The reserve shortfall is money already owed to a tax authority; it is not
  payroll money. Business Savings is backstop capacity, reported separately,
  never counted. The Tax Reserve is never a source.

### A2. The payroll number

Estimate the next run from the bank: `query_transactions {direction:
"debit", descriptionContains: "<processor name, e.g. GUSTO>", dateFrom: <8
weeks ago>}` → the last two runs' net-pay and tax debits (plus any monthly
fee). Corroborate: Gmail `search_threads` for the processor's payroll-summary
email (register attached; read-only) and `search_journal_entries` for the
payroll entries in the books. If the three disagree, say which you used and
why (the bank for cash timing; the email for the upcoming run if it already
exists). Overtime seasons make the last run a better guide than the average;
say so when the two recent runs differ materially.

### A3. Bills due on or before payroll date

`search_bills` (open, due on/before the payroll date, plus everything
overdue) with holds from
[`../ap-timing/reference/early-payment-method.md`](../ap-timing/reference/early-payment-method.md)
(a not-yet-due bill from a habitually-early vendor is **not** an obligation
this week); the calendar (`list_events`) for the sales-tax remittance,
quarterly estimates, insurance and other dated debits; recurring auto-debits
from the bank's last month (rent, utilities, insurance, subscriptions) that
fall in the window; anything the owner names. Itemize and have the owner
confirm the list; the verdict is only as honest as this table. State the
window edge explicitly.

### A4. Settlement detection

A customer whose money already landed is collected even if the books have
not recorded it. **Never chase a customer who paid this morning.**

1. Open AR: `get_aged_receivables` + `search_invoices` (open balance).
2. Posted credits: `query_transactions {direction: "credit", dateFrom: <at
   least 14 days back, through the Monday of the last complete week>,
   status: ["posted"]}`; slice the range if `truncated`.
3. Drop credits the books already recorded (`search_payments`, same window:
   amount + date ±2 business days + customer). Recorded partials are already
   in the open balance — never match them again.
4. Match the remaining credits to open invoices on amount (open balance
   ±$0.50) then counterparty (`ACH CR <name>`, `MOBILE CHECK DEPOSIT
   <check#>`, `WIRE IN`). Card payments arrive net in grouped merchant
   deposits — match those via the books' Deposit, not by amount. Ambiguous
   → ask.
5. Partial credit → only the received amount is collected.
6. **Received but not booked**: cross it out of collectible, do **not** add
   it to cash (it is already inside A1), narrate the QuickBooks payment
   application in one line (the QuickBooks connector is read-only; it
   reappears until the bookkeeper applies it). _E.g. a church customer's check deposited Monday whose
   invoice is still open._

Output: open AR split into **already landed** (with bank evidence) and
**genuinely outstanding** (named, with amounts, days late and profile from
[`../ar-health/reference/profiles.md`](../ar-health/reference/profiles.md)).

### A5. Verdict

```
Operating balance (cleared)                     $A
− tax-reserve shortfall                          $R    ← owed to the state, not yours
  (pending card authorizations $P are already netted by the bank — shown, not subtracted)
= spendable                                      $S
− payroll (net + taxes) on <date>                $W    ← A2
− bills due on/before <date>                     $B    ← A3, confirmed
= headroom after payroll                         $S − $W − $B

Next up (NOT in the headroom): {bills, estimates, remittance due in the 7 days after payroll, each dated}
```

The headroom is what is left after payroll and the bills that fall due
before it. Obligations that land in the week after payroll (a vendor bill
due the following Thursday, the 15th estimate, the 20th remittance) are
named and dated under "Next up" so the owner sees them coming, but they are
not subtracted — they are paid from the cash that lands between now and
then, and folding them in turns a clear yes into a muddled maybe.

No unlanded inflow is counted in the verdict; outstanding AR is the recovery
path. If short, rank the options:

- **(a) Collect named invoices** — which ones close the gap and by when,
  given each customer's profile; offer reminder **drafts** via
  [`../invoice-chase`](../invoice-chase/SKILL.md) (Gmail `create_draft`
  only, owner approves the set, owner sends). Lead with this.
- **(b) Hold habitually-early bills** — the not-yet-due bills the owner would
  normally pay this week; what holding them to the due date keeps in the
  account ([`../ap-timing`](../ap-timing/SKILL.md)).
- **(c) Savings → operating top-up** — quote the Business Savings balance
  and the exact amount; if the owner wants it, stage it as one
  `make_batch_payment` with a `{rail: "transfer", fromAccountNumber:
  <savings>, toAccountNumber: <operating>, amount}` item (exact unmasked
  numbers from `list_accounts`), print `confirmation_url`
  + `confirmation_title` verbatim, and say nothing has moved until the
  passkey approval. Never the Tax Reserve; never `transfer_funds`.

If covered: say so, show the headroom and what is left after the week's
other obligations, and ask whether to chase outstanding AR anyway.

### A6. "Check again"

When money is expected to land (a customer says the payment went out), re-run **A1
and A4 steps 2–6 only**: `get_account_balance` on operating and
`query_transactions {direction: "credit", dateFrom: <yesterday>, status:
["posted"]}`. Diff against the previous pass, recompute A5, and say what
changed in one sentence: which credit landed, from whom (descriptor), and
the new headroom. If nothing changed, say that. Do not make the owner
re-confirm A3 unless they say it changed.

## Mode B — no bank (short)

1. Run [`../cash-flow-snapshot`](../cash-flow-snapshot/SKILL.md) for the
   horizon: books-only, labeled **estimate**, with the payroll-week risk
   line. 2. If short, run [`../invoice-chase`](../invoice-chase/SKILL.md)
   (drafts only, its own gates) and show whether the top invoices would close
   the gap. Restate: no settlement detection without the bank, so verify
   before sending; offer to re-run in Mode A once Paywhere is connected.

## Gates

- **Drafts only** — Gmail `create_draft`; never send.
- **Transfers are staged, never executed here** — a transfer line in
  `make_batch_payment`, URL printed, passkey on the bank. Never
  `transfer_funds`; never from the Tax Reserve.
- **No QuickBooks writes** — narrate the payment application.
- **Estimates are labeled** — any modeled line says so.
- **A connector dying mid-run**: say which, offer retry / degrade / stop.

## Edge cases

- Payday on a weekend/holiday → ask whether the processor moves it earlier.
- Multiple operating accounts → confirm which fund payroll; sum only those.
- A credit matching two invoices → show both, ask.
- `truncated: true` → slice the date range before concluding.
- QuickBooks missing in Mode A → live balances, owner-stated obligations
  (labeled), no settlement matching.
- Nothing outstanding but still short → options (b) and (c) only; say
  collections cannot close it.

## Output

End with a one-paragraph recap: mode and why, the equation with numbers,
options surfaced and which the owner chose, drafts created (to whom), any
staged transfer with its URL and "nothing has moved until you approve".

## Reference

- [`../_shared/APPROVAL.md`](../_shared/APPROVAL.md) · [`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md)
- [`../tax-reserve-check/SKILL.md`](../tax-reserve-check/SKILL.md) — the reserve shortfall in full
- [`../ar-health/SKILL.md`](../ar-health/SKILL.md) · [`../invoice-chase/SKILL.md`](../invoice-chase/SKILL.md) · [`../ap-timing/SKILL.md`](../ap-timing/SKILL.md) · [`../cash-flow-snapshot/SKILL.md`](../cash-flow-snapshot/SKILL.md)
