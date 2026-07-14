---
name: plan-payroll
version: 0.2.1
description: >
  Answers "am I good for payroll?" two ways. With Paywhere connected (the
  closed loop): real-time account balances, obligations through the payroll
  date, settlement detection that matches recent bank credits to open
  QuickBooks invoices — so it never chases a customer whose money already
  landed — an exact headroom/shortfall equation, ranked recovery options
  (collect named invoices, reserve transfer, delay discretionary AP), Gmail
  reminder drafts, and a cheap "check again" re-run. Without Paywhere
  (QuickBooks-only): falls back to the cash-flow-snapshot + invoice-chase
  forecast pipeline with confidence bands, clearly labeled as an estimate.
  Use when the owner says "can I make payroll," "am I good for payroll,"
  "will payroll clear Friday," or "cash is tight." Accepts optional horizon
  and payroll-date arguments.
---

# Plan Payroll

## Quick start

```
User: "am I good for payroll?"
→ Probe connectors: Paywhere live? → Mode A (closed loop). Not live? → Mode B (forecast).
Mode A:
→ list_accounts + get_account_balance → real-time position (operating vs reserve)
→ QBO bills/AP due by the payroll date + confirmed payroll amounts → obligations
→ query_transactions (recent credits) × open invoices → settlement detection
→ Verdict: available − obligations = headroom or shortfall (equation shown)
→ If short: ranked recovery options; reminder DRAFTS for named short-payers only
→ "check again" any time → re-pull balance + credits, report what changed
```

The same question, two mechanisms. **Mode A** is grounded in the bank — a live
verdict. **Mode B** is a model — a forecast with confidence bands. Always tell
the owner which one they're getting and why.

## Arguments

- `--horizon` (default `30`) — forecast window in days (30, 60, or 90); used
  by Mode B and by Mode A's "what's coming after payroll" context.
- `--payroll-date` (default: the nearest Friday **strictly after** today — on
  a Friday, that means next Friday) — the date payroll must clear. Resolve
  from today's actual date; never reuse a date from a prior session.

## Mode selection

Probe Paywhere with `list_accounts`:
- **Responds** → Mode A. QuickBooks is still required for obligations and open
  AR; if QuickBooks is down, degrade further (see Edge cases).
- **Missing/unreachable** → Mode B, and say plainly what the owner is missing
  without the bank: **no real-time balance** (book balance only), **no
  settlement detection** (the forecast may tell them to chase a customer who
  already paid this morning), and **confidence bands instead of a live
  verdict**. Offer to re-run once Paywhere is connected.

**Progress tracking:** once the mode is decided, call `TaskCreate` once per
sub-step in that mode's section below (subject = the sub-step's name, e.g.
"A1. Real-time position" or "B1. Cash forecast") before starting the first
one, then `TaskUpdate` it to `in_progress` when you begin that sub-step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly. Don't create
tasks for the mode you did NOT enter.

## Mode A — Paywhere connected (the closed loop)

### A1. Real-time position

- `list_accounts` → identify the operating account(s) vs reserve/savings by
  `accountType`, `accountName`, and `isPrimary`. Never hardcode account
  numbers.
- `get_account_balance` per account. Payroll is funded from operating;
  reserve is reported separately as backstop capacity, **not** counted as
  available (the owner decides whether to dip into it — see A4).
- More than one plausible operating account → ask which funds payroll; don't
  guess (see Edge cases).

### A2. Obligations due by the payroll date

Assemble everything that must clear on or before `--payroll-date`, and state
every assumption:

- **Payroll runs**: `search_bills` for the payroll processor's open/recurring
  bills; corroborate the cadence and amount from bank history
  (`query_transactions` with `direction: "debit"`,
  `descriptionContains: "<processor name>"` over the last ~2 months).
- **AP**: `get_aged_payables` plus `search_bills` for open bills due on or
  before **the payroll date + 7 days** (the default window). Include
  everything overdue. Rationale: cash leaving in this week's run must also
  fund the bills landing in the immediate post-payroll week, or the verdict
  flips the day after payroll clears. The owner can narrow the window to
  "through payroll date" — state the window edge explicitly either way and
  keep it consistent through the run (the demo crunch scenario's small
  shortfall is calibrated to the default payroll+7 window: Operating closes
  ≈ $23,000 against Friday obligations of ≈ $23,730 — Gusto $3,600 + the
  contractor cycle $17,380 + overdue AP $1,840 + due-this-week AP $910).
- **Obligations not in QBO**: ask the owner — contractor payout cycles, owner
  draws, anything booked nowhere yet. Include confirmed amounts as
  owner-stated lines.

