# Close Packet Format Reference

The close packet is two files: an xlsx workbook and a one-page PDF summary.

## File naming

```
close-packet-2024-03.xlsx
close-packet-2024-03-summary.pdf
```

Use ISO 8601 year-month (`YYYY-MM`) in the filename. Default save location is the
Desktop; use the user's preferred path if specified.

---

## xlsx workbook — three sheets

### Sheet 1: P&L

A formatted copy of the QuickBooks P&L for the target month. Two-column layout:
**Category** and **Amount**.

Required rows (in order):
1. Revenue subtotal
2. COGS subtotal
3. **Gross Profit** (bold)
4. **Gross Margin %** (bold, formatted as %)
5. Operating expenses by category (each on its own row)
6. Total Operating Expenses
7. **Net Income** (bold)

Include a MoM comparison column if prior-month data is available. Format amounts as
currency (`$#,##0.00`). Negative values in red.

### Sheet 2: Reconciliation

Side-by-side comparison of QuickBooks transaction-register entries vs.
Paywhere bank lines for the month.

Columns:
| Column | Source |
|---|---|
| Date (QB) | QuickBooks TxnDate |
| Amount (QB) | QuickBooks signed amount |
| Account (Paywhere) | Paywhere account name (operating / payroll / reserve / etc.) |
| Date (Paywhere) | Paywhere `postDate` |
| Amount (Paywhere) | Paywhere signed `amount` |
| Type (Paywhere) | `ach` / `wire` / `stablecoin` / `transfer` / `fee` / `interest` |
| Counterparty | Extracted from Paywhere `description` (see `paywhere-bank-lines.md`) |
| Delta | QB amount minus Paywhere amount |
| Status | RECONCILED / MISSING_IN_QB / MISSING_IN_PAYWHERE / DATE_MISMATCH / IN_TRANSIT |

Color-code the Status column:
- RECONCILED → green fill
- DATE_MISMATCH → yellow fill
- IN_TRANSIT → yellow fill
- MISSING_IN_QB or MISSING_IN_PAYWHERE → red fill

### Sheet 3: Action Items

Any open flags from the checklist. Columns:
| Column | Notes |
|---|---|
| Category | Uncategorized Txn / Missing Receipt / Duplicate / Reconciliation Flag |
| Date | Transaction date |
| Amount | Dollar amount |
| Vendor / Customer | Name |
| Description | What's wrong and what to do |

If there are no open items, show a single row: "No open action items — books are clean."

---

## PDF summary — one page

Layout (top to bottom):

```
[Business Name]                    Close Packet — [Month Year]
────────────────────────────────────────────────────────────

KEY FIGURES
Revenue        $XX,XXX
Gross Margin   XX%
Net Income     $XX,XXX

P&L SUMMARY
[150–250 word plain-English narrative from Step 7]

ACTION ITEMS
X uncategorized transactions · X missing receipts · X open flags
[or "Books are clean — no open items." if all clear]

────────────────────────────────────────────────────────────
Prepared [Date] · Powered by Claude
```

Use a clean sans-serif font (Helvetica or equivalent). No logo required. Keep
margins ≥ 0.75 in on all sides so it prints cleanly.

**Generating the PDF:** Use the `xlsxwriter` or `reportlab` Python library if running
a script, or instruct Claude to render the content and export via the Desktop
connector's print-to-PDF capability. The user can also print the PDF from the xlsx
P&L sheet if a script isn't available.
