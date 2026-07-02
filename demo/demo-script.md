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
≈ $20,138, open AR $9,500, **open AP $3,950** (= $2,750 due-this-week bills + the
$1,200 NorthPeak reconciliation item, which beat 3 resolves — see DATASET.md),
recipients configured, enrichment written, **stablecoin counterparties approved**
(2 recipients — Devon, CryptoConsult; 2 senders — Thames, Mitsui — so the
Phase-2 stablecoin beats are KYC-ready), and `beatsReady`. If the books seed
reports `errorCount > 0`, re-check the QBO sandbox chart of accounts.

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

**3. Investigate + reconcile a charge** (the `get_transaction_detail` → Gmail → write-back beat)
```
There's an ACH debit for $1,280 I don't recognize — the statement just says
"NPA*ENRICH 8002231". What is it?
```
→ The plain bank row shows only `ACH DEBIT NPA*ENRICH 8002231 — $1,280` (a
payment-processor passthrough, not a vendor name). `get_transaction_detail` adds
**one breadcrumb and nothing more** — an invoice reference, `NP-INV-4471`. That's
the thread to pull: the agent **searches Gmail for that invoice** and finds it —
**NorthPeak Analytics LLC**, "Data enrichment subscription — annual, billed in
arrears (contract #NP-2231)"; auto-renewed (signed by M. Webb ~11 months ago)
**at a higher rate, $1,200 → $1,280**.

**Why it's not recognized (say this out loud — it's the "aha"):** the bank feed
hands you a cryptic descriptor and an amount, never *who* or *why*:

- **The descriptor is opaque.** `NPA*ENRICH 8002231` is a processor passthrough —
  it doesn't even name the vendor (the `8002231` echoes contract NP-2231).
- **It's annual, not monthly**, so it doesn't register as a familiar line.
- **Someone else set it up** (M. Webb, ~11 months ago) and it **auto-renewed
  silently** — at a new, higher price.

**Then the reconciliation (the agentic payoff):**
```
Does this match my books? Fix it if not.
```
→ The agent finds QBO bill `PWD-BILL-0601` for NorthPeak is still **open at the
old $1,200**, while the bank actually paid **$1,280** — the payment never matched
(wrong amount + unrecognizable descriptor), so QBO left the bill unpaid. It
proposes the correction — **update the bill to $1,280 and record the bill payment
against this charge** — and, on approval, writes it back to QuickBooks
(`update_bill` + `create_bill_payment`). The $80 gap is the silent auto-renew
price increase; the invoice (found in Gmail) is the evidence. The bill is
dated out of the beat-4 window, so it never shows up in "pay bills due this week"
— it's resolved here. (Frame it: *"Your books still think this is $1,200 and
unpaid; your bank shows $1,280 actually went out. Want me to correct the bill and
match the payment?"*)

**4. Pay the bills due this week** (ACH + Wire, paid by name)
```
Pay the bills due this week
```
→ Overdue ≈ $1,840 (DigitalOcean $300 ACH, Sutter Hill $560 **wire**, Grant
Henderson $980 ACH) + due-this-week ≈ $910 (AWS $760 + Google Workspace $150,
ACH). One mixed-rail batch paid by payee name (no raw bank details), one
approval, Bill Payments booked back to QBO.

**5. Payroll check** (the agent should flag this proactively after beat 4; if
not, prompt it)
```
Am I good for payroll this Friday?
```
→ Operating ≈ $20,250 (the beat-4 bills have cleared) vs Friday obligations ≈
$20,980 (Gusto $3,600 + contractor cycle $17,380) → a small shortfall (~$730).
Collectible AR
= Alderbrook $4,800 + Mitsui's open half $2,100 = **$6,900** comfortably covers
it → the agent's move is **"chase Alderbrook," not raid the Reserve** (the Reserve
is runway, not a payroll backstop). (Hallsten's $2,600 bank credit is already
received but unrecorded in QBO — it must NOT be counted as collectible.)

**Mid-demo "money just landed"** — the presenter posts Alderbrook's live deposit.
This is **triggered from the chat via MCP, not a script**: paste the prompt below
(it calls `deposit_to_mock_account` on the **Demo Seeder / paywhere-mock**
connector; it posts immediately, so the next balance check sees it). Copy/paste:
```
Using the Demo Seeder, post a $4,800 deposit into my Operating Checking with statement description "ACH CR ALDERBROOK VENTURES" — simulating Alderbrook's incoming payment.
```
Then, back in the owner's voice:
```
Alderbrook just paid — check again
```
→ Operating now clears Friday comfortably. (The agent resolves the Operating
account number itself; both connectors must be on the same bank user — see Notes.)

**6. Move money** (the closer — now that payroll is secured)
```
Now that payroll's covered, move $3,000 into savings to set some of the cushion aside
```
→ A normal internal transfer (approval-gated), **checking → savings**. After
Alderbrook, Operating is ≈ $25,050; moving $3,000 to the Reserve leaves ≈ $22,050
— still clearing Friday's ≈ $20,980 payroll run. This is deliberately AFTER the
payroll beat: a savings→checking transfer earlier would erase the beat-5 shortfall.
Moving money INTO the Reserve here lands the lesson — the Reserve is where surplus
goes once you're covered, not a backstop you raid for an operating gap.

---

## Phase 2 — the rails

**A. Getting paid** (invoices + stablecoin requests + Gmail **drafts**, never sent)
```
Send out this month's invoices and create stablecoin payment requests for the
clients who pay that way, then draft the emails
```
→ Invoices in QBO + `initiate_stablecoin_receipt` for the stablecoin clients
(Thames, Mitsui — their wallets were registered + approved as stablecoin senders
at setup; Zurich still pays by wire) + **Gmail drafts** (drafts only — nothing is sent).

**B. Pay-and-bill** (hours from QBO time-activities; saved payees)
```
Run the pay-and-bill cycle for last week
```
→ Pulls last week's hours from QBO time-activities, bills clients, pays
contractors on their rails (ACH/Wire by the worker's name, Devon via stablecoin).
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

- **The `Paywhere` and `paywhere-mock` connectors MUST be signed in as the same
  bank user (same resolved user ID).** They are separate connectors with separate
  tokens, but the bank world *and* the `get_transaction_detail` enrichment are
  keyed by the resolved user ID (set by the bank-login username), not by the
  token. If they are signed in as different users, `/demo-setup` builds a world
  the `Paywhere` connector can't see — balances read the wrong world and NorthPeak
  comes back with `detail: null`. Always sign **both** connectors in as the same
  user, and if you re-authorize one, re-authorize the other and re-run
  `/demo-setup`. (The skill's step-5 readback now checks for this.)
- Every money-moving step is approval-gated — the agent always shows the batch
  and waits for an explicit yes.
- Phase-2-A produces Gmail **drafts**, never sends.
- If a connector drops mid-demo, re-authorize it; if the bank world looks wrong,
  re-run `/demo-setup` (same-week determinism makes the re-run identical).
