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
3. `get_account_transactions` for each account, scoped to the target month
   (`fromDate`/`toDate`), paging through with `pageNumber`/`pageSize` until
   you have the full month. (For filtered or aggregated pulls, prefer
   `query_transactions`.)

## Transaction shape

Each row in `get_account_transactions` carries:

| Field | Notes |
|---|---|
| `id` | Stable identifier for the line. Use it as the reconciliation key when writing back to QB memos, and to look up enriched detail via `get_transaction_detail`. |
| `postDate` | Date-time the line posted (e.g. `2026-06-02 14:05:16-05:00`). Compare on the date part for matching. |
| `amount` | Signed decimal. Positive = credit (money in), negative = debit (money out). |
| `description` | Human-readable line description (e.g. `Amazon Web Services Inc`, `Thames Fintech Ltd - consulting hours`). |
| `statementDescription` | The raw bank statement descriptor (e.g. `ACH DEBIT AMAZON WEB SERVICES INC`, `WIRE IN THAMES FINTECH LTD`, `ACH CR ALDERBROOK VENTURES`). Cryptic processor descriptors land here — match and fingerprint on this field. |
| `status` | Settlement status of the line. |
| `type` | Rail/category of the line: `ACH`, `DomesticWire`, `Transfer`, `Cash`. (`query_transactions` matches `types` case-insensitively, but use these exact values.) |

There is **no fee field**. Fees post as their own separate lines (e.g. a
`WIRE TRANSFER FEE` debit), so don't subtract a fee from the parent
transaction's amount.

## Counterparty extraction

Prefer the structured source first:

- **`get_transaction_detail`** (by `accountNumber` + `id`, or `accountNumber`
  + `postDate` + `amount`) returns whatever enriched `detail` is on file for a
  line. It is best-effort and often **sparse** — sometimes just a reference or
  invoice number — and frequently `null`. When it hands you a reference you
  don't recognize, follow the thread (e.g. search Gmail for that invoice). When
  `detail` is `null`, fall back to parsing the text fields below.

When you have to parse text, the counterparty lives in `description` /
`statementDescription`:

- **ACH debits** — `statementDescription` is `ACH DEBIT <PAYEE>` (e.g.
  `ACH DEBIT AMAZON WEB SERVICES INC`); `description` usually carries the
  cleaner name. Some lines are deliberately cryptic processor passthroughs
  (e.g. `ACH DEBIT NPA*ENRICH 8002231`) that don't name the vendor — those
  are exactly the rows to resolve with `get_transaction_detail`.
- **ACH credits** — `statementDescription` is `ACH CR <PAYER>` (e.g.
  `ACH CR ALDERBROOK VENTURES`).
- **Wires** — `statementDescription` is `WIRE IN <SENDER>` /
  `WIRE OUT <PAYEE>`; `description` carries the human label.
- **Stablecoin payouts** — `statementDescription` is
  `STABLECOIN PAYOUT <NAME>`.
- **Transfers / fees / interest** — descriptive labels like
  `INTEREST PAYMENT`, `WIRE TRANSFER FEE`, or an internal transfer label.

When neither a structured detail nor a recognizable descriptor is available,
fall back to the full `description` string. Never silently drop the row — the
owner needs to be able to identify it.

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
