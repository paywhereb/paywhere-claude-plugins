# Cash-crunch scenario — the /plan-payroll shortfall math

Layers on the base world seeded by
[../../demo-setup-base/SKILL.md](../../demo-setup-base/SKILL.md). Every number
below ties to the base manifests —
[../../demo-setup-base/seed/persona.md](../../demo-setup-base/seed/persona.md),
[../../demo-setup-base/seed/bank-manifest.md](../../demo-setup-base/seed/bank-manifest.md),
[../../demo-setup-base/seed/qbo-manifest.md](../../demo-setup-base/seed/qbo-manifest.md)
— and every date is a token per
[../../demo-setup-base/seed/date-tokens.md](../../demo-setup-base/seed/date-tokens.md).
Accounts are referred to by role (Operating / Reserve); concrete numbers come
from `get_demo_world` at run time.

**The scripted demo line this scenario must produce, verbatim:**

> **"$6,200 short for Friday's payroll unless two invoices are collected."**

## Why the base world has no crunch — and why that's deliberate

After a full base seed (no horizon drops): **Operating Checking $96,291.97**,
**Reserve Savings $165,243.75** (bank-manifest.md closing check).

The Friday obligations set — define it once, use it consistently:

| # | Obligation | Amount | Due |
|---|---|---|---|
| O1 | Gusto payroll run (W-2 staff, persona.md "Payroll") | 11,700.00 | `W+0:Fri` |
| O2 | Contractor payout cycle (persona.md workers table) | 56,800.00 | `W+0:Fri` |
| O3 | Open AP — overdue: PWD-BILL-0308 $940.00 + 0309 $1,850.00 + 0310 $3,200.00 | 5,990.00 | already past due |
| O4 | Open AP — coming due: PWD-BILL-0311 $2,450.00 (`W+0:Fri`) + 0312 $480.00 (`W+0:Fri`) + 0313 $4,500.00 (`W+0:Fri+7`) | 7,430.00 | by `W+0:Fri+7` |
| | **FridayObligations** | **81,920.00** | |

O2 itemized (hours × pay rate, all exact): Priya Raman 160 × $100 =
$16,000.00; Marcus Webb 150 × $80 = $12,000.00; Elena Sorokina 150 × $120 =
$18,000.00; Devon Okafor 120 × $90 = $10,800.00. Sum **$56,800.00**.

**Definition.** FridayObligations = the Gusto run + the contractor cycle (both
due `W+0:Fri`) + **every open bill due on or before `W+0:Fri+7`** — at base
seed that is the entire open-AP book ($5,990.00 overdue + $7,430.00 coming
due). The window runs through `W+0:Fri+7` because the Slack renewal due the
following week must be funded from the same cash; counting it is the
conservative funding view and keeps the total at the canonical $81,920.00.
This matches `/plan-payroll` Mode A's **default** AP window (payroll date
+ 7 days) — the scripted −$6,200 only holds under that window. If the owner
narrows plan-payroll to "due through payroll date only", the Slack $4,500
falls out and the verdict reads −$1,700; the presenter should leave the
default in place.

Base headroom: 96,291.97 − 81,920.00 = **+14,371.97**. No crunch by default —
the base world is healthy on purpose. This extension drains Operating to
create the crunch.

## The drains — three backdated bank withdrawals

Target: ProjectedAvailable(`W+0:Fri`) − FridayObligations = **−6,200.00**
exactly.

```
TargetOperating = FridayObligations − 6,200.00 = 81,920.00 − 6,200.00 = 75,720.00
DrainTotal      = 96,291.97 − 75,720.00       = 20,571.97
```

Three realistic one-offs that stack in the same week as payroll — quarterly
estimated tax, an annual insurance renewal, a workstation refresh. The tax row
carries the odd cents (computed tax amounts are never round); it is also the
**flex row** when recomputing against a non-canonical world (below). All
counterparty details are mock/test values, defined here because they exist
only in this scenario (persona.md remains untouched):