Render the obligations as an itemized table and have the owner confirm it
before computing the verdict. The verdict is only as honest as this list.

### A3. Settlement detection — the headline

A customer whose money already **landed** is collected, even if QuickBooks
hasn't recorded the payment yet. **Never chase a customer who paid this
morning.**

1. Open AR: `get_aged_receivables` + `search_invoices` for open invoices
   (customer, DocNumber, open balance, due date).
2. Recent settled credits:
   `query_transactions {direction: "credit", dateFrom: <at least 14 days
   back — at minimum back through the Monday of the LAST COMPLETE week, so a
   payment that landed early last week is never missed>, dateTo: <today>,
   status: ["posted"]}`. If `truncated: true`, narrow the date range and
   re-query in slices rather than shrinking the lookback.
3. **Discard credits QuickBooks already recorded** before classifying
   anything: `search_payments` over the same window and drop every bank
   credit that matches a recorded payment on amount + date (±2 business
   days) + customer. A recorded partial payment (Mitsui-style) is already
   reflected in the invoice's open balance — its credit must NOT be matched
   again or the remainder would be wrongly crossed out as settled. Only
   UNRECORDED credits continue to the next step.
4. Match each remaining credit to an open invoice on **amount +
   counterparty**: amount against the invoice's open balance first, then
   confirm the counterparty with
   `descriptionContains: "<customer name fragment>"` (it searches both
   description and statementDescription, case-insensitive). A credit matching
   two open invoices → ask, don't guess.
5. **Partial payments**: an unrecorded credit smaller than the invoice
   marks only the **received amount** as collected; the remainder stays
   open AR.
6. **The phantom**: an UNRECORDED bank credit whose QBO invoice is still open =
   received-but-unrecorded. Cross it out of collectible AR **and do not add
   it to incoming cash** — it is already inside the balance from A1 (never
   double-count). Offer to record the QBO payment (`create_payment`) — gated,
   only with explicit approval. (In the demo world this is Hallsten & Berg's
   $2,600 credit — landed in the bank, never recorded in QBO — so it must be
   **excluded** from collectible AR even though its invoice still shows open.)

Output of this step: open AR split into **already landed** (crossed out, with
the bank transaction id + postDate as evidence) vs **genuinely outstanding**
(named, with amounts).

### A4. Verdict + shortfall projection

Show the equation with every term — never just the conclusion:

```
Available now (operating, settled)          $A     ← A1; landed credits are already inside
− Obligations due by <payroll date>         $B     ← A2, itemized and confirmed
= Headroom / (shortfall)                    $A − $B
```

No expected-but-unlanded inflow is counted in the verdict — that's the whole
point of the closed loop. Genuinely outstanding AR appears as the *recovery*
path, not as cash.

If short, present ranked recovery options:

