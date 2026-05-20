# Gotchas — cash-flow-snapshot

Known edge cases and connector failure modes. 2–5 entries, Good/Bad format.

---

## 1. QuickBooks AR aging includes invoices already collected

**Bad:** Including fully-paid invoices from the AR aging report inflates inflow
projections. QuickBooks sometimes shows $0-balance invoices in aging exports.

**Good:** Filter AR rows to `balance_due > 0` before computing inflows. If the
connector doesn't expose balance_due, cross-reference against Paywhere credits
(`get_account_transactions` with positive `amount` in the same window as the
invoice due date) and subtract any matching deposit from the invoice total
before including it.

---

## 2. Pending Paywhere transactions are not the same as settled cash

**Bad:** Treating pending Paywhere debits/credits as already settled. ACH
receipts can take 1–3 business days to clear; an in-flight wire may show up
as pending until the same day it lands. Counting them as settled inflows
produces overconfident cash timing.

**Good:** When pulling `get_account_transactions`, separate settled lines
from pending ones (the upstream payload exposes status — pending wires
through `get_wire_payment_status`, pending ACH through
`get_ach_payment_status`). Apply expected clearing windows: ACH 1–3 business
days, wire same-day, stablecoin receipt minutes-to-hours.

---

## 3. CSV column names are inconsistent across accounting exports

**Bad:** Requiring exact column names like "Date", "Amount", "Type". QuickBooks
CSV exports use "Transaction Date", "Amount", "Transaction Type". Wave uses
"Date", "Amount", "Account Type". Rigid parsing fails silently.

**Good:** Fuzzy-match column headers (date → transaction date → txn date;
amount → debit/credit; type → category → account type). Show the header row
to the user and confirm mapping before computing — one question beats a silent
wrong forecast.

---

## 4. Fixed costs hidden in one-off AP entries

**Bad:** Only pulling recurring line items labeled as "recurring" in QuickBooks.
Many SMBs don't tag fixed costs consistently — rent may appear as a one-off
vendor bill each month.

**Good:** Look for AP entries that appear in 3+ consecutive months with the same
vendor and similar amount (±10%). Treat these as recurring fixed costs in the
forecast. Surface the list to the user: "I'm treating these as fixed monthly
costs — does that look right?"

---

## 5. Confidence band formula breaks when mean payment lag is zero

**Bad:** Dividing stddev by a mean lag of 0 (e.g. customers who pay
immediately by wire) produces a divide-by-zero error or an infinite band.

**Good:** If mean lag ≤ 1 day, set band_pct to 5% (low variance, near-immediate
settlement). Don't attempt the division.
