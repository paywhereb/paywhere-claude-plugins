# Example: Refund request — Paywhere credit found

**Scenario:** A customer emails saying their product arrived damaged and they want a full refund. The owner forwards the email and says "answer this customer."

---

## Customer email (forwarded)

> **Subject:** Damaged product — need refund
>
> Hi, I ordered a cutting board set last month and it arrived cracked. I'd like a full refund please. My invoice number was INV-3847.
>
> — Sarah M.

---

## Step 2 — Paywhere lookup result

Searched `get_account_transactions` (operating account, last 30 days, credits only) for $64.00:

- **Paywhere transaction id:** pw_txn_01HXY...
- **Amount:** $64.00 (credit)
- **postDate:** 2026-03-28
- **type:** `ach`
- **description:** `ACH Sarah Martinez / INV-3847`
- Counterparty matches HubSpot record by name → confirmed.

---

## Step 3 — HubSpot lookup result

Contact found: Sarah M. (sarah.m@email.com)
- Lifecycle stage: Customer
- Prior orders: 2
- Notes: "Returning customer — sent holiday promo Dec 2025."

---

## Step 4 — Draft reply (presented to owner for review)

> **Subject:** Re: Damaged product — need refund
>
> Hi Sarah,
>
> So sorry to hear your cutting board set arrived cracked — that's definitely not okay. I've pulled up your order and I'm sending a full refund of $64.00 back via ACH to the same account you paid from. You should see it within 1–3 business days.
>
> Thanks for letting me know, and I appreciate your patience. Really sorry about this.
>
> [Owner name]

---

## Step 5 — Owner approves draft (no edits)

---

## Step 6 — Refund approval prompt (refund is *staged*, not sent)

> *"Stage a Paywhere refund of $64.00 to Sarah Martinez — return the ACH credit from 2026-03-28? Reply Y to draft the outbound ACH for owner approval in the Paywhere flow."*

Owner replies: **Y**

→ Outbound ACH drafted in the Paywhere flow. The owner reviews counterparty + amount + account in Paywhere and approves the send there. This skill does **not** initiate the outbound payment directly.

---

## Step 7 — Send + HubSpot note

Reply sent via Gmail.

HubSpot note logged on Sarah M.'s contact:
> "Ticket Deflector — 2026-04-23: Customer reported damaged product. Refund of $64.00 staged in Paywhere (return of ACH pw_txn_01HXY...). Reply sent via email. Owner to approve outbound ACH in Paywhere."

---

## Step 8 — Report

> Reply sent to Sarah M. · Refund of $64.00 staged in Paywhere · HubSpot note logged.
