# Connector Query Guide

How to pull the right data from each connector for each mode.

---

## QuickBooks — Quarterly mode (P&L)

Pull a **Profit & Loss** report for the period January 1 through the last day of the most recently completed quarter.

Key fields to capture:
- `Total Income` (gross revenue)
- `Total Expenses` (all operating expenses)
- `Net Ordinary Income` (= income − expenses; this is the basis for tax calculation)

If QuickBooks returns multiple income/expense categories, sum them. You want the single
bottom-line net profit figure.

**If the user's QuickBooks is on cash basis**, use that. If accrual, note it in output —
the accountant should confirm which basis to use for estimated taxes.

---

## QuickBooks — Year-end mode (contractor payments)

Pull all **bill payments and checks** to vendors for the full tax year (Jan 1 – Dec 31).

Filter for:
- Vendor type = "1099 eligible" (if the user has tagged vendors in QuickBooks)
- OR any vendor whose category is: consulting, contract labor, subcontractor, freelance, design, legal, accounting, marketing, staffing

For each vendor record, capture:
- Vendor name (legal name if available)
- EIN / SSN (from vendor profile — indicates W-9 on file)
- Total payments for the year
- Payment dates and amounts (for cross-reference)
- Vendor type / 1099 eligibility flag

**Common issue:** Many QuickBooks users do not tag vendors as 1099-eligible. If
`1099 eligible` returns few or no results, pull ALL vendors with significant payment
totals and let the user / accountant classify them. Note this in output.

---

## Paywhere — Year-end mode (cross-check)

Pull ACH and wire **outflows** for the tax year as a completeness check on
QuickBooks. The bank doesn't generate 1099-K forms, so this is purely about
catching contractor payments the owner forgot to book.

For each Paywhere account from `list_accounts`, call
`get_account_transactions` scoped to the tax year.

Filter to debit lines (negative `amount`) with `type` in (`ACH`, `DomesticWire`).
For each line:

- Extract counterparty from `description` (heuristics in
  `month-end-prep/reference/paywhere-bank-lines.md`).
- Aggregate by counterparty.
- Cross-reference each counterparty against QuickBooks vendor records:
  - **Counterparty matches a QB vendor** → confirms the QB record (sanity check on total).
  - **Counterparty has no matching QB vendor** → surface for accountant review under "Paywhere reconciliation note" in the deliverable.

**Exclude:** internal transfers between the owner's own Paywhere accounts
(`type: "transfer"`), payroll provider payments if the owner uses an
external payroll service (those generate their own W-2s), and stablecoin
payouts to wallets the owner controls.

---

## Desktop / CSV fallback

If any connector is unavailable, ask the user to:
1. Export a P&L from QuickBooks as CSV (Reports → Profit & Loss → Export)
2. Export a Transaction List by Vendor from QuickBooks as CSV
3. Export each Paywhere account's transactions as CSV from the Paywhere dashboard (Activity → Export)

When reading uploaded CSVs, look for these columns (names vary by export):
- P&L: `Description`, `Amount`, `Type` (Income / Expense)
- QB Vendor: `Vendor`, `Amount`, `Date`, `Account`
- Paywhere: `postDate`, `amount`, `description`, `type`

If columns don't match, ask the user to identify the payee name and amount columns.
