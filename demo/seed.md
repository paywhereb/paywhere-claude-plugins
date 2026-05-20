# Demo Kit — Seeding the Sandbox

The Paywhere SMB plugin is designed to be demonstrable end-to-end without
exposing any real customer data. This document describes how to stand up
the demo environment and what data to seed.

> **No real money. No real customers. Mock-dev only.**
>
> Every connector used in the demo points at a sandbox / test environment.
> No production money movement is initiated by any flow in this demo kit.

---

## Sandboxes you'll need

### 1. QuickBooks Online sandbox company

1. Create a free Intuit Developer account at <https://developer.intuit.com>.
2. From the dashboard, provision a **sandbox company**. Every developer
   account gets two pre-seeded sandbox companies free of charge.
3. Note the QBO OAuth credentials and the sandbox company id; you'll need
   them when authorizing the QuickBooks MCP in the demo session.
4. The official QBO MCP endpoint is:

   ```
   https://ai-inc.quickbooks.intuit.com/v1/mcp
   ```

   (Already wired into `paywhere-smb/.mcp.json` — no changes needed.)

The sandbox arrives pre-seeded with sample customers, vendors, and a
simulated month of transactions. Use that as the baseline.

### 2. Paywhere mock-dev environment

A dedicated Paywhere mock-dev instance pointing at
`http://mock-dev-api.paywhere.com/paywhere-api/v1` (per the `CLAUDE.md`
in the API repo).

Seed it with **one calendar month of transactions** designed to mirror
the QBO sandbox company's deposits and expenses:

- For every QBO bank deposit, post a matching Paywhere credit with the
  same `amount` and a `postDate` within ±1 day. Use realistic
  counterparty strings in `description` (e.g.
  `ACH Acme Corp / INV-3847`).
- For every QBO expense check or bill payment, post a matching Paywhere
  debit.
- Mix `type` values across `ach`, `wire`, `stablecoin`, and `transfer`
  so the close packet shows the full product surface.

Then **deliberately seed two discrepancies** so the close demo has
something to flag:

1. **Missing-in-QB**: a $43.17 interest credit posted to the Paywhere
   operating account with no corresponding QB entry. Realistic
   description: `Interest credit · monthly accrual`.
2. **Fee delta**: a wire that posted at $5,000.00 with a separate
   `type: "fee"` line for $1.20. QB books the wire correctly but
   miscategorizes the fee as a $0.00 line — surfaces as a $1.20 delta in
   reconciliation.

These are the two seeded discrepancies that the demo script highlights
when running `/close-month`.

### 3. Optional: HubSpot demo portal

A free HubSpot developer portal seeded with ~20 contacts and ~10 deals
in mixed pipeline stages. This unlocks `/monday-brief`, `/run-campaign`,
and `/customer-pulse-check`.

### 4. Optional: Gmail / Slack workspaces

A throwaway Gmail account and Slack workspace for `/monday-brief`
delivery and the watch-list section. Not required for the core demo
flows; nice-to-have polish.

---

## Recommended demo dataset

For the canonical demo, seed the QBO sandbox + Paywhere mock-dev as
described above for **April 2026**:

| Date    | Type      | QBO entry                                 | Paywhere line                                                | Match status |
|---------|-----------|-------------------------------------------|--------------------------------------------------------------|--------------|
| Apr 02  | Deposit   | Acme Corp · $8,400 · INV-3847             | ACH credit · $8,400 · "ACH Acme Corp / INV-3847"             | ✓ matched    |
| Apr 04  | Deposit   | BlueSky LLC · $14,200 · INV-3848          | Wire credit · $14,200 · "WIRE FROM BlueSky LLC"              | ✓ matched    |
| Apr 06  | Bill      | AWS · $1,250                              | ACH debit · $1,250 · "ACH AWS Inc"                           | ✓ matched    |
| Apr 09  | Bill      | Office rent · $3,200                      | Wire debit · $3,200 · "WIRE TO Sutter Hill Properties"       | ✓ matched    |
| Apr 11  | —         | (no QB entry)                             | ACH credit · $43.17 · "Interest credit · monthly accrual"    | ⚠ MISSING_IN_QB |
| Apr 14  | Deposit   | Crestwood Inc · $6,000 · INV-3849         | Stablecoin credit · $6,000 · USDC on Polygon                 | ✓ matched    |
| Apr 15  | Bill      | Payroll · $22,000                         | ACH debit · $22,000 · "ACH Gusto Payroll · run 04-15"        | ✓ matched    |
| Apr 18  | Bill      | Vendor wire · $5,000                      | Wire debit · $5,000 · "WIRE TO Larkspur Studios"             | ✓ matched    |
| Apr 18  | Bill      | Bank fees · $0.00 (miscategorized)        | Fee debit · $1.20 · "Wire fee"                               | ⚠ $1.20 DELTA |
| Apr 22  | Deposit   | Crestwood Inc · $6,000 · INV-3850         | ACH credit · $6,000 · "ACH Crestwood Inc / INV-3850"         | ✓ matched    |
| Apr 25  | Pending   | (booked as receivable, not yet cleared)   | Wire pending · $2,400 · "WIRE FROM Greenfield Ventures"      | IN_TRANSIT past expected window — surfaces in `/monday-brief` Risks |
| Apr 28  | Bill      | Software subs · $480                      | ACH debit · $480 · "ACH Notion Labs"                         | ✓ matched    |

The seeded receivables and the April 15 payroll line together produce a
visible "payroll crunch" risk when `/plan-payroll` runs on or before
April 14.

---

## Running the demo

After seeding both sandboxes, install the plugin in Claude Desktop:

```bash
/plugin marketplace add paywhereb/paywhere-claude-plugins
/plugin install paywhere-smb@paywhere-claude-plugins
```

Authorize Paywhere (mock-dev OAuth) and QuickBooks (sandbox company)
through the connector flow. Then run the three demo flows in order:

1. `/plan-payroll` — should flag the April 15 payroll crunch and stage
   reminders for the open invoices (Acme, BlueSky, Crestwood).
2. `/close-month` — closing April 2026. Should produce a close packet
   whose Reconciliation sheet flags exactly two discrepancies: the
   $43.17 interest credit (MISSING_IN_QB) and the $1.20 wire-fee delta.
3. `/monday-brief` — should surface the $2,400 wire from Greenfield
   Ventures as still pending past its same-day clearing window.

These are the three flows recorded for the demo screencast in the
plugin's `README.md`.

---

## Credentials boundaries

- The QBO sandbox is a real QBO company. It holds no real customer data,
  but treat its credentials like any other sandbox: don't commit them.
- The Paywhere mock-dev environment lives behind the same authentication
  boundary as the production Paywhere API but processes no real money
  movement. Never point the demo plugin at production Paywhere.
- HubSpot, Gmail, and Slack should be throwaway sandbox accounts.