- **(a) Collect specific invoices** — name them with amounts, and show which
  combination closes the gap (e.g. "collecting Alderbrook ($4,800) alone flips
  you from −$730 to +$4,070; adding Mitsui's outstanding half ($2,100) gives
  +$6,170"). Lead with this.
- **(b) Transfer from reserve** — quote the reserve balance and the exact
  `transfer_funds {fromAccountNumber, toAccountNumber, amount}` that would
  close the gap. **Surface it; never execute without explicit approval.**
- **(c) Delay discretionary AP** — name the specific bills (vendor, amount,
  due date) that could slip past payroll, and what that buys.

If covered, say so, show the headroom, and ask whether to chase the
outstanding AR anyway.

### A5. Reminder drafts — for the named short-payers only

For the **specific** customers identified in A3 as genuinely outstanding (and
only those):

- Tone per the invoice-chase conventions —
  [../invoice-chase/reference/tone-matching.md](../invoice-chase/reference/tone-matching.md)
  (gentle for good payers, firm for repeat-late).
- Queue with Gmail `create_draft` — **drafts only; Gmail cannot send**. The
  owner sends from their mail client.
- Show every draft first and **gate before creating drafts in bulk** — one
  approval covers one batch; changing the set restarts the gate.

### A6. Re-check on demand — "check again"

When the owner says "check again" (or money is expected to land mid-meeting),
re-run **A1 plus the A3 credit query only** (steps 2–6, reusing the
previous AR pull) — `get_account_balance` on the operating account(s)
and `query_transactions {direction: "credit", dateFrom: <yesterday>, dateTo:
<today>, status: ["posted"]}` — cheap and fast. Diff against the previous
pass, recompute the A4 equation, and **say what changed**, e.g.:

> "Alderbrook's $4,800 landed 2 minutes ago — gap closed: −$730 → +$4,070.
> Mitsui's outstanding $2,100 half is still open."

If nothing changed, say that too. Never make the owner re-confirm the A2
obligations table on a re-check unless they say it changed.

## Mode B — Paywhere not connected (forecast only)

The pre-Paywhere pipeline: chain two skills, owner approval at each handoff.

### B1. Cash forecast — trigger the `cash-flow-snapshot` skill

1. Pull AR, AP, and historical payment timing from QuickBooks; fall back to
   CSV upload if QuickBooks is also unavailable.
2. Layer in known fixed costs (rent, payroll, recurring vendor charges).
3. Produce the `--horizon` forecast with percentage-variance confidence bands
   and named risk flags — including the payroll-date risk line ("payroll
   ($X) hits <date>; low-band cash the day before: $Y").
4. Deliver chat summary + XLSX, **labeled as an estimate** — book balances
   and modeled timing, not bank truth.
5. If the forecast shows payroll comfortably covered, ask whether to still
   chase overdue invoices or stop here. Otherwise wait for explicit "okay,
   see what we can collect" before B2.

### B2. Overdue collection — trigger the `invoice-chase` skill

1. Pull overdue invoices from QuickBooks; apply invoice-chase's own
   cross-reference and tone-matching logic, with its existing approval gates.
2. Rank by amount × days-late × payment history; draft tone-matched
   reminders; queue as mail drafts only after approval — never send.
3. Show the projected cash impact if a top-N subset pays within the horizon —
   does that close the B1 payroll gap?

State the caveat once more in the recap: without the bank there is no
settlement detection, so a "chase" candidate may have already paid —
recommend the owner verify before sending, and offer to re-run in Mode A once
Paywhere is connected.

## Approval gates (must hold)

- **No sends, ever** — reminders are drafts only (Gmail cannot send; the
  owner sends). No bulk draft creation without approval of the shown set.
- **No transfers without explicit approval** — `transfer_funds` is surfaced
  as an option with exact numbers, never executed unprompted. Same for any
  QBO write (recording a phantom payment is gated).
- **Forecasts are labeled as estimates** — Mode B output (and any Mode A
  line that relies on modeled timing) says so explicitly; never present a
  forecast as a live verdict.
- **One approval covers one batch.** Changing the set after approval starts
  a new round.
- A connector dying mid-run: stop, report which one, and ask whether to
  retry, degrade (Mode A → Mode B), or abort.

## Edge cases — spell these out, don't guess

- **Payroll date lands oddly** (`--payroll-date` on a weekend or a
  holiday-ish Monday): ask whether payroll actually moves earlier — don't
  silently shift it. The default payroll date is computed, but the owner's
  processor calendar wins.
- **Multiple operating accounts**: ask which one(s) fund payroll; if several,
  show per-account balances and sum only the confirmed ones.
- **A credit matches multiple open invoices** (same amount, ambiguous
  counterparty): present both candidates and ask — never auto-apply.
- **Partial payments**: count only the received amount as collected (the
  analog of commissioning on the received amount, not the invoice total);
  keep the remainder in outstanding AR and in any reminder draft.
- **Received-but-unrecorded (phantom AR)**: cross out of collectible, don't
  double-count in cash, offer the gated QBO payment recording (A3.5).
- **`query_transactions` returns `truncated: true`**: narrow the date range
  and re-query before concluding anything.
- **QuickBooks missing in Mode A**: real-time balances still work, but
  obligations and AR come from the owner's word alone — render the verdict
  with an explicit "owner-stated obligations, no QBO corroboration" label,
  and skip settlement matching against invoices (there are none to match).
- **Nothing outstanding but still short**: go straight to options (b) and
  (c) — reserve transfer and AP triage — and say collections can't close
  this gap.

## Output

End every run with a one-paragraph recap: which mode ran (and why), the
verdict with the equation (live headroom/shortfall in Mode A; forecast bands
in Mode B), recovery options surfaced and which (if any) the owner approved,
drafts queued and to whom, and the projected position if the named invoices
collect.

## Reference

- [../cash-flow-snapshot/SKILL.md](../cash-flow-snapshot/SKILL.md) — the Mode
  B forecast engine (confidence bands, XLSX, CSV fallback).
- [../invoice-chase/SKILL.md](../invoice-chase/SKILL.md) — reminder drafting,
  scoring, and its own gates (Mode B step 2; tone rules reused in A5).
- [../invoice-chase/reference/tone-matching.md](../invoice-chase/reference/tone-matching.md)
  — gentle/firm tone selection for reminder drafts.
