# Nick's HVAC — run-of-show (SCENARIOS.md)

Copy-paste prompts for every beat in blueprint §8, what the presenter should
see (and which answer-key field it comes from), the live injects, the
rehearsal checklist, and what is not in this build. Persona and data:
[`../paywhere-smb/DATASET.md`](../paywhere-smb/DATASET.md). Setup and
troubleshooting: [`presenter-kit.md`](presenter-kit.md). The blueprint is
`paywhere-mcp/docs/plans/nicks-hvac-demo-blueprint.md`.

**How to read the answer key.** `/demo-setup` prints `answerKeySummary`; its
paths are the `AnswerKey` shape in
`paywhere-mcp-api/src/demo/world/types.ts`, and the full key for a demo date
is `paywhere-mcp-api/src/demo/world/fixtures/answer-key-<today>.json`
(`answer-key-2026-09-02.json` for the September 2026 run). Every "you should
see" below names the path. Numbers roll with the date model, so read them
from the setup report or the fixture, not from this file. The **fixed**
figures — agreement amounts and the staged live-surface amounts: Westport
**$7,200** overdue, Trane **$11,400** to hold, bills due this week Johnstone
**$6,850** / Voltage **$2,150** / Ironclad **$1,900**, the St. Anselm **$520**
agreement check **#4471**, the Angi **$349** debit — are in DATASET.md. Every
other figure in this file is marked ≈ and is the September 2026 value.

**Voice.** Acts 1–3 are the owner talking to their finance agent in Claude
Cowork. Only `/demo-setup` and the injects are presenter commands. Every
money beat ends the same way: a `/confirm/<id>/<nonce>` link, opened on the
bank, approved with a passkey. Say once, early: *"Nothing moves from chat.
The bank's page is where the approval happens."*

---

## Act 0 — Setup (presenter, before the meeting)

1. In Cowork, create a project for the demo and paste
   [`cowork-project-prompt.md`](cowork-project-prompt.md) into its
   instructions (persona, answer style, money-movement rules, tool-field
   hygiene — the steer the skills deliberately do not carry).
2. Connect the four connectors in that project — Paywhere
   (`demo.dev.paywhere.com/mcp`), quickbooks, Gmail and Google Calendar —
   signed in as **demo-nick@paywhere.com** for the Google pair
   ([`presenter-kit.md`](presenter-kit.md) §1).
3. Side-load `dist/paywhere-smb-1.0.5.plugin` (presenter-kit §2).
4. Then, in the project:

```
/demo-setup
```
(optional: `/demo-setup username: brett`)

Approve the gate. The seed is **asynchronous**: the skill polls
`get_demo_world` for ≈ 4–6 minutes and shows progress. Then it reads the
world back through the connector and reports. Record the **bank
username/password** (also posted to the demo Slack channel).

You should see, from the report:

| Report line | Answer-key path |
|---|---|
| Operating / Tax Reserve / Business Savings balances (read back == `expectedClosing`) | `balances.operating`, `balances.taxReserve`, `balances.savings` |
| True available cash and its formula | `trueAvailable.amount`, `trueAvailable.formula` |
| Reserve balance, collected-not-remitted, **shortfall**, missed Fridays, next remittance | `tax.reserveBalance`, `tax.collectedNotRemitted.total`, `tax.shortfall`, `tax.missedSweeps`, `tax.nextRemittance` |
| Largest overdue invoice; the received-but-unbooked check | `ar.largestOverdue`, `ar.unbookedReceipt` |
| Bills due this week with rails; hold candidates | `ap.dueThisWeek`, `ap.holdCandidates` |
| Friday payroll date, estimate, headroom | `payroll.nextPayDate`, `payroll.estimatedTotal`, `payroll.headroomAfterPayroll` |
| Subscriptions monthly total | `subscriptions.monthlyTotal` |
| Readback ✓ ×4: balances, payees (count + wire/ACH spot-check), enrichment, unbooked check | — |
| `dateModelSource: "provided"` | — |

