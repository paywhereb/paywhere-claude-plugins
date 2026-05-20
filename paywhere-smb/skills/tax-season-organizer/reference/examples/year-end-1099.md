# Worked Example: Year-End 1099 Prep

**Scenario:** Marcus owns a digital marketing agency. He asks: "I need to send out
my 1099s — can you pull together a list of who needs one?"

---

## Step 1: Pull contractor payments from all sources

**QuickBooks** (Jan 1 – Dec 31, 2024):

| Vendor | Total paid | 1099 eligible? | EIN/SSN on file? |
|--------|-----------|----------------|-----------------|
| Jenna Torres (copywriter) | $8,400 | Yes | Yes |
| Apex Web Solutions | $15,200 | Yes | Yes |
| Bob Nguyen | $550 | No | No |
| FedEx | $320 | No | No |
| Spark Digital Inc. | $6,000 | Yes | Yes |

**Paywhere** (ACH/wire outflows, 2024 — counterparty extracted from `description`):

| Counterparty | Total sent | Type | Notes |
|--------------|-----------|------|-------|
| Jenna Torres | $1,200 | ACH | Likely same as QuickBooks vendor |
| Design by Mike | $2,100 | ACH | Not in QuickBooks |
| Bob Nguyen | $480 | ACH | |

---

## Step 2: Aggregate and deduplicate

Cross-referencing QuickBooks and Paywhere:

| Payee | QuickBooks | Paywhere | Total | Notes |
|-------|-----------|----------|-------|-------|
| Jenna Torres | $8,400 | $1,200 | **$9,600** | Same person — counterparty match |
| Apex Web Solutions | $15,200 | — | **$15,200** | |
| Spark Digital Inc. | $6,000 | — | **$6,000** | |
| Design by Mike | — | $2,100 | **$2,100** | Not in QuickBooks; payee name from `description` |
| Bob Nguyen | $550 | $480 | **$1,030** | Combined > $600; flagged |
| FedEx | $320 | — | $320 | Below threshold; goods/shipping — exempt |

---

## Step 3: Apply $600 threshold and W-9 check

- Jenna Torres: $9,600 ✅ → **1099-NEC required** · W-9 on file (EIN recorded in QB)
- Apex Web Solutions: $15,200 ✅ → **1099-NEC candidate** · W-9 on file · Note: may be a corp (confirm)
- Spark Digital Inc.: $6,000 ✅ → **1099-NEC candidate** · W-9 on file · "Inc." — likely corp exempt (confirm)
- Design by Mike: $2,100 ✅ → **1099-NEC required** · W-9 not on file — must collect; payment was Paywhere-only with no QB record, so the accountant should also confirm the QB booking
- Bob Nguyen: $1,030 ✅ → **1099-NEC required** · W-9 not on file — must collect
- FedEx: $320 → below threshold; goods/shipping — not required

---

## Step 4: Output delivered to Marcus

```
## 1099 prep list — 2024
Prepared January 10, 2025 · For review by your accountant · Not tax advice

### Summary
- Contractors paying: 5 candidates identified
- Require 1099-NEC (≥$600 for services): 5
- Missing W-9: 2 — action required before January 31
- Corporation exemption review needed: 2 (Apex, Spark)
- Paywhere-only contractor payments needing accountant review: 1 (Design by Mike)

### 1099-NEC candidates

| Payee | Total paid | Source(s) | W-9 status | Notes |
|-------|-----------|-----------|------------|-------|
| Jenna Torres | $9,600 | QB + Paywhere ACH | ✅ EIN on file | Confirm QB has the full $9,600 booked |
| Apex Web Solutions | $15,200 | QuickBooks | ✅ EIN on file | "Solutions" — may be corp; confirm exemption with accountant |
| Spark Digital Inc. | $6,000 | QuickBooks | ✅ EIN on file | "Inc." — likely corp-exempt; confirm with accountant |
| Design by Mike | $2,100 | Paywhere ACH only | ⚠️ Missing W-9 | Full name unknown — obtain before filing; not in QB |
| Bob Nguyen | $1,030 | QB + Paywhere ACH | ⚠️ Missing W-9 | Combined QB ($550) + Paywhere ($480) = $1,030 |

### Missing W-9 action list
These contractors must provide a W-9 before you can file:

1. **Design by Mike** — paid $2,100 via Paywhere ACH. Obtain full legal name and W-9.
   IRS W-9 form: https://www.irs.gov/pub/irs-pdf/fw9.pdf
2. **Bob Nguyen** — paid $1,030 (QB + Paywhere). W-9 not on file for either source.

### Paywhere reconciliation note
Design by Mike received $2,100 via ACH from your Paywhere operating account
but has no QuickBooks vendor record. Confirm with your accountant whether
this should also be booked in QB before filing.

### Next steps for your accountant
- [ ] Collect W-9 from Design by Mike (full legal name needed first)
- [ ] Collect W-9 from Bob Nguyen
- [ ] Confirm corporation exemption for Apex Web Solutions
- [ ] Confirm corporation exemption for Spark Digital Inc.
- [ ] Book Design by Mike's $2,100 in QuickBooks (Paywhere ACH out, not in QB)
- [ ] File 1099-NECs by January 31, 2025
- [ ] File 1096 transmittal with IRS by January 31, 2025
```
