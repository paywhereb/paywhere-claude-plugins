---
name: invoice-chase
version: 0.2.0
description: >
  Drafts overdue-invoice reminder emails from QuickBooks AR, cross-referenced
  against Paywhere bank credits (so a customer who already wired you doesn't
  get chased), matched to each customer's payment history and tone (gentle
  for good customers, firm for repeat late payers). All sends queue as mail
  drafts for the owner to approve. Use when the user asks "who owes me
  money," mentions overdue invoices, or wants to follow up on unpaid
  invoices.
---

# Invoice Chase

## Quick start

Pull the AR aging report, score each customer by payment history, draft a tone-matched reminder for each overdue invoice, and present them to the owner. Nothing sends until the owner says so.

```
User: "who owes me money"
→ Pull AR aging from QuickBooks
→ Cross-reference Paywhere credits (last 14 days, all accounts)
→ Score each customer: good-payer / occasionally-late / repeat-late
→ Draft tone-matched reminders as mail drafts
→ Show summary table + drafts. Wait for "send these."
```

## Setup (first run only)

Ask the owner one question before running for the first time:

1. **Mail connector**: "Do you use Gmail or Apple Mail for drafts?" — store the answer; use it for all draft queuing.

Do not ask again on subsequent runs.

## Workflow

1. **Pull overdue receivables.** Query QuickBooks AR aging for all invoices more than 1 day past due.

2. **Cross-reference Paywhere credits.** For each Paywhere account returned by `list_accounts`, call `get_account_transactions` for the last 14 days. Set the `intent` field to something like "Chasing overdue invoices — checking which customers already paid." Filter to credits (positive `amount`).

   For each overdue invoice, look for a Paywhere credit whose `amount` matches the invoice within $0.50. If found:
   - Flag the customer as "possibly paid — verify" and exclude from the draft queue.
   - Note the Paywhere transaction id and `postDate` so the owner can reconcile in QB.

   The counterparty in `description` is free-text (see `paywhere-bank-lines.md` in `month-end-prep`'s reference for extraction heuristics), so prefer matching by amount first, then confirm by counterparty. When two open invoices share the same amount, surface both to the owner rather than guessing.

3. **Score each customer.** Read [reference/tone-matching.md](reference/tone-matching.md) for scoring logic. Result: `good-payer`, `occasionally-late`, or `repeat-late`.

4. **Draft reminder emails.** One email per customer — consolidate multiple overdue invoices into one email. Match tone to score. See [reference/examples/gentle-reminder.md](reference/examples/gentle-reminder.md) and [reference/examples/firm-reminder.md](reference/examples/firm-reminder.md).

5. **Present drafts to owner.** Show a summary table first (example layout — rows come from live AR data):

   | Customer | Amount Due | Days Late | Tone | Send via |
   |---|---|---|---|---|
   | _customer_ | $1,200 | 18 days | Gentle | Gmail draft |
   | _customer_ | $450 | 47 days | Firm | Gmail draft |

   Then show each draft email in full. Wait for owner to say "send these" or approve individually.

6. **Queue drafts — only after approval.** Queue each approved reminder as a draft in the owner's configured mail app. Never send directly; the owner sends from their mail client.

7. **Report what happened.** List what was queued as draft and what was flagged (possibly paid, excluded with the matching Paywhere transaction id).

## Approval gates

- **Never send or queue a draft without explicit owner approval.** Present all drafts first; wait for the go-ahead.
- **Never include a customer whose invoice amount appears as a Paywhere credit in the last 14 days.** Flag as "possibly paid — verify" instead.
- **Never send to a customer not in the QuickBooks AR report.** No reminders from memory alone.
- **One approval covers one batch.** Adding a customer or changing a draft after approval starts a new round.

## Reference

- [reference/tone-matching.md](reference/tone-matching.md) — scoring logic, tone guidelines, subject line formulas
- [reference/gotchas.md](reference/gotchas.md) — known failure modes
- [reference/examples/gentle-reminder.md](reference/examples/gentle-reminder.md) — good-payer email example
- [reference/examples/firm-reminder.md](reference/examples/firm-reminder.md) — repeat-late-payer email example
