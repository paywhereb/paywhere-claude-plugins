# Close Packet Format Reference

The close packet is two files: an xlsx workbook and a one-page PDF summary.

## File naming

```
close-packet-2024-03.xlsx
close-packet-2024-03-summary.pdf
```

Use ISO 8601 year-month (`YYYY-MM`) in the filename. Save into the working
folder under `close/`; use the owner's preferred path if specified.

---

## xlsx workbook — five sheets

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
| Rail (descriptor) | POS / RECURRING / ACH / CHECK / WIRE / MERCHANT SETTLEMENT / TRANSFER / FEE / INTEREST (from the descriptor stem) |
| Counterparty | Extracted from the descriptor / enrichment (see `paywhere-bank-lines.md`) |
| Gross / Fee / Net | Filled for merchant settlements only (books gross, fee line, bank net) |
| Delta | QB amount minus bank amount (0 for a gross→net match) |
| Status | RECONCILED / MISSING_IN_QB / MISSING_IN_BANK / DATE_MISMATCH / IN_TRANSIT / FEE_NOT_POSTED |

Color-code the Status column:
- RECONCILED → green fill
- DATE_MISMATCH → yellow fill
- IN_TRANSIT → yellow fill
- FEE_NOT_POSTED → orange fill
- MISSING_IN_QB or MISSING_IN_BANK → red fill

### Sheet 3: Settlement Fees

One row per merchant settlement in the month:
| Column | Notes |
|---|---|
| Settlement date | Bank `postDate` |
| Bank net | Bank credit amount |
| Books deposit ref | Deposit DocNumber |
| Books gross | Sum of the grouped payments |
| Fee line | Negative fee line amount, or blank |
| Difference | Gross + fee line − bank net |
| Status | MATCHED / FEE_NOT_POSTED |
| Narrated fix | e.g. "add −$71.56 Merchant Fees line to Deposit 1043" |

Total row: unbooked merchant fees for the month.

### Sheet 4: Unrecorded Purchases

Bank card debits with no books Purchase:
| Column | Notes |
|---|---|
| Date | Bank `postDate` |
| Amount | Debit amount |
| Descriptor | Full `statementDescription` |
| Stem | Normalized vendor stem |
| Suggested account | Expense account a prior purchase for the stem used, if any |
| Narrated fix | "record a Purchase of $X to <account> dated <date>" |

### Sheet 5: Action Items

Any open flags from the checklist. Columns:
| Column | Notes |
|---|---|
| Category | Uncategorized Txn / Missing Receipt / Duplicate / Fee Not Posted / Unrecorded Purchase / Refund / Failed Autopay / Reconciliation Flag |
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
X uncategorized · X fees not posted (${total}) · X unrecorded purchases · X missing receipts
[or "Books are clean — no open items." if all clear]

────────────────────────────────────────────────────────────
Prepared [Date] · Powered by Claude
```

Use a clean sans-serif font (Helvetica or equivalent). No logo required. Keep
margins ≥ 0.75 in on all sides so it prints cleanly.

**Generating the files:** use whatever file tooling the client provides (Cowork
writes xlsx/PDF with its own tooling; in Claude Code a small script with
`openpyxl` / `reportlab` works). Do not assume a specific library is present —
check, then write. Both files go to `close/` in the working folder.
