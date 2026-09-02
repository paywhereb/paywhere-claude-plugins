---
name: month-end-prep
version: 1.0.0
description: >
  Month-end close for an owner-operated business: reconciles the QuickBooks
  register against the bank lines of every account, matches merchant
  settlements gross-to-net (the bank deposit is net of fees; the books'
  Deposit is gross with a fee line), catches deposits whose merchant fee was
  never posted, finds debit-card purchases that never made it into the
  books, surfaces refunds and failed autopays, flags uncategorized and
  duplicate entries, then writes a plain-English P&L narrative and a close
  packet (xlsx + one-page PDF) into the working folder. Reads only; every
  bookkeeping fix is narrated, never performed. Use when the owner says
  "close the month," "month-end," "reconcile," "what's missing in the
  books," "P&L," or asks why revenue or margin changed this month.
---

# Month End Prep

Classical bank reconciliation plus the three things a service business with
a merchant account gets wrong every month: settlements land **net**, some
deposits are booked **gross** without the fee line, and a slice of card
purchases never reach the books. The bank is the evidence; the books are
what gets corrected. The demo books are read-only, so every fix is narrated
as the two-line correction a bookkeeper would make.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Agree on the target
month"), then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

## Step 1 — Agree on the target month

Default: the prior calendar month, resolved from the actual date. Confirm in
one line before pulling.

## Step 2 — Books: P&L and register

`get_profit_and_loss` for the month; the register from `search_invoices`,
`search_payments`, `search_deposits`, `search_bills`, `search_bill_payments`,
`search_purchases`, `search_transfers`, `search_journal_entries`,
`search_credit_memos`. Flag **uncategorized** lines (see
`reference/quickbooks-reconcile.md`) and list them; do not advance with open
ones unless the owner says "skip for now".

## Step 3 — Bank: every account, the whole month

`list_accounts` → for each account `query_transactions {dateFrom, dateTo,
status: ["posted"]}` (slice by half-month if `truncated`). Pending rows at
month end go in an `IN_TRANSIT` bucket. Descriptor conventions are in
`reference/paywhere-bank-lines.md`.

## Step 4 — Reconcile (the matching pass)

Walk bank lines against the register: amount within $0.50, date ±2 days,
same sign → **RECONCILED**; else `DATE_MISMATCH`, `MISSING_IN_QB`,
`MISSING_IN_BANK`. Then run the three checks below **before** reporting the
gaps — they explain most of them.

### 4a. Merchant settlements, gross to net

A merchant deposit at the bank (`INTUIT PYMT SOLN DEPOSIT`-style, one per
settlement day) is **net** of processing fees. The books' Deposit
(`search_deposits`) groups that day's card/pay-by-link payments from
Undeposited Funds at **gross** and carries a **negative fee line** to the
merchant-fee expense account. Match on date ±2 (T+1 card, T+2 ACH) and
`bank amount == deposit gross + fee line` (fee line is negative). A match
is one reconciled row even though the two amounts differ; show gross, fee,
net.

### 4b. Unposted fees

A books' Deposit **without** a fee line whose gross exceeds the bank deposit
by a plausible fee — 1–4% of gross plus a few cents per payment — is a
**fee not posted**. List each: deposit ref, books gross, bank net,
difference. The correction (narrated): add the negative merchant-fee line
for the difference so the Deposit equals the bank; the P&L picks up the fee.
Sum the differences — this is the month's unbooked merchant expense.

### 4c. Unrecorded card purchases

Bank `POS DEBIT` / `RECURRING DEBIT` rows with no `search_purchases` match
(amount ±$0.50, date ±2) are **not in books**. List them with the descriptor
stem and the expense account a prior purchase for the same stem used, if
any. Recurring ones may also be a `../subscription-audit` finding.

### 4d. Refunds and failed autopays

- A bank **debit** with a refund/card-return descriptor, or a books
  `RefundReceipt` / `CreditMemo`, is a refund — match it to the credit memo,
  not to a deposit (see `reference/gotchas.md`).
- A recurring customer payment that is present in prior months and absent
  this month (no bank credit, no books payment, invoice still open) is a
  **failed autopay** candidate: name the customer and the open invoice; the
  follow-up is `../invoice-chase`.

## Step 5 — Duplicates

Same amount (±$0.01), same counterparty, within 5 days, distinct `TxnID` →
suspicious duplicate. Present pairs; the owner decides.

## Step 6 — Receipts

Books expenses above $75 with no attachment: list them and ask the owner
which have receipts. Do not skip silently; do not go looking on the owner's
machine.

## Step 7 — Owner sign-off gate

```
Uncategorized:            X of X resolved
Settlement matches:       X matched gross→net · X fees not posted (${total})
Unrecorded card purchases: X (${total})
Refunds / failed autopay: X
Missing in books / bank:  X / X
Suspicious duplicates:    X flagged, X cleared
Missing receipts:         X outstanding
```

Ask: "Ready to write the P&L summary and export the close packet?" **Do not
proceed without explicit confirmation.** Every open flag is acknowledged or
explicitly deferred (deferred items go to the Action Items sheet).

## Step 8 — P&L narrative

150–250 words, plain English: headline, revenue drivers (customers,
categories; note concentration), gross margin, expense lines that moved >10%,
bottom line, watch list. Include one sentence on cash vs profit if the bank
balance moved differently from net income (hand off to `../cash-bridge` for
the full bridge). See `reference/examples/pl-narrative.md`.

## Step 9 — Export the close packet

Write into the working folder:

- `close/close-packet-YYYY-MM.xlsx` — sheets `P&L`, `Reconciliation`
  (with the gross/fee/net columns for settlements), `Settlement Fees`,
  `Unrecorded Purchases`, `Action Items` — layout in
  `reference/close-packet-format.md`.
- `close/close-packet-YYYY-MM-summary.pdf` — one page.

Confirm the paths. Nothing is emailed; if the owner wants it sent to the
accountant, create a Gmail **draft** with the files attached (never send).

## Narrate, never write

The demo QuickBooks connector is read-only (the shared books reseed daily).
For each correction say what would be booked outside a demo — "add a
−$71.56 Merchant Fees line to Deposit 1043", "record a $38.20 Purchase to
Vehicle:Fuel for the 14th" — and move on. Never claim a fix was made.

## Approval gates

- Never reconcile a month the owner says has been filed.
- Never void, modify or create a QuickBooks transaction.
- Always pause at Step 7.
- No money moves from here; anything to pay is `../pay-bills`.

## Graceful degradation

| Missing | Fallback |
|---|---|
| quickbooks | Ask for a register + P&L CSV export; run the bank-side checks (4c, 4d) regardless. |
| Paywhere | Ask for a per-account CSV export of the month; settlement checks (4a/4b) still run against it. |

## Reference files

- `reference/paywhere-bank-lines.md` — descriptor conventions per rail, settlement matching, counterparty extraction
- `reference/quickbooks-reconcile.md` — books fields, uncategorized rules, split transactions
- `reference/close-packet-format.md` — xlsx sheets and PDF layout
- `reference/gotchas.md` — refunds vs deposits, splits vs duplicates, fee lines, the sign-off gate
- `reference/examples/pl-narrative.md` — worked narrative
