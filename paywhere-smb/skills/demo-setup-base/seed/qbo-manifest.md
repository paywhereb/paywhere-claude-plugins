# QBO seed manifest — mirrors bank-manifest.md

The canonical QuickBooks seed for Meridian Staffing & Advisory LLC. Dates use
the tokens in [date-tokens.md](date-tokens.md); counterparty and rate data
come from [persona.md](persona.md); every bank row referenced below is defined
in [bank-manifest.md](bank-manifest.md).

Tool names verbatim (note the **hyphens** on bill/vendor CRUD): `create_invoice`,
`create_payment`, `search_payments`, **`create-bill`**, `create_bill_payment`,
**`create-vendor`**, `search_vendors`, `create_customer`, `search_customers`,
`create_item`, `search_items`, `create_deposit`, plus `search_invoices`,
`search_bills`, `search_bill_payments`, `search_deposits` for reset/dedupe.

**Kept/dropped lockstep rule:** every QBO transaction that mirrors a bank row
carries the same token and **inherits its kept/dropped status**. If a bank row
drops at the horizon, its QBO mirror is not created either — otherwise QBO
would show money movement the bank never saw.

## Master data — matched by DisplayName, created only if missing, NEVER deleted

Search first (`search_customers` / `search_vendors` / `search_items` by
DisplayName), create only what's missing, and report created-vs-existing.

- **Customers (5):** Thames Fintech Ltd, Zurich Dynamics AG, Alderbrook
  Ventures LLC, Mitsui Digital KK, Hallsten & Berg AB.
- **Vendors (15):** the 8 AP vendors (Amazon Web Services Inc, Gusto Inc,
  Sutter Hill Properties, Google Workspace, Slack Technologies, HubSpot Inc,
  Grant Henderson CPAs, DigitalOcean) + the 3 commission payees (Jane Doe
  Referrals, Acme Sales Partners LLC, CryptoConsult DAO) + the 4 workers as
  vendors (Priya Raman, Marcus Webb, Elena Sorokina, Devon Okafor). Workers
  and commission payees carry no bills in the base seed — they exist so
  /pay-and-bill and /pay-commissions can book against them immediately.
- **Items (4, type Service):** `Consulting Hours – Senior` (hourly; Thames @
  $130, Zurich @ $156 via per-line rates), `Contract Staffing Hours` (hourly;
  Alderbrook @ $104, Mitsui @ $117), `Advisory Retainer` (flat $8,500),
  `Staffing Placement` (one-off placement fee — reserved for live demos).

Deposits and bill payments post to the QBO bank account representing
**Operating Checking**; the two Reserve interest deposits post to the account
representing **Reserve Savings**. If the QBO company lacks a matching bank
account, ask the user which to use and note the substitution in the summary.

## DocNumber scheme

Every demo transaction carries a DocNumber prefixed **`PWD-`**:

| Prefix | Entity | Numbering |
|---|---|---|
| `PWD-INV-####` | Invoices | `01xx` = M-2, `02xx` = M-1, `03xx` = current cycle; `xx` = client order Thames 01, Zurich 02, Alderbrook 03, Mitsui 04, Hallsten 05 |
| `PWD-PAY-####` | Customer payments | same month prefix, chronological within month |
| `PWD-DEP-####` | Deposits | mirrors its payment's number; `xx07` = the month's interest deposit |
| `PWD-BILL-####` | Bills | same month prefix; paid bills chronological, open bills appended after them |
| `PWD-BPAY-####` | Bill payments | mirrors its bill's number |

If the fork's `create_payment` / `create_deposit` / `create_bill_payment`
lacks a DocNumber field, put the `PWD-` id at the start of `PrivateNote`
instead — `search_*` filters match it with `LIKE` either way.

## M-2 — fully reconciled month

Invoices (`create_invoice`, TxnDate `M-2:01`, DueDate `M-2:15`):

| DocNumber | Customer | Line | Amount |
|---|---|---|---|
| PWD-INV-0101 | Thames Fintech Ltd | Consulting Hours – Senior, 160 × $130 | 20,800.00 |
| PWD-INV-0102 | Zurich Dynamics AG | Consulting Hours – Senior, 150 × $156 | 23,400.00 |
| PWD-INV-0103 | Alderbrook Ventures LLC | Contract Staffing Hours, 150 × $104 | 15,600.00 |
| PWD-INV-0104 | Mitsui Digital KK | Contract Staffing Hours, 120 × $117 | 14,040.00 |
| PWD-INV-0105 | Hallsten & Berg AB | Advisory Retainer, 1 × $8,500 | 8,500.00 |

Payments (`create_payment`, applied to the invoice shown) + deposits
(`create_deposit`, same token, 1:1 with a bank credit):