| Token | Account | Direction | Amount | Type | Description | StatementDescription | achRecipient |
|---|---|---|---|---|---|---|---|
| `W-1:Tue` | Operating | withdraw | 13,471.97 | ACH | United States Treasury - quarterly federal estimated tax (EFTPS) | ACH DEBIT IRS USATAXPYMT | name `United States Treasury`, aba `061036000`, accountNumber `23401009`, accountType `Checking` |
| `W-1:Wed` | Operating | withdraw | 5,400.00 | ACH | Pacific Shield Insurance Co - annual premium renewal | ACH DEBIT PACIFIC SHIELD INS | name `Pacific Shield Insurance Co`, aba `026009593`, accountNumber `884422110099`, accountType `Checking` |
| `W-1:Fri` | Operating | withdraw | 1,700.00 | ACH | Corelink Office Systems - workstation refresh | ACH DEBIT CORELINK OFFICE SYS | name `Corelink Office Systems`, aba `121000248`, accountNumber `778811223344`, accountType `Checking` |

All rows: `status: "posted"`, `postDate` = the resolved token date. All three
tokens are `W-1:*` — **never dropped** at any horizon (date-tokens.md), so the
crunch survives any day-of-week and any day-of-month run. No drain ever uses a
post-horizon date.

Balance walk (withdrawals only — Operating must stay positive at every step):

```
96,291.97 − 13,471.97 = 82,820.00   (after EFTPS)
82,820.00 −  5,400.00 = 77,420.00   (after insurance)
77,420.00 −  1,700.00 = 75,720.00   (after equipment)   ✓ minimum 75,720.00 > 0
```

Reserve Savings is deliberately untouched: **$165,243.75** stays available as
the escape hatch (`transfer_funds`) that /plan-payroll should *surface as an
option*, never auto-take.

## The shortfall equation — every term

No seeded row exists after the horizon (seeds end at the horizon, full stop),
so with no collections the Operating balance *is* the Friday projection:

```
ProjectedAvailable(W+0:Fri) = 75,720.00
FridayObligations           = 11,700.00 + 56,800.00 + 5,990.00 + 7,430.00 = 81,920.00
Headroom                    = 75,720.00 − 81,920.00 = −6,200.00            ← the crunch
```

## The two-invoice recovery

True collectible AR after the base seed (qbo-manifest.md cross-check):

| Invoice | Customer | Open balance | Note |
|---|---|---|---|
| PWD-INV-0303 | Alderbrook Ventures LLC | 15,600.00 | fully open — slow payer, no payment anywhere |
| PWD-INV-0304 | Mitsui Digital KK | 7,020.00 | second half open (first $7,020.00 received `W-1:Thu`) |
| | **True open AR** | **22,620.00** | |

**Excluded — the phantom:** PWD-INV-0305 (Hallsten & Berg AB, $8,500.00) is
open *in QBO*, but the bank already received the money (`W-1:Mon` ACH CR,
deliberately unrecorded). That $8,500.00 is already inside the $75,720.00
balance — it is **not collectible cash** and must never be added to the
recovery math. /plan-payroll's settlement detection crosses it out and offers
to record the QBO payment instead.

```
−6,200.00 + 15,600.00 (Alderbrook) + 7,020.00 (Mitsui) = +16,420.00 covered
```

Hence the verdict line, verbatim: **"$6,200 short for Friday's payroll unless
two invoices are collected."**

## QBO mirrors — the drains must NOT create new discrepancies

