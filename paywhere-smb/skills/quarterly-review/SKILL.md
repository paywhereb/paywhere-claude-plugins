---
name: quarterly-review
description: Generates a full QBR narrative — revenue trend, margin trend, customer health, top opportunities and risks — as a presentation-ready PDF or deck. Accepts optional quarter and save-to arguments.
allowed-tools: Read, WebFetch, Bash
---

Run the quarterly business review. Pull financial, sales, and customer data for the quarter, synthesize it into a narrative, and produce a presentation-ready document.

Parse arguments:
- `--quarter` (default: previous calendar quarter) — format `YYYY-QN` (e.g., `2026-Q1`)
- `--save-to` (default: `files`) — `files` (Google Drive), `desktop`, or `both`

## Step 1 — Financial performance

Using the `business-pulse` skill in deep mode:

1. Pull QuickBooks P&L for the quarter: revenue, COGS, gross margin, operating expenses, net margin.
2. Compare to prior quarter and same quarter last year (if available).
3. Pull Paywhere inflows for the same period (`get_account_transactions` across accounts, positive `amount` only) to validate QB revenue against cash actually received.
4. Calculate: revenue growth %, margin change in points, top 3 revenue categories.

## Step 2 — Customer concentration

1. Pull QuickBooks revenue by customer for the quarter (invoices / sales receipts grouped by `CustomerRef`).
2. Calculate revenue per customer and rank customers by contribution.
3. Flag any customers representing >20% of revenue (concentration risk) and any large customer whose revenue dropped sharply vs. the prior quarter.

## Step 3 — Top opportunities

Identify 3 specific opportunities for next quarter based on the data:
- Revenue upside (category, customer segment, or channel to double down on)
- Margin upside (cost to cut or price to raise)
- Customer upside (segment to target or churn to reduce)

## Step 4 — Top risks

Identify 3 specific risks for next quarter:
- Revenue risk (concentration, trend, seasonality)
- Margin risk (rising cost, pricing pressure)
- Operational risk (demand gap, vendor dependency)

## Step 5 — QBR narrative

Write a 500–800 word narrative in plain business English with this structure:
1. Quarter headline (one sentence)
2. Revenue story (trend + why)
3. Margin story (trend + why)
4. Customer story (concentration + revenue mix)
5. Three opportunities
6. Three risks
7. One-paragraph call to action for next quarter

## Step 6 — Export

Generate:
1. **`qbr-{YYYY-QN}.pdf`** — formatted narrative + key charts (as ASCII tables if no chart tool available)
2. Save to `--save-to` location

## Connector failures

If QuickBooks is unreachable, stop — the QBR requires QB financial data as the foundation (revenue, margin, and customer concentration all derive from it). If Paywhere is missing, skip cash cross-validation and note "Paywhere not connected — revenue validated from QB only."

## Approval gates

- **Never publish or email the QBR automatically.** Always display for owner review first.
- **Flag if any data source returns incomplete data** — note gaps in the narrative.

## Output

Present the narrative in-line, then confirm export. End with a one-paragraph "what to focus on next quarter" summary.
