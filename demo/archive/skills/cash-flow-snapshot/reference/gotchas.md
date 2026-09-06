# Gotchas — cash-flow-snapshot

## 1. Counting the reserve or savings as cash
**Bad:** summing all three balances as the opening position.
**Good:** Operating only. The Tax Reserve holds money the business owes the state; Business Savings is the owner's cushion. Say both are excluded, every run.

## 2. Timing AR by due date instead of behavior
**Bad:** placing an invoice's cash in its due-date week.
**Good:** due date + the customer's mean lag from 12 months of paid invoices. A routinely-late payer's invoice lands two or three weeks later than the books suggest; that is often the whole minimum-balance story.

## 3. Double-counting a received-but-unbooked credit
**Bad:** an invoice still open in the books whose check already cleared the bank appears both in the opening balance and in week-1 inflows.
**Good:** match recent bank credits (`query_transactions direction: "credit"`, 14 days) to open invoices on amount + counterparty stem; drop matched invoices from inflows and note them for the bookkeeper.

## 4. Modeling bills at the owner's habit instead of the due date
**Bad:** pulling a bill forward because the owner "always pays that one early."
**Good:** model at due date and annotate the habit. The gap between the two is the `pay on due date` lever.

## 5. Payroll from the books instead of the bank
**Bad:** reading payroll from journal entries only, missing the split between net and tax debits and the actual debit day.
**Good:** the bank's processor debits show the real cadence and total; the books confirm the components.

## 6. Calendar events with no amount
**Bad:** silently skipping them, or inventing a figure.
**Good:** list them under "dated, unquantified" so the owner can supply the number; they become owner-stated lines.

## 7. `query_transactions` truncation
**Bad:** aggregating over a window that returns `truncated: true`.
**Good:** narrow to one account or a shorter window and re-query; 3 accounts × 12 months normally fits under the scan cap.