If `get_demo_dates` says `seeded: false`, the books have not reseeded yet —
wait or ping the QBO demo owner; do not demo on unaligned dates.

Optional: pick the prospect's brand at `/poc-admin`.

**Pre-run Act 3** now (see Act 3) so the brief, the sweep file and their
staged proposals exist before the room fills.

---

## Act 1 — The assistant (interactive, in Cowork)

Bank-only fact in **bold** — say it out loud; it is the reason the FI is
buying the connector.

### 1.0 Warm-up — bare connector, no plugin (claude.ai or Claude Desktop)

Add only the Paywhere custom connector (`https://demo.dev.paywhere.com/mcp`),
sign in as the demo bank user. Paste, one at a time:

```
What's my balance?
```
```
What have I spent at Johnstone this year?
```
```
Pay Voltage Electric $2,150 by ACH
```

You should see: three accounts; a 12-month spend figure for the parts
supplier from descriptor search; the saved payee resolving **by name**, a
staged proposal and a `/confirm` link — open it, approve with the passkey.
**The connector stands alone before skills add judgment.** FI seat:
Connections + Money Movement show the session and the batch.

### 1.1 — Pulse
```
How is my business doing?
```
You should see: three balances; **true available cash = Operating − reserve
shortfall − pending** (`trueAvailable`); 12 months of money in vs out with
best/worst months (`strongestMonths`, `weakestMonths`); the #1 issue — the
largest overdue invoice from a routinely-late customer (`ar.largestOverdue`,
`ar.chaseOrder[0]`; note `liveSurface.overdueInvoices` is sorted by days
late, so its `[0]` is a smaller, older invoice) and/or the equipment bill
about to be paid early (`liveSurface.earlyPayTemptation`). FI:
`cash_flow_management` intent.