| Payment / Deposit | Customer | Token | Amount | Applies to | Bank row match |
|---|---|---|---|---|---|
| PWD-PAY-0101 / PWD-DEP-0101 | Hallsten & Berg AB | M-2:03 | 8,500.00 | INV-0105 (closes) | ACH CR, M-2:03 |
| PWD-PAY-0102 / PWD-DEP-0102 | Thames Fintech Ltd | M-2:05 | 20,800.00 | INV-0101 (closes) | wire in, M-2:05 |
| PWD-PAY-0103 / PWD-DEP-0103 | Zurich Dynamics AG | M-2:06 | 23,400.00 | INV-0102 (closes) | wire in, M-2:06 |
| PWD-PAY-0104 / PWD-DEP-0104 | Mitsui Digital KK | M-2:10 | 7,020.00 | INV-0104 (partial) | wire in, M-2:10 |
| PWD-PAY-0105 / PWD-DEP-0105 | Mitsui Digital KK | M-2:24 | 7,020.00 | INV-0104 (closes) | wire in, M-2:24 |
| PWD-PAY-0106 / PWD-DEP-0106 | Alderbrook Ventures LLC | M-2:26 | 15,600.00 | INV-0103 (closes) | ACH CR, M-2:26 |
| PWD-DEP-0107 (deposit only) | — Reserve interest | M-2:31 | 93.75 | — | Cash deposit to Reserve, M-2:31 |

Bills (**`create-bill`**) + bill payments (`create_bill_payment`), TxnDate =
the token shown = the bank debit date:

| Bill / BillPayment | Vendor | Token | Amount | Bank row match |
|---|---|---|---|---|
| PWD-BILL-0101 / PWD-BPAY-0101 | Sutter Hill Properties | M-2:01 | 6,845.00 | **two** bank rows: rent 6,800 + wire fee 45 (bill has both lines) |
| PWD-BILL-0102 / PWD-BPAY-0102 | Amazon Web Services Inc | M-2:05 | 2,450.00 | ACH debit, M-2:05 |
| PWD-BILL-0103 / PWD-BPAY-0103 | Google Workspace | M-2:07 | 480.00 | ACH debit, M-2:07 |
| PWD-BILL-0104 / PWD-BPAY-0104 | Slack Technologies | M-2:07 | 375.00 | ACH debit, M-2:07 |
| PWD-BILL-0105 / PWD-BPAY-0105 | HubSpot Inc | M-2:10 | 1,160.00 | ACH debit, M-2:10 |
| PWD-BILL-0106 / PWD-BPAY-0106 | DigitalOcean | M-2:12 | 640.00 | ACH debit, M-2:12 |
| PWD-BILL-0107 / PWD-BPAY-0107 | Gusto Inc | M-2:13 | 11,700.00 | ACH debit, M-2:13 |
| PWD-BILL-0108 / PWD-BPAY-0108 | Grant Henderson CPAs | M-2:20 | 1,500.00 | ACH debit, M-2:20 |
| PWD-BILL-0109 / PWD-BPAY-0109 | Gusto Inc | M-2:27 | 11,700.00 | ACH debit, M-2:27 |

The M-2:24 sweep pair is bank-internal — **no QBO entity** (reconciliation
treats the matched Transfer out/in pair as self-matching).

## M-1 — fully reconciled month

**Identical to M-2** with `02xx` numbering and `M-1:dd` tokens, plus one
substitution: the interest deposit is **PWD-DEP-0207, token `EOM-1`,
$150.00**. Same 1:1 bank-row mapping, same rent two-row exception, same sweep
exclusion.

## M0 — deliberately incomplete (the demo surface)

### Current-cycle invoices (`create_invoice`, TxnDate `W-1:Mon`, DueDate `W+0:Fri+7`)

