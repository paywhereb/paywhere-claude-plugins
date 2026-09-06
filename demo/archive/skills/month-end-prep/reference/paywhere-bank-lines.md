# Bank lines — reconciliation reference

The mock bank's transaction record has seven fields and no counterparty, category, check-number, fee or interest type. **The statement descriptor carries the rail.** Everything below describes descriptor *conventions* to look for; confirm what a given world actually contains before relying on a stem.

## Pulling

1. `list_accounts` — one entry per account (operating checking, tax reserve, savings). Identify by name / type / `isPrimary`, never by number.
2. `get_account_balance` per account — anchors the month-end book balance ± timing items.
3. `query_transactions {dateFrom, dateTo, status: ["posted"]}` per account — the month's posted rows; `status: ["pending"]` for in-transit card authorizations. Slice the range if `truncated: true`. (`get_account_transactions` pages raw rows if you need them unfiltered.)

## Transaction shape

| Field | Notes |
|---|---|
| `id` | Stable line id; the key for `get_transaction_detail`. |
| `postDate` | Compare on the date part. |
| `amount` | Signed. Positive = credit (money in), negative = debit (money out). |
| `description` | Human label. |
| `statementDescription` | The raw descriptor — **match and fingerprint on this**. |
| `status` | `posted` / `pending`. |
| `type` | `ACH`, `DomesticWire`, `Transfer`, `Cash`. Checks, card purchases, fees and interest all ride on these four; the descriptor tells them apart. |

There is no fee field: fees post as their own lines.

## Descriptor conventions by rail

| Descriptor stem | Direction | What it is | Books counterpart |
|---|---|---|---|
| `POS DEBIT <MERCHANT> <store#> <CITY ST>` | debit | Debit-card purchase | `Purchase` (payment type Cash/Check to the bank account); ≈ a few % are typically **unrecorded** |
| `RECURRING DEBIT <VENDOR>` | debit | Card-on-file subscription | `Purchase`; see `subscription-audit` |
| `ACH DEBIT <PAYEE>` | debit | ACH to a saved payee or a vendor auto-debit | `BillPayment` (vendor bill) or `Purchase` (auto-debit) |
| `ACH DEBIT <PAYROLL PROCESSOR> NET PAY` / `… TAX` | debit | Payroll run (net + taxes, biweekly) | `JournalEntry` (wages, employer taxes, reimbursements) |
| `ACH CR <CUSTOMER>` | credit | Customer paid by ACH from their own bank / AP system; one row = one invoice | `Payment` → deposited directly to the bank account |
| `MOBILE CHECK DEPOSIT <check#> <CUSTOMER>` | credit | Check deposited | `Payment` (check number in the payment) grouped by a `Deposit`; one may be **received-but-unbooked** |
| `WIRE IN <SENDER>` (+ a small wire-fee debit) | credit | Project milestone / large invoice | `Payment` + `Deposit`; fee as bank charge |
| `WIRE OUT <PAYEE>` (+ wire-fee debit) | debit | Wire to a subcontractor / vendor | `BillPayment` |
| `INTUIT PYMT SOLN DEPOSIT` (or the merchant provider's stem) | credit | **Net** merchant settlement, T+1 card / T+2 ACH, grouped daily | `Deposit` of that day's card payments at **gross** with a **negative merchant-fee line**; some deposits are missing the line |
| `TRANSFER TO <ACCOUNT>` / `TRANSFER FROM <ACCOUNT>` | debit / credit | Internal transfer (Friday tax sweep to the reserve, savings sweep, owner distribution) | `Transfer`; owner draws to equity |
| `ACH DEBIT <STATE> DEPT OF REVENUE` | debit (from the tax reserve) | Sales-tax remittance on the 20th | `Purchase` against the per-state liability account |
| `ACH DEBIT IRS USATAXPYMT` | debit | Owner quarterly estimate | Equity draw, not expense |
| `SERVICE CHARGE` | debit | Monthly bank fee | `Purchase` to bank charges |
| `INTEREST PAID` | credit (savings) | Interest | `Deposit` line to interest income |

## Settlement matching (gross → net)

```
for each bank credit with the merchant stem on day D:
    candidates = books Deposits with txnDate in [D−2, D] to the operating account
    match if deposit.gross + deposit.feeLine.amount == bank.amount (±0.50)   # feeLine negative
    else if deposit has NO fee line and 0.01×gross ≤ (gross − bank) ≤ 0.04×gross + 0.30×paymentCount:
        FEE_NOT_POSTED, difference = gross − bank
```

Report matched settlements as one row with gross / fee / net. A settlement can span two books Deposits when the provider batches card and ACH separately — check the sum before flagging.

## Counterparty extraction

`get_transaction_detail` first (best-effort enrichment: counterparty, memo, category, doc ref — may be `null`). Then the descriptor: the token after the rail prefix, minus store numbers, city/state and reference ids (rules in `../../subscription-audit/reference/normalization.md`). Never drop a row you cannot name — show the full descriptor.

## Pending vs posted

`status: "pending"` rows are card authorizations not yet settled. Report them as `IN_TRANSIT` with the descriptor; reconcile them next month. Payment tools in this deployment **stage proposals** rather than execute, so a payment the owner has not yet approved on the bank's page has no bank row at all — do not expect one.

## Reconciliation logic

```
for each bank line in the month (per account):
    find register entry: |amount diff| < 0.50, |date diff| ≤ 2 days, same sign,
                          and (counterparty stem matches OR memo carries the bank id)
    RECONCILED / DATE_MISMATCH / MISSING_IN_QB / MISSING_IN_BANK / IN_TRANSIT
```

Run per account, then aggregate: a deposit missing from Operating may have landed in the reserve or savings (interest, transfers). Internal transfers appear twice (debit on one account, credit on the other) — pair them before flagging.
