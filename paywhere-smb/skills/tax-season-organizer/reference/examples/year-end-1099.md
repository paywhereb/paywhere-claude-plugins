# Worked Example: Year-End 1099 Prep

**Scenario:** Marcus owns a small marketing agency. In early January of
`Y+1` he asks: "I need to send out my 1099s — can you pull together a list
of who needs one?" The tax year is `Y`. Figures are illustrative.

---

## Step 1: Read payments from both sources in one turn (5 calls)

**QuickBooks** — `search_vendors` ∥ `search_bill_payments {Y}` ∥
`search_purchases {Y}`, summed per vendor:

| Vendor | Total paid | is1099 | Tax id on file? |
|---|---|---|---|
| Jenna Torres (copywriter) | $8,400 | Yes | Yes |
| Apex Web Solutions | $15,200 | Yes | Yes |
| Bob Nguyen | $550 | No | No |
| Parcel carrier | $320 | No | No |
| Spark Digital Inc. | $6,000 | Yes | Yes |

**Paywhere** — `query_transactions {direction: "debit", dateFrom: "Y-01-01",
dateTo: "Y-06-30"}` ∥ the same for `Y-07-01` → `Y-12-31`; ACH and wire rows
kept, card / payroll / transfers dropped; counterparty from the descriptor
stem:

| Counterparty | Total sent | Type | Notes |
|---|---|---|---|
| Jenna Torres | $1,200 | ACH | Likely the same as the QuickBooks vendor |
| Design by Mike | $2,100 | ACH | Not in QuickBooks |
| Bob Nguyen | $480 | ACH | |

No `get_transaction_detail` needed — every descriptor was readable.

---

## Step 2: Aggregate and deduplicate

| Payee | QuickBooks | Bank | Total | Notes |
|---|---|---|---|---|
| Jenna Torres | $8,400 | $1,200 | **$9,600** | Same person — counterparty match; confirm the books have all $9,600 |
| Apex Web Solutions | $15,200 | — | **$15,200** | |
| Spark Digital Inc. | $6,000 | — | **$6,000** | |
| Design by Mike | — | $2,100 | **$2,100** | Bank only; name from the descriptor |
| Bob Nguyen | $550 | $480 | **$1,030** | Combined crosses $600 |
| Parcel carrier | $320 | — | $320 | Goods/shipping, below threshold — exempt |

---

## Step 3: Threshold and W-9 status

- Jenna Torres — $9,600 → **1099-NEC** · W-9 on file
- Apex Web Solutions — $15,200 → **1099-NEC candidate** · W-9 on file · may be a corporation (confirm)
- Spark Digital Inc. — $6,000 → **1099-NEC candidate** · W-9 on file · "Inc." — likely corporate-exempt (confirm)
- Design by Mike — $2,100 → **1099-NEC** · W-9 **missing** · bank-only, not booked
- Bob Nguyen — $1,030 → **1099-NEC** · W-9 **missing**
- Parcel carrier — $320 → not required

---

## Step 4: The file — `tax/1099-prep-Y.md`

```
## 1099 prep list — Y
Prepared January 10, Y+1 · For review by your accountant — not tax advice

### Summary
- Payees paid for services: 5 candidates
- Require 1099-NEC (≥ $600 for services): 5
- Missing W-9: 2 — collect before filing (deadline January 31, Y+1)
- Corporation exemption to confirm: 2 (Apex, Spark)
- Bank-only payments with no vendor record: 1 (Design by Mike)

### 1099-NEC candidates

| Payee | Total paid | Source(s) | W-9 status | Notes |
|---|---|---|---|---|
| Jenna Torres | $9,600 | Books + bank ACH | On file | Confirm the books carry the full $9,600 |
| Apex Web Solutions | $15,200 | Books | On file | May be a corporation; confirm exemption |
| Spark Digital Inc. | $6,000 | Books | On file | "Inc." — likely exempt; confirm |
| Design by Mike | $2,100 | Bank ACH only | Missing | Full legal name unknown; not in the books |
| Bob Nguyen | $1,030 | Books + bank ACH | Missing | $550 booked + $480 bank-only |

### Missing W-9 action list
1. **Design by Mike** — paid $2,100 by ACH. Obtain the full legal name and a W-9.
2. **Bob Nguyen** — paid $1,030 across both sources. W-9 not on file.

### Bank reconciliation note
Design by Mike received $2,100 by ACH from Operating and has no vendor
record in the books. Bob Nguyen's $480 bank payment is also unbooked.
Confirm with your accountant whether these should be entered before filing.

### Next steps for your accountant
- [ ] Collect W-9 from Design by Mike (full legal name first)
- [ ] Collect W-9 from Bob Nguyen
- [ ] Confirm corporation exemption for Apex Web Solutions and Spark Digital Inc.
- [ ] Book the two bank-only payments in the books
- [ ] File 1099-NECs and the 1096 transmittal by January 31, Y+1
```

## Step 5: Reply (chat)

> Five 1099-NEC candidates, two missing W-9s (Design by Mike, Bob Nguyen),
> one payee paid from the bank with no vendor record. Written to
> `tax/1099-prep-Y.md`. Five tool calls; nothing filed.