| DocNumber | Customer | Amount | State after seed |
|---|---|---|---|
| PWD-INV-0301 | Thames Fintech Ltd | 20,800.00 | paid (below) |
| PWD-INV-0302 | Zurich Dynamics AG | 23,400.00 | paid (below) |
| PWD-INV-0303 | Alderbrook Ventures LLC | 15,600.00 | **OPEN — no payment anywhere** (slow payer; the crunch's AR) |
| PWD-INV-0304 | Mitsui Digital KK | 14,040.00 | **half-paid — $7,020.00 balance open** |
| PWD-INV-0305 | Hallsten & Berg AB | 8,500.00 | **open in QBO, but the bank already has the cash** — payment deliberately NOT recorded (W-1:Mon ACH CR) |

### Recorded payments + deposits (mirror the W-1 bank credits)

| Payment / Deposit | Customer | Token | Amount | Applies to |
|---|---|---|---|---|
| PWD-PAY-0301 / PWD-DEP-0301 | Thames Fintech Ltd | W-1:Tue | 20,800.00 | INV-0301 (closes) |
| PWD-PAY-0302 / PWD-DEP-0302 | Zurich Dynamics AG | W-1:Wed | 23,400.00 | INV-0302 (closes) |
| PWD-PAY-0303 / PWD-DEP-0303 | Mitsui Digital KK | W-1:Thu | 7,020.00 | INV-0304 (partial) |

Deliberately **missing** from QBO: the Hallsten & Berg $8,500 payment
(W-1:Mon bank credit — the "received but not recorded" demo) and any entry for
the **$43.17** M0:02 interest credit (discrepancy a).

### Paid bills (mirror the kept M0 bank debits — lockstep rule applies)

| Bill / BillPayment | Vendor | Token | Amount | Note |
|---|---|---|---|---|
| PWD-BILL-0301 / PWD-BPAY-0301 | Sutter Hill Properties | M0:01 | 6,845.00 | rent 6,800 + fee 45, two lines |
| PWD-BILL-0302 / PWD-BPAY-0302 | Sutter Hill Properties | M0:03 | 2,500.00 | buildout deposit — **fee NOT booked**: bank shows +$1.20 fee row, QBO $0.00 (discrepancy b) |
| PWD-BILL-0303 / PWD-BPAY-0303 | Amazon Web Services Inc | M0:05 | 2,450.00 | |
| PWD-BILL-0304 / PWD-BPAY-0304 | Google Workspace | M0:07 | 480.00 | |
| PWD-BILL-0305 / PWD-BPAY-0305 | Slack Technologies | M0:07 | 375.00 | |
| PWD-BILL-0306 / PWD-BPAY-0306 | HubSpot Inc | M0:10 | 1,160.00 | |
| PWD-BILL-0307 / PWD-BPAY-0307 | DigitalOcean | M0:12 | 640.00 | |

### Open bills — the /pay-bills AP surface (no bill payments, no bank rows)

| Bill | Vendor | Rail | Amount | TxnDate | DueDate | Status at seed |
|---|---|---|---|---|---|---|
| PWD-BILL-0308 | DigitalOcean | ACH | 940.00 | M-1:15 | **W-1:Mon** | **OVERDUE** (reserved-capacity one-off) |
| PWD-BILL-0309 | Sutter Hill Properties | Wire | 1,850.00 | M-1:20 | **EOM-1** | **OVERDUE** (CAM/utilities true-up) |
| PWD-BILL-0310 | Grant Henderson CPAs | ACH | 3,200.00 | M-1:25 | **W-1:Fri** | **OVERDUE** (annual audit fee) |
| PWD-BILL-0311 | Amazon Web Services Inc | ACH | 2,450.00 | W-1:Wed | W+0:Fri | coming due (current-month usage, billed in arrears) |
| PWD-BILL-0312 | Google Workspace | ACH | 480.00 | W-1:Wed | W+0:Fri | coming due |
| PWD-BILL-0313 | Slack Technologies | ACH | 4,500.00 | W-1:Thu | W+0:Fri+7 | coming due (annual plan renewal) |

Open AP totals: **$5,990.00 overdue + $7,430.00 coming due = $13,420.00**.
Overdue due-dates use past tokens (`W-1:*`, `EOM-1`) so they are *always*
before today; coming-due bills use `W+0:Fri(+N)` — due dates are exempt from
the horizon drop rule.

## Reset procedure — finding and removing a prior demo seed

Before seeding, search for leftovers from a previous run: `search_invoices`,
`search_bills`, `search_payments`, `search_bill_payments`, `search_deposits`,
each filtering DocNumber `PWD-%` (the filters match with `LIKE`; fall back to
`PrivateNote LIKE 'PWD-%'` where DocNumber wasn't persisted). Show the user
what exists, and **only after approval** delete in dependency order:

1. payments → invoices
2. bill payments → bills
3. deposits

(`delete_payment`, `delete_invoice`, `delete_bill_payment`, **`delete-bill`**,
`delete_deposit`.) Customers, vendors, and items are matched by DisplayName
and **never deleted** on reset.

## Cross-check — the numbers must tie out with bank-manifest.md exactly

| Month | Invoiced | Payments received (QBO) | Bank client credits | Bills paid (QBO) | Bank debits − sweep |
|---|---|---|---|---|---|
| M-2 | 82,340.00 | 82,340.00 | 82,340.00 | 36,850.00 | 81,850.00 − 45,000.00 = 36,850.00 ✓ |
| M-1 | 82,340.00 | 82,340.00 | 82,340.00 | 36,850.00 | 36,850.00 ✓ |
| M0 | 82,340.00 | 51,220.00 | 59,720.00 | 14,450.00 | n/a (no sweep) — see below |

M0 reconciliation identities (full seed, before horizon drops):

- Bank M0 credits **$59,763.17** = QBO recorded deposits **$51,220.00**
  (20,800 + 23,400 + 7,020) + unrecorded Hallsten **$8,500.00** + unbooked
  interest **$43.17**. ✓
- Bank M0 debits **$14,451.20** = QBO bill payments **$14,450.00** + unbooked
  wire fee **$1.20**. ✓
- QBO deposit totals per month: M-2 **$82,433.75** (clients + 93.75 interest),
  M-1 **$82,490.00** (clients + 150.00 interest), M0 **$51,220.00** — each
  equals that month's bank credits minus the sweep-in and minus the
  deliberately unbooked M0 rows. ✓
- Open AR after seed: true **$22,620.00** (Alderbrook 15,600 + Mitsui balance
  7,020); QBO *shows* **$31,120.00** until the Hallsten payment is recorded
  (the 8,500 phantom is the bookkeeping demo).
- Commission spot-checks (rates per persona.md): 20,800×.05 = **1,040**;
  23,400×.10 = **2,340**; 7,020×.10 = **702**; 15,600×.05 = **780**;
  14,040×.10 = **1,404** — all whole dollars by design.
