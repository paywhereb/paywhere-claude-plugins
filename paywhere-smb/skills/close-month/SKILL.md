---
name: close-month
version: 1.0.0
description: >
  Closes the month: reconciles every bank account against the books, matches
  merchant settlements GROSS-TO-NET (bank net vs QuickBooks deposit gross
  minus the fee line), finds deposits whose fee line the bookkeeper never
  posted, finds debit-card purchases not recorded in the books, flags gaps
  and duplicates, writes the P&L narrative and exports the close packet to
  the working folder. Narrates every bookkeeping fix (demo books are
  read-only). Accepts optional month argument. Use when the owner says
  "close the books," "close the month," "month-end," "reconcile," or "what's
  missing from the books."
allowed-tools: Read, WebFetch, Bash
---

Run the month-end close workflow — the command wrapper for the
[`../month-end-prep`](../month-end-prep/SKILL.md) skill. Reconcile, flag
gaps, narrate the P&L, export the close packet. Nothing here writes to
QuickBooks or moves money.

Parse arguments:
- `--month` (default: previous calendar month, from the actual current date) — `YYYY-MM`

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Reconcile"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

## Step 1 — Reconcile (month-end-prep)

Trigger the `month-end-prep` workflow for the target month:

1. Pull the QuickBooks register for the month (invoices, payments, deposits,
   bills, bill payments, purchases, transfers, journal entries).
2. Pull every Paywhere account (`list_accounts`) and `query_transactions`
   per account for the month (`dateFrom`/`dateTo`; slice if `truncated`).
3. Match by amount + date (±2 days) + sign. Surface:
   - **Missing in QuickBooks** — a bank line with no book entry (interest,
     bank fee, a check deposited but not applied, an unrecorded card purchase).
   - **Missing in the bank** — a book entry with no bank line (uncleared
     check, deposit in transit).
   - **Variance lines** — matched but amounts differ.

## Step 2 — The three settlement checks (by name)

1. **Gross-to-net settlement matching** — every merchant settlement in the
   bank (`INTUIT PYMT SOLN DEPOSIT`, net of fees) against the QBO Deposit
   that groups the same card/check payments: bank net must equal deposit
   gross plus the negative "Merchant Fees" line.
2. **Unposted fee lines** — a deposit whose gross equals the bank credit plus
   a fee-sized gap and which has **no** fee line: list each with the
   difference; the fix (narrated, not performed) is adding the negative fee
   line to that deposit.
3. **Unrecorded card purchases** — `POS DEBIT` / `RECURRING DEBIT` rows with no
   QBO Purchase (amount ± $0.50, ± 3 days): list each with descriptor and
   amount; the fix (narrated) is recording the purchase to the right expense
   account.

Also: refunds (`RETURN` / negative settlement rows) vs QBO RefundReceipts,
and the sales-tax transfers/remittances vs QBO Transfers/Purchases against
the liability accounts.

## Step 3 — Flag suspicious entries

Uncategorized transactions; duplicates (same amount, same counterparty,
within 3 days — a monthly subscription is not a duplicate); expenses above
$75 with no receipt. Recommend an action per item. Wait for the owner to
triage before the narrative. Do not auto-categorize or delete anything.

## Step 4 — P&L narrative

```
{Month YYYY} closed at ${revenue} revenue ({+/-}{X}% vs prior month); cash collected ${collected}.
Top driver: {class/customer}. Biggest swing: {line} {direction} ${amount} because {reason}.
Margin: {X}% ({+/-}Y pts). {Cost commentary}.
Three notable items: 1. … 2. … 3. …
Bank vs books: {n} settlements short ${x} (fee lines missing), {m} card purchases unrecorded ${y}, {k} other gaps.
```

## Step 5 — Export the close packet

Write to `close/` in the working folder:

1. `close/close-packet-{YYYY-MM}.xlsx` — tabs `Reconciliation` (match table,
   gap rows highlighted), `Settlements` (gross / fee / net / bank / difference
   per settlement), `Flagged`, `P&L` (with prior-month delta), `Trial Balance`.
2. `close/close-packet-{YYYY-MM}.pdf` — one-page summary: narrative, top-line
   numbers, gap counts.

Confirm the paths.

## Connector failures

QuickBooks unreachable → stop. Paywhere unreachable → ask for a per-account
CSV export and note "reconciling against CSV". Both → stop.

## Approval gates

- **Never fix flagged items in QuickBooks** — the demo books are read-only and
  the write-back is the bookkeeper's; narrate the exact correction.
- **Never delete duplicates**; show both records.
- **Always pause after Step 3** before the narrative and export.

## Output

One-paragraph recap: revenue, collected, margin, settlement gaps, unrecorded
purchases, remaining gaps, file paths.
