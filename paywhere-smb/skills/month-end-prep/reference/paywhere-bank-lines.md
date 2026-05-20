# Paywhere Bank Lines — Reconciliation Reference

This is classical bank reconciliation: every line that hit the Paywhere bank
account should map to a QuickBooks book entry, and vice versa. The Paywhere
MCP exposes one tool per data shape — there are no settlement batches or
processor payouts to unwind.

## Contents

- [Pulling Paywhere transactions](#pulling-paywhere-transactions)
- [Transaction shape](#transaction-shape)
- [Counterparty extraction](#counterparty-extraction)
- [Pending vs settled](#pending-vs-settled)
- [Reconciliation logic](#reconciliation-logic)

---

## Pulling Paywhere transactions

For each account on the user's profile:

1. `list_accounts` — returns one entry per Paywhere account (operating,
   reserve, payroll, etc.). Each entry has an account id you'll use for the
   downstream calls.
2. `get_account_balance` for each account — current available + pending
   balance. Use this to anchor your reconciliation: end-of-month book
   balance in QuickBooks should equal Paywhere available balance ± timing
   differences (outstanding checks, deposits in transit).
3. `get_account_transactions` for each account, scoped to the target month.
   **Always populate the `intent` field** with a first-person sentence
   ("I'm reconciling March for month-end close, matching bank lines to the
   QB register"). This signals to the MCP that you're in a reconciliation
   flow and influences which product recommendations are surfaced
   downstream.

## Transaction shape

Each row in `get_account_transactions` carries roughly:

| Field | Notes |
|---|---|
| `postDate` | Calendar date the line posted to the account (ISO date). Use this for date matching. |
| `amount` | Signed decimal. Positive = credit (money in), negative = debit (money out). |
| `description` | Free-text description from the upstream rail (ACH/wire memo, stablecoin tx note, internal transfer label, etc.). |
| `type` | Enum: `ach`, `wire`, `stablecoin`, `transfer`, `fee`, `interest`, etc. Indicates which clearing window applies. |
| `runningBalance` | Account balance after this line posted, if upstream provided it. Useful for sanity-checking the order of operations. |
| `id` | Stable identifier for the line. Use it as the reconciliation key when writing back to QB memos. |

There is **no fee field**. Paywhere posts fees as their own debit lines
with `type: "fee"` and a distinct `description`. Do not subtract a fee from
the parent transaction's amount.

## Counterparty extraction

Today the upstream Paywhere API returns counterparty inside the free-text
`description`. Until a structured `counterpartyName` field lands (tracked
upstream), extract it heuristically:

- **ACH credits/debits** — counterparty is usually the substring after
  `ACH ` and before the next ` / ` separator (e.g. `ACH Acme Corp /
  INV-112` → counterparty `Acme Corp`).
- **Wire credits/debits** — counterparty is everything between `WIRE FROM`
  / `WIRE TO` and the first dollar amount or memo separator.
- **Stablecoin receipts** — `description` includes the sender wallet
  address and (if the user named the recipient) the recipient nickname.
  Extract the recipient nickname when present; fall back to a truncated
  wallet address.
- **Internal transfers** — `description` follows `Transfer to <account>` /
  `Transfer from <account>`. Use the named account verbatim.

When the regex misses, fall back to the full `description` string. Never
silently drop the row — the owner needs to be able to identify it.

## Pending vs settled

Two adjacent surfaces tell you whether a line is final:

- `get_account_transactions` returns settled lines (already on the
  balance). Treat these as canonical.
- `get_ach_payment_status(id)` and `get_wire_payment_status(id)` let you
  poll outstanding payments by id. Include their expected-settle dates in
  the unreconciled bucket so the owner can plan around the month boundary.

Stablecoin receipts settle within minutes-to-hours of being broadcast to
the network — usually they're already settled by the time you look. The
list of supported chains is available via `list_supported_chains`.

---

## Reconciliation logic

Use this logic to match each Paywhere line against the QuickBooks
transaction register:

```
for each paywhere line in target month (per account):
    find QB entry where:
        abs(QB.amount - paywhere.amount) < $0.50
        AND abs(QB.TxnDate - paywhere.postDate) <= 2 days
        AND sign(QB.amount) == sign(paywhere.amount)
        AND (counterparty heuristic match OR memo contains paywhere.id)

    if match found:
        mark as RECONCILED
    elif abs(QB.amount - paywhere.amount) < $0.50 (date mismatch only):
        flag as DATE_MISMATCH (usually a timing difference — low priority)
    elif paywhere line not matched at all:
        flag as MISSING_IN_QB (bank-side activity not yet posted to books;
                               common for interest credits and bank fees)
    elif QB entry not matched to any paywhere line:
        flag as MISSING_IN_PAYWHERE (likely an outstanding check or a
                                     deposit posted to QB ahead of the bank)
```

**Multi-account businesses:** Run the logic per account, then aggregate
flags. A QB deposit that doesn't match the operating account may
legitimately have landed in the payroll or reserve account — don't flag
it until you've checked all accounts returned by `list_accounts`.

**Pending payments at month-end:** If a Paywhere wire or ACH is still in
`pending` status on the last day of the month, include it in the
reconciliation report with status `IN_TRANSIT` and the expected-settle
date. Don't reconcile against QB — that match happens next month after it
clears.
