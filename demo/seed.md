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

### 1. QuickBooks (hosted Paywhere fork)

The plugin points QuickBooks at the **hosted Paywhere QBO fork**, not the
official Intuit MCP:

```
https://qbo-demo.paywhere.com/mcp
```

(Already wired into `paywhere-smb/.mcp.json` — no changes needed.) The
fork wraps a QBO sandbox company and adds the tools the commission flow
relies on (`search_payments`, `search_bills` with DocNumber/PrivateNote
`LIKE`, `create_bill`/`create_bill_payment`, `create_vendor`). It arrives
pre-seeded with sample customers, vendors, and a simulated month of
transactions — use that as the baseline.

### 2. Paywhere hosted demo environment

The plugin points Paywhere at the **hosted demo MCP**:

```
https://demo.paywhere.com/mcp
```

(Already wired into `paywhere-smb/.mcp.json`.)

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

### 3. Google Drive (commission register)

`/pay-commissions` reads a **commission register** Google Sheet as its
source of truth, and `/commission-setup` creates it. Connect a Google
Drive account so the Sheet can be created and read. No manual seeding
needed — run `/commission-setup`, which builds the
`Paywhere Commission Register` Sheet (tabs `Customers` / `ACH` / `Wire` /
`Stablecoin` / `PaidLog`), creates the matching QBO payee vendors and
historical payments, and registers + verifies the Paywhere stablecoin
recipient. It is idempotent (search-before-create), so re-running is safe.

> **Commission incoming-credit dependency (ENG-332).** `/pay-commissions`
> matches Paywhere bank *credits* to QBO customer payments. Seeding mock
> incoming credits in the hosted Paywhere demo env requires the ENG-332
> seeding MCP, which does not exist yet. Until it ships, `/commission-setup`
> seeds the QBO Payments to mirror whatever credits already exist in the
> demo bank account; if the window has no credits, the match step lists the
> QBO payments as unmatched. The confirmation gate, dedupe, and stablecoin
> preview all still demo regardless.

### 4. Optional: Gmail account

A throwaway Gmail account for invoice-reminder and payroll mail drafts
(`/plan-payroll`, `invoice-chase`) and the `business-pulse` watch-list.
Not required for the core demo flows; nice-to-have polish.

---

## Example demo scenario

> **One illustrative scenario — your seeded values will differ.** The skills
> read live data and assume no specific records; the table below is just a
> concrete dataset you *can* seed so the flows have something to surface. Swap
> in whatever scenario you want to demo.

Seeded for **April 2026**:

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
| Apr 25  | Pending   | (booked as receivable, not yet cleared)   | Wire pending · $2,400 · "WIRE FROM Greenfield Ventures"      | IN_TRANSIT past expected window — surfaces in `business-pulse` Risks |
| Apr 28  | Bill      | Software subs · $480                      | ACH debit · $480 · "ACH Notion Labs"                         | ✓ matched    |

The seeded receivables and the April 15 payroll line together produce a
visible "payroll crunch" risk when `/plan-payroll` runs on or before
April 14.

---

## Running the demo

After seeding both sandboxes, install the plugin in either
**Claude Code** or **Cowork** — those are the two clients that run
the packaged skills and slash commands. Claude Desktop and claude.ai
chat do not.

**Claude Code:**

```
/plugin marketplace add paywhereb/paywhere-claude-plugins
/plugin install paywhere-smb@paywhere-claude-plugins
```

**Cowork:** build the `.plugin` archive with `./scripts/package.sh`
(in the repo root) and side-load it via Cowork's plugin file picker.
See [`paywhere-smb/README.md`](../paywhere-smb/README.md#installation)
for full instructions.

Authorize Paywhere (hosted demo OAuth) and QuickBooks (hosted fork)
through the connector flow. Then run the flows in order. **With the example
scenario above**, you'd see:

1. `/plan-payroll` — flags the April 15 payroll crunch and stages
   reminders for the open invoices (Acme, BlueSky, Crestwood).
2. `/close-month` — closing April 2026. Produces a close packet whose
   Reconciliation sheet flags the two seeded discrepancies: the $43.17
   interest credit (MISSING_IN_QB) and the $1.20 wire-fee delta.
3. `business-pulse` ("Monday brief" / "weekly check-in") — surfaces the
   $2,400 wire from Greenfield Ventures as still pending past its
   same-day clearing window.
4. `/commission-setup` then `/pay-commissions "last week"` — seeds the
   register + QBO vendors/history + verified stablecoin recipient, then
   matches payments, shows the commission table, gates on approval,
   disburses across ACH / Wire / Stablecoin (stablecoin in preview to
   surface the 1% fee), and books a marker Bill + Bill Payment. A second
   `/pay-commissions` run reports everything "already paid" (dedupe proof
   from both the QBO DocNumber and the register's PaidLog).

These are the flows recorded for the demo screencast in the plugin's
`README.md`.

---

## Credentials boundaries

- The QBO fork wraps a real QBO sandbox company. It holds no real customer
  data, but treat its credentials like any other sandbox: don't commit them.
- The Paywhere hosted demo environment lives behind the same authentication
  boundary as the production Paywhere API but processes no real money
  movement. Never point the demo plugin at production Paywhere.
- Gmail and Google Drive should be throwaway sandbox accounts.