### 1.2 — Profit to cash
```
QuickBooks says I made about $14k in August. Why doesn't my bank balance move with my profit?
```
(Swap in the last complete month and `cashBridge.netIncome` rounded — the
prompt is deliberately neutral about direction: for a September demo August
cash rose by **more** than profit because the summer receivables were
collected; in a slow month it falls while profitable. The skill answers
either way.) You should see the bridge: `cashBridge.netIncome` → `deltaAR`
(negative in September = prior months' invoices collected), `distributions`
($9k quarterly, Aug 25), `ownerTaxes`, `taxSweepsToReserve`,
`equipmentAndStocking`, `earlyVendorPayments` → `operatingCashChange`, with
the top drivers named (`cashBridge.drivers`) and the line "that cash was
earned in June–July; it swings back when invoicing rises". **What actually
cleared and when.**

### 1.3 — Who owes me
```
Who owes me money and who do I call first?
```
You should see: aging (`ar.aging`), behavior profiles derived from 12 months
of payment lags (`ar.latePayers`), DSO and direction (`ar.dso`), a chase
order ranked by cash impact × lateness (`ar.chaseOrder`), two Gmail
**drafts** (never sent), and one customer **excluded** because their check was
deposited this week but not yet applied in the books
(`ar.unbookedReceipt`; **received-but-unbooked credit**). FI:
`accounts_receivable`.

### 1.4 — Due this week / paying early → one batch
```
What's due this week, and am I paying anyone early?
```
You should see: bills due within 7 days with rails (`ap.dueThisWeek` — the
three staged bills plus any generated bill that falls due in the window, a
smaller Trane bill in September), the equipment bill **held** to its due
date with the vendor's early-payment history in days and dollars
(`ap.holdCandidates[0]` = Trane $11,400, `ap.earlyPaymentPattern`).
Then:
```
Pay the bills due this week
```
You should see: ONE batch — ACH lines and a wire line — paid by payee name,
a `/confirm` link with its title. Open it on the bank, approve with the
passkey. **One approval, on the bank's surface.** FI: Money Movement shows
the batch awaiting → approved.

### 1.5 — Payroll
```
Am I good for payroll Friday?
```
You should see: the equation (available − reserve shortfall − obligations
through Friday + 7 days) with the payroll date and estimate from the bank's
processor debits (`payroll.nextPayDate`, `payroll.estimatedTotal` ≈ $11.1k,
`payroll.headroomAfterPayroll`); if tight,
"collect X" ranked first, never "raid the reserve". **Live posting** — now
inject (below) and paste:
```
Westport just paid — check again
```
You should see the headroom move by exactly the injected amount.

### 1.6 — How much is really mine
```
How much of my balance is actually mine?
```
You should see: sales tax collected on **received** payments since the last
remittance, by state (`tax.collectedNotRemitted`), the Tax Reserve balance
(`tax.reserveBalance`), the **shortfall** (`tax.shortfall`, ≈ $2.8k in
September), the missed Fridays (`tax.missedSweeps` — the last two are this
month's; the three Oct–Nov ones are the history), the 20th
(`tax.nextRemittance`), and a proposed
catch-up transfer Operating → Tax Reserve staged as a batch **transfer**
line with a `/confirm` link. **The reserve balance is a bank fact.** FI:
`tax_compliance`.

### 1.7 — The odd debit / subscriptions
```
What's this $349 'ANGI LEADS' debit?
```
```
What subscriptions am I paying?
```
You should see: the row, its enrichment, the vendor, the renewal email, months
seen (`liveSurface.unknownRecurringDebit`); then the recurring-debit table
from 12 months of descriptors with flags — zero attribution, orphaned,
duplicate seat — and the monthly total (`subscriptions.items`,
`subscriptions.monthlyTotal`). **12 months of descriptors.** FI:
`spend_analysis`.

### 1.8 — The van → what to bring the bank (the #1 beat)

Paste exactly this first — a plain yes/no with an amount and a time. It must
route to `big-purchase-decision`, and the first two sentences of the reply
must be the verdict:
```
Can I afford to buy a van this week for $58,500?
```
You should see, up front: **"Not in cash this week — yes, financed."** A
$58,500 cash purchase drops the 13-week minimum to
`van.cashPurchaseMinBalanceAfter` (`forecast13w.minBalance.amount` − 58,500,
≈ $11k in September), below the payroll-plus-bills cushion, with the Tax
Reserve and Business Savings excluded from spendable cash; financed at the
term sheet's terms it fits (`van.recommendation`). Then the support: the
quote, term sheet and insurance quote from Gmail and the dealer appointment
from Calendar; historical lows and their causes (`lows[]` — the Jan–Feb
collision is the year's minimum at $14,000); the monthly payment
(`van.financing.monthlyPayment` = $989.22) net of insurance, fuel and the
mileage offset (`van.netMonthlyCashImpact`). **Historical minimums,
seasonality of cash.** Follow-ups, one at a time:
```
Cash or finance?
```
```
When is the safest month?
```
→ `van.safestPurchaseMonths` / `van.riskyMonths` (Aug/Mar/Jun vs Jan/Jul/Dec
in September), each risky month with its collision named.
```
What about a second van before next summer?
```
→ `van.secondVanVerdict`: defer unless collections improve, Trane/Ferguson
are paid on due date, or the bank extends a line of credit — each quantified
from `whatIf[]`.
```
What should I bring to the bank?
```
→ `credit-readiness`: working-capital gap, months short, LOC and card sizing,
and the package written to the working folder
(`bank/credit-readiness-<date>.pdf` + `.xlsx`).

**FI seat (paywhere-admin → Intents):** with the project prompt in place,
the `intent` on every call in this beat is Nick's question in his own words
("decide whether to finance a $58,500 van or pay cash"), so the Intents
screen shows **`financing_debt` rising** during the beat — the CRO's warm
loan lead. If it stays flat, the calls did not carry the financing words:
the skills no longer word that field, so check the Cowork project's
instructions are [`cowork-project-prompt.md`](cowork-project-prompt.md)
(§Tool fields).

### 1.9 — What-ifs
```
What if revenue drops 10%? What if Westport pays 30 days late? What if I hire a tech? What if I stop paying vendors early?
```
You should see: a lever table over the 13-week forecast with Δ minimum
balance per lever and the best combination (`whatIf[]` — seven levers
including "Van financed", each with `deltaMinBalance13w`;
`forecast13w.minBalance`).

---

## Act 2 — The application (on-demand)

### 2.1
```
Build me a cash dashboard I can open every morning
```
→ `dashboard/cash.html` in the working folder: three balances, true
available, 13-week chart, AR aging, next-30-days obligations, tax-reserve
gauge, subscriptions. Open it. Say: *a file can't call the bank; the 7:30
brief regenerates it every weekday.*

### 2.2
```
Build a 13-week cash model in Excel I can play with
```
→ `models/cash-13w.xlsx`; change a lever cell (collections speed, pay-on-due,
revenue %, hire, van, LOC) and watch the minimum-balance cell move.

### 2.3 (optional)
```
Build a collections tracker
```
→ `tracking/collections.xlsx` with profiles, promises, next actions.

---

## Act 3 — The agent (Cowork scheduled tasks)

Pre-run both before the meeting so outputs and staged proposals exist. In the
room: show the schedule, open the output file, open the `/confirm` link,
approve.

### 3.1 — Daily cash brief

Cowork → Scheduled tasks → new task:

- **Schedule:** `Every weekday at 7:30am`
- **Prompt:** `Run my morning cash brief`

Run it once now. You should see `briefs/<today>.md`: balances, true
available, today's calendar obligations, exceptions (overdue with no credit,
due bills, held bills, reserve shortfall, pending, unknown debit,
unreconciled settlements), the regenerated `dashboard/cash.html`, and ONE
staged batch — reserve top-up transfer + due bills — with the `/confirm`
link and *"Nothing has moved until you approve this on the bank's page."*
FI: Intents shows `sessionType: scheduled`; Money Movement shows an
agent-staged batch awaiting a human.

### 3.5 — Friday tax sweep

- **Schedule:** `Every Friday at 4:00pm`
- **Prompt:** `Run the Friday tax sweep`

You should see `sweeps/<date>.md`: this week's received payments matched to
bank credits, the sales tax on them by state, and the staged Operating → Tax
Reserve **transfer** with the `/confirm` link (`tax.lastSweep` after
approval). This is Nick's manual Friday habit, automated and still approved
by him.

> **Presenter note.** The demo bank posts nothing after the most recent
> Sunday, so on any weekday "this week's received payments" is empty and the
> sweep is a correct but dull **$0**. Before this beat, run `/demo-inject`
> ("simulate Westport paying") so a payment lands this week; the sweep then
> has real tax to stage. The first live eval confirmed the $0 path behaves.

### Not scheduled in this build (see "Not in this build")

3.2 `ar-chase-agent` (Mon 8am), 3.3 `tax-remittance-agent` (18th), 3.4
`settlement-reconcile-agent` (nightly). Their interactive equivalents exist:
`invoice-chase`, `tax-reserve-check`, `month-end-prep`.

---

## Act 4 — The FI seat (paywhere-admin)

Walk, in order:

1. **Intents** — category mix over the session: `cash_flow_management`,
   `accounts_receivable`, `tax_compliance`, `spend_analysis`, and the
   **`financing_debt` spike from 1.8** (the classifier keys on loan / lease /
   financ- / line of credit / debt in the `intent` text — the van beat's
   calls carry those words). Filter `sessionType: scheduled` to show the
   3.1/3.5 runs.
2. **Connections** — the demo owner's consent grant to Claude; the bare
   connector session from 1.0.
3. **Money Movement** — the batches from 1.0, 1.4, 1.6, 3.1, 3.5: staged →
   approved (passkey) → executed; the transfer lines alongside vendor lines.
4. Fraud Review is left out this round (D11).

Talking point: the bank sees aggregates and money movement, never
conversation text. The screens' background is the generic multi-business
snapshot; Nick's HVAC is one business in it, and everything just done is
appended live.

---

## Live injects (presenter, via `demo-inject`)

Presenter-voice prompts (they call the demo-seeder tools on the Paywhere
connector; the skill resolves the Operating account and reads amounts from
the live answer key). Injects are permanent for this world — re-run
`/demo-setup` before the real demo if you inject in rehearsal.

**Westport just paid** (use in 1.5):
```
Inject a deposit: simulate Westport paying its largest overdue invoice — post an ACH credit to Operating with the customer's AP descriptor.
```
Then, owner voice: `Westport just paid — check again`. Effect:
`ar.largestOverdue` clears; `trueAvailable` and payroll headroom rise by the
amount.

**Emergency call invoice** (cash side only — the books are read-only):
```
Inject a deposit: an emergency-call card settlement landed today — post a merchant settlement deposit to Operating for the emergency job amount.
```
Owner voice: `Anything new land today?`

**Blue Line autopay failed**:
```
Inject a withdrawal: Blue Line's card autopay failed — reverse the agreement amount from Operating with a merchant return descriptor.
```
Owner voice: `Did Blue Line's payment go through?`

Pending card authorizations cannot be injected (posted rows only).

---

## Rehearsal checklist

- [ ] Cowork project created; `cowork-project-prompt.md` pasted as its instructions; plugin 1.0.5 side-loaded.
- [ ] `/demo-setup` completed; readback ✓ ×4; credentials recorded; `dateModelSource: "provided"`.
- [ ] Gmail (`demo-nick@paywhere.com`) and Calendar connected in Cowork; the Google seed ran this week (`seed-google.mjs --check`).
- [ ] Bare-connector session (1.0) signed in on a second window with the same bank user.
- [ ] Passkey enrolled for the demo bank user on the `/confirm` page (or TOTP ready).
- [ ] Act 3 pre-run: `briefs/<today>.md`, `sweeps/<last Friday>.md`, `dashboard/cash.html` exist; their `/confirm` links open.
- [ ] Act 2 files opened once (dashboard renders offline; xlsx lever cells recalc).
- [ ] paywhere-admin open on Intents with the demo business filter.
- [ ] Never-send safeguards in place (presenter-kit.md): Gmail send/reply/forward denied in the client; outbound restricted on the mailbox.
- [ ] Every Act 1 prompt pasted once this week; the router picked the intended skill (dispatch is not covered by the eval).
- [ ] 1.8 specifically: "Can I afford to buy a van this week for $58,500?" reached `big-purchase-decision`, the verdict was in the first two sentences, and Intents showed `financing_debt` move.
- [ ] 1.2 wording updated to last month's `cashBridge.netIncome`; the reply bridged the real direction.
- [ ] Inject prompts tested once, then `/demo-setup` re-run.
- [ ] Say-out-loud lines rehearsed: the bank-only fact per beat; "nothing moves from chat".

---

## Not in this build (deferred, blueprint §10.1 order)

| Item | Why deferred | Interim |
|---|---|---|
| `settlement-reconcile-agent` (3.4 nightly) | time | `month-end-prep` / `close-month` do gross-to-net matching, unposted fees, unrecorded card purchases interactively |
| `ar-chase-agent` (3.2 Mon 8am) | time | `invoice-chase` interactively; the drafts-only rule is the same |
| `referral-fees` skill (partner → rule → trigger-on-collection) | time | `quarterly-review` names referral sources and fee bills; no owed-vs-not-yet-payable computation |
| `tax-remittance-agent` (3.3 18th) | time | `tax-reserve-check` reports the 20th's amounts by state; remittance staging can be asked for interactively |
| Pre-warmed world pool (instant `/demo-setup`) | server | async seed, ≈ 4–6 min |
| `query_transactions groupBy: counterparty` | server | skills categorize from a bounded 12-month pull by descriptor stem |
| Fraud beat | D11 | — |
| Eval cases beyond the first 8–10 | time | rehearsal checklist |
