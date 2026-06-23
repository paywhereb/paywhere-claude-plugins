# Demo Script — Paywhere MCP (copy/paste run-of-show)

The live demo is driven by **free-text prompts you paste into the chat** (Claude
Cowork), not slash commands — it should feel like a real owner talking to their
finance agent. The one exception is setup, which the presenter runs once.

- **Persona:** Meridian Staffing & Advisory LLC (scaled ~0.30×). Full dataset:
  [`../paywhere-smb/DATASET.md`](../paywhere-smb/DATASET.md).
- **Determinism:** same-week — a rehearsal on Tuesday and the live run on Friday
  produce identical bank history + books (only `W+0` due dates shift, by design).
- **Reset between rehearsals:** just re-run `/demo-setup` (idempotent; orphans
  the prior world). No manual cleanup.

---

## Setup (presenter, once)

```
/demo-setup
```

Approve the gate. **Record the returned bank username/password** (also posted to
the demo Slack channel). Confirm the report shows Operating ≈ $23,000, Reserve
≈ $20,138, recipients configured, enrichment written, and `beatsReady`. If the
books seed reports `errorCount > 0`, re-check the QBO sandbox chart of accounts.

---

## Phase 1 — the everyday squeeze

**1. Balances**
```
Show my account balances
```
→ Operating ≈ $23,000, Reserve ≈ $20,138.

**2. Categorize spending**
```
Categorize my spending over the last few months
```
→ Reads the bank (6 months). Biggest categories: contractor labor, payroll
(Gusto), rent, cloud/SaaS — plus a one-off that stands out (NorthPeak).

**3. Move money**
```
Transfer $10,000 from savings to checking
```
→ A normal internal transfer (approval-gated).

**4. Investigate a charge** (the `get_transaction_detail` beat)
```
I don't recognize the payment to NorthPeak Analytics — can you get me more information?
```
→ The plain bank row shows only `ACH DEBIT NORTHPEAK ANALYTICS — $1,280`.
`get_transaction_detail` reveals the counterparty (220 Kearny St Ste 600, San
Francisco CA), memo ("Data enrichment subscription — annual, billed in arrears,
contract #NP-2231"), category, ref NP-INV-4471, and the note that it auto-renewed
(signed by M. Webb 11 months ago).

**5. Pay the bills due this week** (ACH + Wire, pre-configured recipients)
```
Pay the bills due this week
```
→ Overdue ≈ $1,840 (DigitalOcean $300 ACH, Sutter Hill $560 **wire**, Grant
Henderson $980 ACH) + due-this-week ≈ $910 (AWS $760 + Google Workspace $150,
ACH). One mixed-rail batch via `recipientRef` (no raw bank details), one
approval, Bill Payments booked back to QBO.

**6. Payroll check** (the agent should flag this proactively after beat 5; if
not, prompt it)
```
Am I good for payroll this Friday?
```
→ Operating ≈ $23,000 vs Friday obligations ≈ $23,730 (Gusto $3,600 + contractor
cycle $17,380 + the AP just queued) → a small shortfall (~$730). Collectible AR
= Alderbrook $4,800 + Mitsui's open half $2,100 = **$6,900** comfortably covers
it → the agent's move is "chase Alderbrook." (Hallsten's $2,600 bank credit is
already received but unrecorded in QBO — it must NOT be counted as collectible.)

**Mid-demo "money just landed"** — presenter posts Alderbrook's live deposit,
then re-asks:
```
(presenter, via the seeder)  deposit_to_mock_account → Operating, $4,800,
  statementDescription "ACH CR ALDERBROOK VENTURES"
```
```
Alderbrook just paid — check again
```
→ Operating now clears Friday comfortably.

---

## Phase 2 — the rails

**A. Getting paid** (invoices + stablecoin requests + Gmail **drafts**, never sent)
```
Send out this month's invoices and create stablecoin payment requests for the
clients who pay that way, then draft the emails
```
→ Invoices in QBO + `initiate_stablecoin_receipt` for the stablecoin clients +
**Gmail drafts** (drafts only — nothing is sent).

**B. Pay-and-bill** (hours from QBO time-activities; pre-seeded recipients)
```
Run the pay-and-bill cycle for last week
```
→ Pulls last week's hours from QBO time-activities, bills clients, pays
contractors on their rails (ACH/Wire via `recipientRef`, Devon via stablecoin).
Whole-dollar: Priya 40h@$40, Marcus 36h@$30, Elena 40h@$60 (wire), Devon
32h@$50 (stablecoin); bill = pay × 1.3.

**C. Commissions** (server-side commission map; no spreadsheet)
```
Pay commissions for last week
```
→ Commission map (client → rate → payee → rail): Thames 5% → Jane Doe (ACH),
Alderbrook 5% → Jane Doe (ACH), Zurich 10% → Acme (Wire), Mitsui 10% →
CryptoConsult (Stablecoin). Hallsten earns no commission → the visible
"skipped — not in the commission map" row.

---

## Notes

- Every money-moving step is approval-gated — the agent always shows the batch
  and waits for an explicit yes.
- Phase-2-A produces Gmail **drafts**, never sends.
- If a connector drops mid-demo, re-authorize it; if the bank world looks wrong,
  re-run `/demo-setup` (same-week determinism makes the re-run identical).
