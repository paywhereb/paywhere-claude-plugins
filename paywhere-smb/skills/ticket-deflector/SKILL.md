---
name: ticket-deflector
description: >
  Reads a forwarded customer email or ticket, pulls payment status from
  Paywhere (the credit that matches the customer's invoice) and account
  history from HubSpot, drafts a tone-matched reply in the owner's writing
  voice, and can stage an owner-approved refund as a Paywhere ACH or wire
  back to the customer. Use when the user says "draft a response," "answer
  this customer," "where's my order," or "I want a refund."
compatibility: "Requires Paywhere, HubSpot, Mail. Optional: Intercom."
---

# Ticket Deflector

## Quick start

Forward or paste a customer email — Claude looks up the matching Paywhere credit, pulls the customer record from HubSpot, and drafts a reply in the owner's voice. If a refund is needed, it stages the details and waits for explicit approval before queuing anything.

```
User: "answer this customer" [forwards email]
→ Extract customer email + issue from thread
→ Search Paywhere credits for the matching invoice amount
→ Pull HubSpot contact history
→ Draft reply in owner's voice
→ Owner approves draft → send or stage
→ If refund needed: approval prompt → owner confirms → stage Paywhere ACH back to customer
```

## Workflow

1. **Read the customer message.** Accept a forwarded Gmail thread or pasted text. Extract: customer email address, name, order or invoice ID (if present), and the core issue — refund request, order status question, or general complaint. If multiple issues are present, address them in the order they appear.

2. **Look up payment status in Paywhere.** Pull `get_account_transactions` for the operating account (and any other relevant accounts) for the last 30 days. Set `intent` to "Resolving a customer ticket — looking up whether their payment cleared." Filter to credits (positive `amount`). Match by:
   - Invoice amount (within $0.50), if the customer or HubSpot record has it on file.
   - Counterparty extracted from `description` (heuristics in `month-end-prep/reference/paywhere-bank-lines.md`).
   - Both, preferred.

   If a match is found, capture: amount, `postDate`, Paywhere transaction `id`, and `type` (ACH / wire / stablecoin). If no match: flag in the draft — *"No Paywhere credit found matching this customer in the last 30 days; verify the invoice was actually paid before promising a refund."* Do not guess.

   If Intercom is connected, also check for open support tickets from this customer.

3. **Pull customer history from HubSpot.** Search contacts by email address. Pull: lifecycle stage, notes, open deals, and recent activity. If no contact exists, note it and offer to create one after the reply is sent — do not create during the response workflow.

4. **Draft the reply.** Write in the owner's writing voice. Adjust tone to fit the issue type:
   - Refund request → empathetic, clear, action-oriented
   - Order status question → factual, reassuring
   - General complaint → acknowledge, explain, offer resolution

   Flag any data gaps inline in the draft with a bracketed note (e.g., *[Note: No Paywhere credit matched this customer in the last 30 days — verify payment cleared before sending]*) so the owner sees the gap before sending. For a worked example, see [reference/examples/respond-refund-request.md](reference/examples/respond-refund-request.md). For common pitfalls, see [reference/gotchas.md](reference/gotchas.md).

5. **Approval gate — owner reviews the draft.** Present the full draft. Do not send or stage it until the owner approves. The owner may edit freely before approving.

6. **Approval gate — refund issuance.** If a refund is warranted, surface a dedicated confirmation prompt after the owner approves the draft:

   > *"Stage a Paywhere refund of $[amount] to [customer name] ([email]) — return the ACH credit from [postDate]? Reply Y to draft the outbound ACH for owner approval in the Paywhere flow."*

   Wait for explicit confirmation. If the owner's reply is anything other than a clear yes, stop and ask what they'd like to do instead. **Never** initiate the outbound Paywhere payment from inside this skill — stage it; the owner approves and sends from the Paywhere flow.

7. **Send or stage the reply.** After draft approval, ask the owner: send via Gmail now, or save as a draft? Execute their choice. Then log the interaction as a note on the HubSpot contact timeline.

8. **Report.** One short paragraph: reply sent or staged, refund staged or not, HubSpot note logged.

## Approval gates

- **Never initiate a Paywhere outbound payment from this skill** — refunds are *staged* for owner approval; the owner sends them from the Paywhere flow with their own confirmation.
- **Never send the reply without owner review.** Always present the full draft first.
- **Never create a HubSpot contact during the response flow.** Offer it afterward.
- **Never auto-select a matching Paywhere credit.** If multiple credits match the invoice amount, surface them all (with `postDate` and counterparty) and let the owner choose.
- **Never fabricate payment details.** If Paywhere has no matching credit, say so inline in the draft — do not invent a status.

## Reference

- [reference/gotchas.md](reference/gotchas.md) — Good / Bad patterns for tone, Paywhere credit lookup, and ambiguous refund scenarios
- [reference/examples/respond-refund-request.md](reference/examples/respond-refund-request.md) — worked example: refund request with Paywhere credit found
