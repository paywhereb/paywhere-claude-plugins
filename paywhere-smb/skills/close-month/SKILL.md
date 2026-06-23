---
name: close-month
description: Closes the month — reconciles QB vs payment processors, flags gaps, writes P&L narrative, exports close packet. Accepts optional month and save-to arguments.
allowed-tools: Read, WebFetch, Bash
---

Run the month-end close workflow. Reconcile, flag gaps, narrate the P&L, and export the close packet for the owner's records (and their accountant).

Parse arguments:
- `--month` (default: previous calendar month) — `YYYY-MM` format
- `--save-to` (default `files`) — `files` (Google Drive), `desktop` (local), or `both`

## Step 1 — Reconcile

Trigger the `month-end-prep` skill workflow:

1. Pull all QuickBooks transactions for the target month.
2. Pull every Paywhere account (`list_accounts`) and call `get_account_transactions` per account for the same month.
3. Match QB entries to Paywhere bank lines by amount + date (±2 days) + sign.
4. Surface three gap categories:
   - **Missing in QuickBooks** — Paywhere shows a bank line with no corresponding QB entry (interest credit, bank fee, deposit not yet posted)
   - **Missing in Paywhere** — QB shows a transaction with no bank line yet (outstanding check, deposit in transit)
   - **Variance lines** — matched but amount differs (fees posted as their own Paywhere line; reconciles separately)

## Step 2 — Flag suspicious entries

Surface in the same report:
- **Uncategorized transactions** — QB entries with no category
- **Suspicious duplicates** — same amount, same vendor, within 3 days
- **Missing receipts** — QB entries above $75 with no attachment

For each, recommend an action: categorize as X, delete duplicate, attach receipt from inbox.

Wait for owner to triage flagged items before generating the narrative. Do not auto-categorize or auto-delete.

## Step 3 — P&L narrative

After triage, generate a plain-English P&L narrative:

```
{Month YYYY} closed at ${revenue} revenue ({+/-}{X}% vs prior month).
Top driver: {category/customer}. Biggest swing: {category} {direction} ${amount}
because {reason inferred from transactions}.

Margin: {X}% ({+/-}Y pts vs prior). {Cost-side commentary}.

Three notable items:
1. ...
2. ...
3. ...
```

Numbers come from QB; the *why* comes from cross-referencing top transactions, vendor names, and prior-month deltas.

## Step 4 — Export the close packet

Generate two files:

1. **`close-packet-{YYYY-MM}.xlsx`** — multi-tab workbook:
   - `Reconciliation` — QB ↔ Paywhere bank-line match table with gap rows highlighted
   - `Flagged` — uncategorized / duplicates / missing receipts
   - `P&L` — formatted income statement with prior-month delta column
   - `Trial Balance` — accounts + ending balances
2. **`close-packet-{YYYY-MM}.pdf`** — one-page summary: P&L narrative + top-line numbers + gap count

Save both to the chosen `--save-to` location. Filename format: `close-packet-YYYY-MM.xlsx` (e.g. for the month being closed).

## Connector failures

If QuickBooks is unreachable, stop — reconciliation requires QB as the books-side source of truth. If Paywhere is unreachable, fall back to CSV upload (the owner exports transactions per account from the Paywhere dashboard) and note "Paywhere connector unavailable — reconciling against CSV." If both QB and Paywhere are unreachable, stop and ask the owner to reconnect.

## Approval gates

- **Never auto-fix flagged items.** Always show the gap, recommend an action, wait for the owner.
- **Never delete duplicates without explicit confirmation.** Show both records side-by-side.
- **Saving the packet is auto** — it goes to the owner's own drive.

## Output

End the run with a one-paragraph recap: revenue, margin, gap count remaining (if any), file paths to the saved packet. If gaps were not all resolved, list them so the owner can revisit.
