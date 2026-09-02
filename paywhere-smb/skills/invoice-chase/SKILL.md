---
name: invoice-chase
version: 1.0.0
description: >
  Turns overdue receivables into action: ranks open invoices by cash impact ×
  lateness using each customer's derived payment profile (see ar-health),
  cross-checks the bank so a customer whose check or ACH already landed but is
  not yet applied in the books is EXCLUDED rather than chased, and creates
  tone-matched Gmail DRAFTS — never sends. The owner approves the set of drafts
  to create and sends from Gmail. Use when the owner says "who do I call
  first," "who owes me money and who do I call first," "chase overdue
  invoices," "follow up on unpaid invoices," "draft reminders," or "send
  reminders" (they become drafts).
---

# Invoice Chase

Books say who owes; the bank says who already paid. Rank what is genuinely
outstanding, draft a reminder per customer in the tone their history earns,
and leave the sending to the owner. **Drafts only**: Gmail `create_draft`;
never `send_message`, `reply` or `forward`. Nothing is written to QuickBooks
(the demo books are read-only; any fix is narrated).

## Quick start

```
User: "who owes me money and who do I call first?"
→ Open AR (get_aged_receivables + search_invoices) + 12-month lag history → profiles
→ Bank credits since the oldest open invoice → received-but-unbooked items EXCLUDED
→ Rank collectible invoices by cash impact × lateness
→ Draft one Gmail reminder per customer for the top set (tone by profile)
→ Show the table + full drafts → owner approves the SET → create_draft each
→ Report: drafts created (in Gmail), excluded items with bank evidence
```

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Pull overdue
receivables"), then `TaskUpdate` it to `in_progress` when you begin that
step and `completed` when it's done. This is what drives Cowork's visible
progress display — it does not happen unless you do it explicitly.

## Workflow

1. **Pull overdue receivables.** `get_aged_receivables` plus `search_invoices`
   for invoices with a positive open `Balance` past due at today (resolve
   today from the actual date). Roll sub-customer jobs up to the parent
   customer; net any `search_credit_memos` against the customer. Pull the
   customer's contact email from `search_customers`.

2. **Profile each customer.** Apply the derived-profile rules in
   [`../ar-health/reference/profiles.md`](../ar-health/reference/profiles.md)
   from 12 months of `search_invoices` + `search_payments` (lag = payment date
   − due date). Fewer than 3 paid invoices → "insufficient history" and the
   neutral tone.

3. **Cross-check the bank — the exclusion step.** `query_transactions
   {direction: "credit", dateFrom: <oldest open invoice date>, status:
   ["posted"]}` across all accounts. An open invoice whose amount matches a
   posted credit within $0.50 (descriptor `ACH CR <name>`, `MOBILE CHECK
   DEPOSIT <check#>`, `WIRE IN <sender>`) is **received, not booked**:
   - exclude it from the chase list and from collectible AR;
   - show the evidence line: bank date, amount, descriptor (and the check
     number when the descriptor carries one);
   - narrate the fix: outside a demo, the payment would be recorded against
     the invoice in QuickBooks; the demo books are read-only, so say it in
     one line instead of writing it.
   Two open invoices with the same amount → show both, ask, chase neither
   until the owner picks. Card payments settle net inside grouped merchant
   deposits, so match those through the books' Deposit, not by amount.
   A credit still pending is "in transit — do not chase".

4. **Rank.** `cash impact = open × lateness factor × profile factor`
   (factors in the profiles reference). The top two are "call first".
   Explain each rank in plain words: dollars, days late, pattern.
   _E.g. "a multi-site restaurant customer: $2,100, 38 days late, pays 30–60
   days late on one invoice in four — call before the check-paying church
   whose $520 is 9 days late and always arrives."_

5. **Draft one reminder per customer.** Consolidate a customer's overdue
   invoices into one email. Tone from
   [`reference/tone-matching.md`](reference/tone-matching.md): gentle for
   prompt customers, neutral for occasionally-late / insufficient history,
   firm for routinely late and cured-delinquent. Examples (clearly examples,
   not templates to copy numbers from):
   [`reference/examples/gentle-reminder.md`](reference/examples/gentle-reminder.md),
   [`reference/examples/firm-reminder.md`](reference/examples/firm-reminder.md).

6. **Present and approve the set.** Summary table first (rows from live data):

   | # | Customer | Open | Days late | Profile | Tone | Action |
   |---|---|---|---|---|---|---|
   | 1 | _customer_ | $7,200 | 18 | routinely late | firm | Gmail draft |
   | — | _customer_ | $520 | 9 | prompt | — | **excluded — check #… deposited {date}** |

   Then every draft in full. Ask which drafts to create; the owner may trim
   or reword. Changing the set restarts this step.

7. **Create the drafts.** Gmail `create_draft` for each approved reminder
   (to the customer's AR contact, subject per the tone rules). Never send.
   If the owner says "remind me to call X Thursday", `create_event` on the
   calendar with **no attendees** — only when asked.

8. **Report.** Drafts created (customer, amount, subject — "in your Gmail
   Drafts, ready to send"); excluded items with their bank evidence and the
   narrated books fix; the projected collectible if the top set pays.

## Approval gates

- **Never send.** `create_draft` is the only Gmail write; the owner sends.
- **Never create drafts before the owner approves the set.** One approval
  covers one set.
- **Never chase a received-but-unbooked invoice.** Exclude, evidence, narrate.
- **Never chase a customer not in the books' AR.** No reminders from memory.
- **Never write to QuickBooks.** Narrate the payment application.

## Unattended

`ar-chase-agent` (a Monday-morning scheduled version) is **not in this
build**. If a schedule ever runs this skill, it follows
[`../_shared/AUTONOMY.md`](../_shared/AUTONOMY.md): `sessionType:
"scheduled"` + `taskId`, drafts only for invoices > 7 days late, an output
file with dedupe, no questions, no sends.

## Reference

- [`../ar-health/SKILL.md`](../ar-health/SKILL.md) — the analysis (aging, DSO, profiles); this skill is the action.
- [`reference/tone-matching.md`](reference/tone-matching.md) — profile → tone, subject lines, body rules
- [`reference/gotchas.md`](reference/gotchas.md) — known failure modes
- [`reference/examples/gentle-reminder.md`](reference/examples/gentle-reminder.md), [`reference/examples/firm-reminder.md`](reference/examples/firm-reminder.md) — example drafts
