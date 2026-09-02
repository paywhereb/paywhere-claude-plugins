# APPROVAL.md — how money moves in this plugin (propose → `/confirm` → passkey)

This is the one place the approval path is written out. Every skill that
stages a payment or transfer links here **and** repeats the three
load-bearing sentences inline, because skills are loaded one at a time:

> 1. `make_ach_payment`, `make_wire_payment` and `make_batch_payment` **never
>    move money**: they stage lines on the owner's open proposal and return a
>    confirmation URL of the form `https://<bank host>/confirm/<id>/<nonce>`.
> 2. **Print that URL verbatim as the approval step.** The owner opens it and
>    approves with a passkey (or TOTP); only then does money move.
> 3. **Never claim money has moved.** Say "staged" / "awaiting your approval",
>    never "paid", "sent" or "transferred". Internal transfers are staged the
>    same way — a `{rail: "transfer", fromAccountNumber, toAccountNumber,
>    amount}` item in `make_batch_payment` — **never `transfer_funds`**.

## What the server does

The demo deployment runs with propose-only sends on (`PROPOSE_ONLY_SENDS=1`,
the default). In that mode the money tools resolve and validate every item
server-side (saved payee → bank details, balance, duplicate check), append it
to the caller's **sticky proposal** (one open proposal per owner; lines
accumulate until it is approved, cancelled or expires) and return:

```json
{
  "proposal_id": "…",
  "status": "open",
  "confirmation_url": "https://<bank host>/confirm/<id>/<nonce>",
  "confirmation_title": "Approve payment batch: $10,900.00 across 3 payments",
  "expires_at": "2026-09-04T21:00:00.000Z",
  "line_count": 3,
  "total_amount": 10900,
  "by_rail": { "ach": { "lines": 2, "amount": 9000 }, "wire": { "lines": 1, "amount": 1900 } },
  "lines": [ { "index": 0, "rail": "ach", "amount": 6850, "summary": "…" }, … ]
}
```

There is no execute tool over MCP. Approval happens **out of band** on the
bank's page — the owner signs in to the bank and confirms with WebAuthn or
TOTP. That page is the bank's surface, which is the point of the demo: one
approval, on the bank, for everything the agent proposed.

## The skill-side procedure

1. **Build the full set first.** Collect every line (bills, transfers) before
   calling any money tool. One batch, one URL.
2. **Interactive runs: an in-chat check is fine, not a gate on money.** Show
   the table (payee, amount, rail, from-account, why) and ask "stage these?"
   Staging is reversible (the owner can decline on the confirm page or
   cancel), so do not make the owner say "yes, pay these" twice — the
   passkey is the real approval. **Unattended runs skip the in-chat check**:
   there is nobody to answer; stage what the skill defines and surface the URL
   (see [`AUTONOMY.md`](AUTONOMY.md)).
3. **Optionally `dryRun: true` first** when a line might fail validation
   (unknown payee, wrong rail). A dry run validates without staging.
4. **Stage with ONE `make_batch_payment`.** Pay saved payees **by name**
   (`recipientId` = the payee's name; `list_saved_payees` tells you the rail).
   Transfers use the `transfer` rail with **exact, unmasked** account numbers
   from `list_accounts`. Never type an ABA or account number from memory.
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
| staged, proposed, awaiting your approval | paid, sent, executed, transferred |
| "approve on the bank's page" | "confirm here and I'll pay" |
| "after you approve, I can verify the debit" | "the debit has posted" |

## Why transfers go through the batch tool

`transfer_funds` executes immediately with no out-of-band approval. In a demo
that shows the bank's approval surface, an immediate transfer is both unsafe
unattended and invisible to the FI's Money Movement screen. The batch tool's
`transfer` rail stages the same move as a proposal line, so the reserve
top-up in [`../tax-reserve-check`](../tax-reserve-check/SKILL.md) and the
Friday sweep in [`../tax-sweep-agent`](../tax-sweep-agent/SKILL.md) wait for
the same passkey as the vendor payments.

## Capture parameters

Every Paywhere tool accepts `intent` (one sentence: why the owner is asking),
`sentiment`, `sessionType` (`interactive | scheduled | background | agentic`)
and `taskId`. Fill `intent` on every money call — it is what the FI's Intents
screen aggregates. Unattended runs stamp `sessionType: "scheduled"` and a
stable `taskId` (see AUTONOMY.md).
