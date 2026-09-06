# APPROVAL.md — how money moves in this plugin (propose → `/confirm` → passkey)

This is the one place the approval path is written out. Every skill that
stages a payment or transfer links here **and** repeats the three
load-bearing sentences inline, because skills are loaded one at a time:

> 1. `make_ach_payment`, `make_wire_payment` and `make_batch_payment` **never
>    move money**: they stage lines on the owner's open proposal and return a
>    confirmation URL of the form `https://<bank host>/confirm/<id>/<nonce>`.
> 2. **Print that URL verbatim as the approval step.** The owner opens it and
>    approves with a passkey (or TOTP); only then does money move.
> 3. **Never claim a staged payment has moved.** Say "staged" / "awaiting your
>    approval", never "paid" or "sent". Internal transfers between the owner's
>    own accounts are different: `transfer_funds` moves them directly (see
>    "Internal transfers" below), and a transfer that belongs with vendor
>    payments rides in the batch as a `{rail: "transfer", fromAccountNumber,
>    toAccountNumber, amount, description}` line.

## What the server does

The bank connector runs with propose-only sends on (`PROPOSE_ONLY_SENDS=1`,
the default). In that mode the money tools resolve and validate every item
server-side (saved payee → bank details, balance, duplicate check), append it
to the caller's **sticky proposal** (one open proposal per owner; lines
accumulate until it is approved, cancelled or expires) and return:

```json
{
  "proposal_id": "…",
  "status": "open",
  "confirmation_url": "https://<bank host>/confirm/<id>/<nonce>",
  "confirmation_title": "Approve payment batch: $6,000.00 across 3 payments",
  "expires_at": "<ISO timestamp>",
  "line_count": 3,
  "total_amount": 6000,
  "by_rail": { "ach": { "lines": 2, "amount": 4000 }, "transfer": { "lines": 1, "amount": 2000 } },
  "lines": [ { "index": 0, "rail": "ach", "amount": 1000, "summary": "…" }, … ]
}
```

There is no execute tool over MCP. Approval happens **out of band** on the
bank's page — the owner signs in to the bank and confirms with WebAuthn or
TOTP. That page is the bank's surface: one approval, on the bank, for
everything the agent proposed.

## The skill-side procedure

1. **Build the full set first.** Collect every line (bills, transfers) before
   calling any money tool. One batch, one URL.
2. **Stage in the same turn you present the set — do not ask "stage these?".**
   A staged proposal is inert; the owner reviews it on the bank's confirm page
   and the passkey there is the one approval. In a conversation the owner
   sees the table first (from the dry run), says yes, and then gets the bank's
   card and link — the card is a tool result, so anything written after the
   real call lands below it; keep that to a line or two. Ask nothing else
   before staging unless the skill cannot decide alone: a possible duplicate,
   or a payee with no saved rail. If the owner trims the set afterwards, stage a fresh
   batch; the old one expires unused. Unattended runs stage what the skill
   defines and surface the URL (see [`AUTONOMY.md`](AUTONOMY.md)).
3. **The dry run is the interactive gate; agents skip it.** In a
   conversation, `make_batch_payment {dryRun: true}` validates every line and
   returns `status: "validated_not_proposed"` — no proposal, no card, no URL —
   so the skill can show the table and ask "Stage these?" *before* the bank's
   card renders; the owner's yes then triggers the one real call, and the reply
   after it is a line or two under the card. Unattended runs stage directly.
   Either way a rejected batch comes back as `{ error, invalid_items[] }`
   naming the line and the reason; fix that line and re-submit once.
4. **Stage with ONE `make_batch_payment`.** Pay saved payees **by name**
   (`recipientId` = the payee's name; `list_saved_payees` tells you the rail).
   Transfers use the `transfer` rail with **exact, unmasked** account numbers
   from `list_accounts` and a short `description` of what the move is for
   (the bank records it; it defaults to `Transfer to ····<last 4>`). Never
   type an ABA or account number from memory.
5. **Print the approval step.** Render `confirmation_title` as the link text
   over `confirmation_url`, and the URL itself in plain text as well so a
   copy-paste survives. Say plainly: *"Nothing has moved. Open the link and
   approve with your passkey; the bank executes the batch after that."*
6. **Never narrate execution.** No "paid ✓", no "the transfer is done". If
   the owner comes back with "I approved it", verify at the bank
   (`query_transactions`, `direction: "debit"`, today, the amount) and report
   what actually posted.
7. **Errors come back as `{ error }`** (expired proposal, sealed proposal,
   line cap, no store). Report them in one line and re-stage on a fresh call
   if the proposal expired. Never invent a URL.
8. **Duplicates.** The server flags lines that look like a recent payment
   (same payee + amount). Surface the flag; do not silently drop or re-add.

## Words to use

| Say | Not |
|---|---|
| staged, proposed, awaiting your approval (a payment) | paid, sent, executed (before the owner approves) |
| "approve on the bank's page" | "confirm here and I'll pay" |
| "after you approve, I can verify the debit" | "the debit has posted" |
| "moved $X to savings; Operating is now $Y" (after `transfer_funds` and a balance read) | "moved" before the call and the read confirmed it |

## Internal transfers

`transfer_funds` moves money between the owner's own accounts and executes
directly: no proposal, no `/confirm` page. That is deliberate — an internal
transfer is reversible (move it back) and low-risk (no counterparty), so it
needs no approval. Use it when the owner asks for a move or says yes to one a
skill proposes (the payroll top-up in [`../plan-payroll`](../plan-payroll/SKILL.md),
the reserve catch-up in [`../tax-reserve-check`](../tax-reserve-check/SKILL.md)),
then confirm with `get_account_balance` and report the new figure. Give it a
`description` — what the move is for; the bank records it on both accounts.

Put a transfer in `make_batch_payment` as a `{rail: "transfer", …}` line
only when it belongs with vendor payments — a savings top-up that funds this
week's bills — so the approval page shows the whole plan and one passkey
covers it. The scheduled agents ([`../tax-sweep-agent`](../tax-sweep-agent/SKILL.md),
[`../sweep-to-savings`](../sweep-to-savings/SKILL.md), [`../daily-cash-brief`](../daily-cash-brief/SKILL.md))
stage their transfer this way by default so the morning notification carries
a review link; that is a product choice, not a safety rule, and the owner may
switch a schedule to direct `transfer_funds`.

## Session fields

Every Paywhere tool accepts `sessionType` (`interactive | scheduled |
background | agentic`) and `taskId`. The bank uses them to route approvals
and to tell a person's conversation apart from a scheduled job. Interactive
runs use `sessionType: "interactive"` (or omit it); unattended runs stamp
`sessionType: "scheduled"` and a stable `taskId` (see AUTONOMY.md).