Each drain gets a matched, fully-booked bill + bill payment (TxnDate = DueDate
= bill-payment date = the bank debit's resolved token date), so /close-month
reconciliation still finds exactly the two standing base discrepancies —
**$43.17** (unbooked interest) and **$1.20** (unbooked wire fee) — and nothing
else.

Vendors (search by DisplayName, create only if missing, NEVER delete):
`United States Treasury`, `Pacific Shield Insurance Co`,
`Corelink Office Systems`.

| Bill / BillPayment | Vendor | Token | Amount | Bank row match |
|---|---|---|---|---|
| PWD-CRUNCH-0001 / PWD-CRUNCH-1001 | United States Treasury | `W-1:Tue` | 13,471.97 | ACH debit, `W-1:Tue` |
| PWD-CRUNCH-0002 / PWD-CRUNCH-1002 | Pacific Shield Insurance Co | `W-1:Wed` | 5,400.00 | ACH debit, `W-1:Wed` |
| PWD-CRUNCH-0003 / PWD-CRUNCH-1003 | Corelink Office Systems | `W-1:Fri` | 1,700.00 | ACH debit, `W-1:Fri` |

Bill payments carry 1000 + the bill's sequence. Dedupe/reset key:
`search_bills` / `search_bill_payments` filtering DocNumber
`PWD-CRUNCH-%` (LIKE; fall back to `PrivateNote LIKE 'PWD-CRUNCH-%'` if the
sandbox drops custom DocNumbers — same caveat as the base seed).

## Determinism — identical Monday through Sunday

- **Tokens only.** All three drains are `W-1:*` rows, which resolve to the
  same concrete dates every day of a given week (the horizon Sunday is
  constant all week) and are never dropped. The −6,200.00 result is therefore
  byte-identical whether the crunch is seeded Monday or Friday.
- **Payroll date = `W+0:Fri`** — the Friday *strictly after* today. On a
  Friday run that is **next** Friday. The crunch story still holds: every
  amount is seeded, none depends on today, so the projection and the verdict
  are the same regardless of which day the demo runs.
- `W+0:Fri` / `W+0:Fri+7` appear only as due dates, never as posted rows
  (date-tokens.md hard rules).

## Recomputing against a non-canonical world

If the live Operating balance or the live obligations differ from canonical
(early-month base run dropped `M0` rows; another demo extension paid AP;
prior demo activity), the setup skill recomputes so the verdict still lands at
exactly −6,200.00. Insurance and equipment stay fixed; the EFTPS row flexes:

```
ObligationsNow = 11,700.00 + 56,800.00 + (live open AP due ≤ W+0:Fri+7)
DrainTotal     = OperatingNow + 6,200.00 − ObligationsNow
EFTPS          = DrainTotal − 5,400.00 − 1,700.00 = DrainTotal − 7,100.00
```

Worked early-month example (all base `M0` rows dropped): OperatingNow =
96,291.97 − 43.17 + 14,451.20 = **110,700.00**; ObligationsNow = 81,920.00
(open bills survive — due dates are exempt from drops). DrainTotal =
110,700.00 + 6,200.00 − 81,920.00 = 34,980.00 ⇒ EFTPS = **27,880.00**.
Check: 110,700.00 − 34,980.00 = 75,720.00; 75,720.00 − 81,920.00 = −6,200.00. ✓

Validity guards: EFTPS must stay positive and the balance walk must never go
negative. If `DrainTotal ≤ 7,100.00`, the formula breaks — see the setup
skill's edge cases (scale the scenario; never seed a nonsense row).

## The mid-demo moment — settlement detection flips the verdict

Live "money just landed" moments are **demo-driven, never seed-driven**
(date-tokens.md hard rule 3). Mid-demo, the presenter posts Alderbrook's
payment as a live deposit (Alderbrook pays by ACH-style credit per persona.md
— type `Transfer`, never `ACH`), then asks /plan-payroll to "check again":

```
deposit_to_mock_account {
  accountNumber: "<Operating, from get_demo_world>",
  amount: 15600.00,
  description: "Alderbrook Ventures LLC - staffing hours",
  statementDescription: "ACH CR ALDERBROOK VENTURES",
  status: "posted",
  transactionType: "Transfer"
}
```

No `postDate` — it posts now, which is the point. The after-math:

```
75,720.00 + 15,600.00 = 91,320.00
91,320.00 − 81,920.00 = +9,400.00     ← gap closed; Mitsui's 7,020.00 still open
(collect Mitsui too:  +9,400.00 + 7,020.00 = +16,420.00)
```

PWD-INV-0303 is still open in QBO at that moment — settlement detection must
flip the verdict from the **bank credit alone** and offer (gated) to record
the QBO payment. That contrast is the whole demo.
