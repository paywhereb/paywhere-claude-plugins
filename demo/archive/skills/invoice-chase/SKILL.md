---
name: invoice-chase
version: 1.0.6
description: >
  Turns overdue receivables into Gmail DRAFTS the owner sends: reads the
  aging report and the open invoices, checks the bank's posted credits so an
  invoice whose money already landed but is not yet applied in the books is
  EXCLUDED rather than chased, ranks customers by open past-due balance, sets
  the tone from where each customer's balance sits in the aging buckets, and
  creates one draft per customer for the top three. Never sends; never writes
  to QuickBooks. Six calls at most, reads in one turn. Use when the owner
  says "who do I call first," "who owes me money and who do I call first,"
  "chase overdue invoices," "follow up on unpaid invoices," "draft
  reminders," or "send reminders" (they become drafts). NOT for "how much is
  owed to me" alone — that is one get_aged_receivables call and a sentence,
  no drafts.
---

# Invoice Chase

The books say who owes; the bank says who already paid. Rank what is
genuinely outstanding, draft one reminder per customer in the tone their
aging earns, and leave the sending to the owner. **Drafts only**: Gmail
`create_draft`; never send, reply or forward. Nothing is written
to QuickBooks (the connector is read-only; any fix is narrated).

## Quick start — three reads + up to three drafts, one owner turn

```
User: "who owes me money and who do I call first?"
→ In ONE turn, in parallel:
    get_aged_receivables {}                                                  (total AR, per-customer buckets)
    search_invoices {criteria:[{field:"Balance", operator:">", value:0}], fetchAll:true}
                                                                             (DocNumber, DueDate, Balance, BillEmail per open invoice)
    query_transactions {direction:"credit", status:["posted"], dateFrom:<120 days ago>, limit:200}
                                                                             (every posted credit since the oldest open invoice — the exclusion lookup)
→ Exclude open balances that match a posted credit (exact amount ± $0.50) — received, not booked
→ Rank customers by collectible past-due balance; tone from the aging buckets
→ create_draft for the top ≤ 3 customers (one each), then the reply: total first, table, one summary line per draft
```

Never pull 12 months of invoices or payments to profile customers: the aging
report's buckets carry the payment behaviour this skill needs. Never call
`search_customers` for emails: the open invoice's `BillEmail` is the AR
contact; if it is empty, create the draft with no recipient and say so.

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Read"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

## Workflow

1. **Read (one parallel turn).** Resolve today from the actual date. The
   three reads above go out together. `dateFrom` for the credits is 120 days
   ago, which covers the report's four 30-day buckets; if `search_invoices`
   returns an open invoice older than that, say its cash was checked from 120
   days only. Roll sub-customer jobs up to the parent customer.

   Degraded modes: **no QuickBooks** → stop; there is no list of who owes.
   **no Paywhere** → no exclusion step: say every draft is unverified against
   the bank and cap drafts at 2. **no Gmail** → run the ranking, list who
   would have been drafted, create nothing.

2. **Exclude what already landed — a lookup, not a glance.** Write down every
   open invoice's `Balance`, then scan every posted credit's amount for an
   exact match within $0.50. A match (descriptor `ACH CR …`, `MOBILE CHECK
   DEPOSIT …`, `WIRE IN …`, a lockbox or bill-pay row) is **received, not
   booked**:
   - exclude the invoice from the chase list and from collectible AR;
   - show the evidence: bank date, amount, descriptor (and the check number
     when the descriptor carries one);
   - narrate the fix in one line: the payment should be applied to the
     invoice in QuickBooks; the connector is read-only.

   The credit usually carries no customer name, so the amount is the key and
   the descriptor is the evidence; a credit that landed before the invoice was
   due still counts. Say what you checked ("{n} open balances against {m}
   posted credits since {date}: {k} matches"). Two open invoices sharing an
   amount → show both, ask, chase neither until the owner picks. Card payments
   settle net inside grouped merchant deposits and never match by amount;
   note them as "card — not matchable at the bank" rather than excluding.

3. **Rank and set the tone.** Collectible past-due balance per customer is
   the rank; days late breaks ties. The top three are the drafts (the top two
   are "call first"). Tone from the aging buckets — the short rule:

   | Where the customer's balance sits | Tone |
   |---|---|
   | most of it Current or 1–30 days | Gentle — a fresh slip, assume oversight |
   | most of it 31–60, or spread across buckets | Neutral — factual, no judgement |
   | most of it 61+ days, or balances in three or more buckets | Firm — direct, names a remit-by date |

   Subject lines and body rules: [`reference/tone-matching.md`](reference/tone-matching.md).
   Explain each rank in plain words: dollars, days late, where the balance
   sits — e.g. "the largest overdue customer: most of its balance is past 60
   days, so the note is firm; a smaller customer whose one invoice slipped
   two weeks gets a gentle one."

4. **Create the drafts, then present.** A draft is inert — nothing reaches a
   customer until the owner presses Send in Gmail — so create them first and
   let the owner review them where they will send them. One `create_draft`
   per customer (to the invoice's `BillEmail`; one email listing every
   overdue invoice — number, amount, due date — and the combined total),
   never more than three, never two to one customer. Then the reply.

## Reply (under 25 lines)

```
Owed to you: ${total from get_aged_receivables} across {n} customers, ${past due} past due.
Checked {n} open balances against {m} posted credits since {date}: {k} already paid, not yet booked.

| # | Customer | Open | Days late | Aging | Tone | Action |
| 1 | {largest overdue customer} | $ | {n} | mostly 61+ | firm | draft in your Gmail Drafts |
| 2 | … | $ | {n} | mostly 1–30 | gentle | draft in your Gmail Drafts |
| — | … | $ | {n} | — | — | excluded — {descriptor} ${amount} on {date}; apply it in QuickBooks |

Call first: {#1} and {#2}. If the three drafted customers pay, ${} comes in.
Drafts (in your Gmail Drafts — edit or delete there; nothing is sent):
  1. To {contact} · "{subject}" · {two-line summary of the body}
  2. …
```

Follow the table with each draft in full only if the owner asks to see them;
the summary lines keep the reply short. Offer to reword, retone or delete
any draft; the owner sends from Gmail.

## Approval gates

- **Never send.** `create_draft` is the only Gmail write; the owner sends.
- **Drafts need no approval.** They are the review step: create them, name
  them, and leave sending to the owner. Ask only when two invoices are
  ambiguous or the recipient is unknown and the owner is present.
- **Never chase a received-but-unbooked invoice.** Exclude, evidence, narrate.
- **Never chase a customer not in the books' AR.** No reminders from memory.
- **Never write to QuickBooks.** Narrate the payment application.
- **Never mention another customer, threaten collections, or quote the tone
  label to the customer.**

## Scheduled runs

If a schedule ever runs this skill, follow
[`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md): `sessionType:
"scheduled"` plus a stable `taskId`, drafts only for invoices more than 7
days late, an output file with dedupe, no questions, no sends.

## Reference

- [`reference/tone-matching.md`](reference/tone-matching.md) — aging bucket → tone, subject lines, body rules
- [`reference/gotchas.md`](reference/gotchas.md) — known failure modes
- [`reference/examples/gentle-reminder.md`](reference/examples/gentle-reminder.md), [`reference/examples/firm-reminder.md`](reference/examples/firm-reminder.md) — example drafts (illustrative only)
- [`../cash-bridge/SKILL.md`](../cash-bridge/SKILL.md) — when the owner asks why cash lags profit
