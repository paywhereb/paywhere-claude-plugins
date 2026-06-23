# Worked example — cash-flow-snapshot

**Scenario:** Small services business. QuickBooks + Paywhere connected. Three
active customers, monthly payroll, office rent.

---

## Input data (pulled from connectors)

**AR aging (QuickBooks):**

| Customer       | Invoice | Amount   | Due Date   | Days Outstanding |
|----------------|---------|----------|------------|------------------|
| Acme Corp      | INV-112 | $2,520   | Apr 10     | 12               |
| BlueSky LLC    | INV-108 | $4,260   | Apr 22     | 0                |
| Crestwood Inc  | INV-115 | $1,800   | May 5      | —                |

**Historical payment lag (computed from prior Paywhere credits matched to QB invoices):**

| Customer       | Mean Lag | Std Dev | Payments on Record |
|----------------|----------|---------|--------------------|
| Acme Corp      | 18 days  | 4 days  | 11                 |
| BlueSky LLC    | 7 days   | 2 days  | 8                  |
| Crestwood Inc  | 12 days  | 5 days  | 6                  |

**Fixed costs (QuickBooks recurring AP):**
- Payroll: $6,600 — hits April 15
- Rent: $960 — hits May 1
- Software subscriptions: $144 — hits May 1

---

## Step 3 output — adjusted inflow dates

| Customer       | Invoice Amount | Adj. Receipt Date | Notes                             |
|----------------|---------------|-------------------|-----------------------------------|
| Acme Corp      | $2,520        | Apr 28            | Due Apr 10 + 18-day mean lag      |
| BlueSky LLC    | $4,260        | Apr 29            | Due Apr 22 + 7-day mean lag       |
| Crestwood Inc  | $1,800        | May 17            | Due May 5 + 12-day mean lag       |

---

## Step 4 output — 30/60/90 forecast

Confidence band calculation:
- Weighted avg stddev: 3.6 days
- Weighted avg mean lag: 12.7 days
- band_pct = 3.6 / 12.7 = **28.3%**

| Window  | Expected Inflows | Expected Outflows | Net      | Low (−28%) | High (+28%) |
|---------|-----------------|-------------------|----------|------------|-------------|
| 0–30d   | $6,780          | $6,600            | +$180    | −$1,718    | +$2,078     |
| 31–60d  | $1,800          | $1,104            | +$696    | +$192      | +$1,200     |
| 61–90d  | $0              | $0                | $0       | —          | —           |

---

## Step 5 output — risks flagged

1. **Payroll crunch:** Payroll ($6,600) hits April 15. Low-band inflows through
   April 14: $0 (both AR receipts fall April 28–29). Shortfall risk: up to $6,600.
   *Recommend: confirm receivables timing with Acme and BlueSky before April 14.*

2. **Late-payer risk:** Acme Corp historically pays 18 days late. Their $2,520
   invoice (due Apr 10) shifts to April 28 — after payroll.

---

## Step 6 output — chat summary

```
Cash Flow Snapshot — Apr 23 → Jul 21, 2026
Sources: QuickBooks, Paywhere

              Expected    Low        High
30-day net:   +$180      −$1,718    +$2,078
60-day net:   +$696      +$192      +$1,200
90-day net:   $0         —          —

⚠ 2 risks flagged:
  • Payroll crunch: $6.6K payroll hits Apr 15; AR receipts don't clear until
    Apr 28–29. Low-band shortfall risk: up to $6,600.
  • Late-payer: Acme Corp (mean 18-day lag) shifts $2,520 past payroll date.

Confidence band: ±28% (based on historical payment variance across 3 customers).

This forecast is based on QuickBooks AR/AP and Paywhere settled bank activity.
It is not a substitute for accounting advice — verify with your bookkeeper
before making financing decisions.
```

**XLSX:** `cash-flow-snapshot-2026-04-23.xlsx` — Summary / Detail / Risks sheets.
