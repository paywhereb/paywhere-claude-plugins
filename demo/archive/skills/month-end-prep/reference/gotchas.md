# Gotchas

Common mistakes and edge cases in month-end close. Each entry has the pattern,
the reason it matters, and a Bad / Good example.

---

## Gotcha: Flagging split transactions as duplicates

**Why it matters:** A single purchase split across multiple GL categories appears
as multiple rows in the QB export — same vendor, same date, different amounts.
Flagging these as duplicates sends the owner on a wild goose chase.

### ✗ Bad

> Flagged as duplicate: Office Depot $47.50 on March 12 and Office Depot $62.50
> on March 12 — same vendor, same date.

Both rows share the same `TxnID` — they're splits of a $110 purchase across
"Office Supplies" and "Equipment."

### ✓ Good

Before flagging duplicates, group rows by `TxnID`. Only compare transactions
with distinct IDs. Splits of the same transaction are never duplicates.

---

## Gotcha: Treating a refund as a missing debit

**Why it matters:** A refund issued by the business appears as a Paywhere
debit (negative `amount`) with no matching deposit. If you treat it as an
unmatched outflow, you'll flag a legitimate refund as a problem.

### ✗ Bad

> Flagged: Paywhere outflow of –$89.00 on March 18 has no matching QB deposit.
> Possible missing transaction.

The –$89.00 is a refund to a customer. It should match a QB credit memo,
not a deposit.

### ✓ Good

Separate inflows (positive `amount`) from outflows (negative `amount`)
before reconciling. Match negative Paywhere lines against QB credit memos or
refund transactions, not deposits. Only flag an unmatched negative if no
credit memo exists in QB.

---

## Gotcha: Treating a wire fee line as part of the parent transaction

**Why it matters:** the bank posts wire fees as their own debit lines (the
descriptor names the fee; there is no fee `type`). They are not deducted
from the parent inflow or outflow. Subtracting them produces phantom
discrepancies. **Merchant settlements are the opposite case**: the fee IS
netted inside the deposit, and the books carry it as a negative line on the
Deposit — see `paywhere-bank-lines.md`.

### ✗ Bad

> Discrepancy: Paywhere wire inflow $5,000.00, QB deposit $4,975.00 —
> delta $25.00. Flagged as reconciliation error.

The $25.00 is a separate Paywhere fee line posted the same day. The wire
itself reconciles 1:1 against QB; the fee line reconciles against the QB
"Bank Fees" GL line.

### ✓ Good

Match fee-descriptor lines independently — usually to a "Bank Charges" GL
category. Do not subtract them from the parent transaction's amount when
comparing against the books.

---

## Gotcha: Flagging a gross→net settlement match as a discrepancy

**Why it matters:** the books' Deposit for a settlement day is gross of
processing fees with a negative fee line; the bank credit is net. The two
amounts differ by design.

### ✗ Bad

> Discrepancy: bank deposit $2,398.44, books Deposit $2,470.00 — delta
> $71.56. Flagged.

### ✓ Good

Compare `gross + feeLine` with the bank amount. If a fee line exists and
the sum matches, the row is RECONCILED (show gross / fee / net). If there is
**no** fee line and the gap is a plausible fee, it is FEE_NOT_POSTED — the
finding is the missing line, not a bad deposit.

---

## Gotcha: Advancing past Step 6 when there are unresolved flags

**Why it matters:** The close packet is the final artifact the owner files or
shares with their accountant. Exporting it with open flags bakes errors into
the record.

### ✗ Bad

> Owner hasn't responded about the 3 uncategorized transactions. Generating
> the close packet now so they have something to look at.

### ✓ Good

Hold at the Step 6 gate until the owner acknowledges every flag — either
resolving it ("categorize this as office supplies") or explicitly deferring it
("mark that as 'to review later'"). Only then export. Open items that the owner
deferred should appear in the Action Items sheet, not be silently dropped.
