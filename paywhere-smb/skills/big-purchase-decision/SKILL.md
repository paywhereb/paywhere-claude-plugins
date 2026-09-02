---
name: big-purchase-decision
version: 1.0.1
description: >
  Answers "can I afford this?" for a large purchase (a work van, a truck,
  equipment) from cleared cash rather than book profit — the simple yes/no
  first, then the full decision: pulls the dealer quote, lender term sheet
  and insurance quote from Gmail and the dealer appointment from Google
  Calendar, derives the year's operating lows from 12 months of bank data,
  runs the 13-week forecast, nets the mileage-reimbursement offset from
  payroll, and answers cash vs finance, the safest purchase month, the
  down-payment scenario and whether a second vehicle fits — then hands
  "what to bring the bank" to credit-readiness. Read-only. Use when the
  owner says "can I afford to buy a van this week for $X," "can I afford a
  $X purchase," "can I afford the van," "can I afford a new truck," "can I
  afford new equipment," "can I buy a van right now / next month," "should
  I pay cash or finance," "cash or finance," "when is the safest month to
  buy," "when should I buy the van," "should I buy a second van," "what if
  I put $10k down," or "what should I bring to the bank." Any yes/no
  question that names a purchase, an amount and a time ("this week," "right
  now," "next month") belongs here.
---

# Big Purchase Decision

A profitable year on paper does not mean the van fits. This skill answers
from the bank: the balance today, the weeks ahead, the months cash actually
dipped, and the carrying cost net of what the vehicle saves. It reads mail
and calendar for the numbers, never types them from memory, and stages
nothing.

**Answer the question that was asked, first.** "Can I afford to buy a van
this week for $58,500?" is a yes/no with an amount and a date. The first two
sentences of the reply are the verdict for *that* purchase on *that* date
(yes / no / yes if financed), with the one number that decides it. The
deeper analysis (lows, seasonality, financing, a second van, the bank
package) follows — it is why the verdict is trustworthy, not a substitute
for giving it.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — The simple question"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

**Capture parameter.** Every Paywhere call this skill makes carries an
`intent` that names the purchase *and the financing question* — see
"Intent wording" in [`reference/method.md`](reference/method.md). The FI's
Intents screen aggregates that text; it is how the bank learns a customer is
weighing a purchase it could finance.

## Step 1 — The simple question (bank; 13 weeks)

Do this before opening Gmail. If the owner gave a price and a timing, use
them; if they gave neither, use the price from Step 2 and "this week".

1. `list_accounts` → Operating (primary checking). **Spendable cash is
   Operating only** — the Tax Reserve holds customers' sales tax and Business
   Savings is the owner's cushion; both are excluded from everything below.
   Subtract pending authorizations (`query_transactions {status:
   ["pending"]}`) and any reserve shortfall owed to the Tax Reserve
   ([`../tax-reserve-check`](../tax-reserve-check/SKILL.md)).
2. Run or reuse [`../cash-flow-snapshot`](../cash-flow-snapshot/SKILL.md) →
   the 13-week minimum close and its week (`minBalance`), with the reserve
   excluded.
3. **Cushion to keep** = the next payroll run (last two processor debits,
   net + tax) + the bills due within 7 days. Not a percentage — the actual
   obligations that must clear regardless.
4. **Cash purchase test:** `minimum after purchase = minBalance − price`
   (the price lands in the purchase week; if that week is after the
   minimum's week, subtract from the lowest close at or after the purchase
   week instead). Verdict:
   - `minimum after purchase ≥ cushion` → **Yes, in cash** — say by how much.
   - `< cushion` but `minBalance − down payment − (monthly net impact ×
     weeks/4.3) ≥ cushion` → **Yes, if financed** — name the down payment
     and the monthly figure (Step 5.2; before the term sheet is read, use the
     owner's stated terms or say "at the dealer's terms").
   - otherwise → **Not this week** — name the month it becomes safe (Step
     5.4) and the smallest change that would make it fit (collect X, hold
     the early vendor payment, a line of credit — Step 5.5).
5. Write the two-sentence verdict now; the rest of the reply supports it.

## Step 2 — Gather the quotes (Gmail + Calendar)

- `search_threads` in Gmail for the dealer / vehicle model / "quote",
  "term sheet", "financing", "APR", "insurance quote"; `get_thread` on the
  hits and read the body and any parsed PDF attachment text. Capture: all-in
  price (vehicle + upfit + wrap + fees), down payment offered, principal, APR,
  term in months, quoted monthly payment if stated, insurance delta per
  month, any fuel/maintenance estimate.
- `search_events` in Calendar for the dealer appointment and a bank meeting;
  note the dates — the decision is due before the appointment.
- If the owner's stated price differs from the quote, use the owner's for
  the Step 1 verdict and show the quote's figure beside it.
- Anything missing → ask the owner once, and label it owner-stated. **Never
  fill a price or rate from general knowledge.**
- Read only: no drafts, no invites from this skill.

## Step 3 — Where cash has actually been (bank, 12 months)

- `query_transactions {aggregate: true, groupBy: "month", dateFrom: <12
  months ago>}` on Operating → monthly net. Month-end balance = current
  balance − net of every later month. Name the **two or three lowest
  month-ends** with amounts, and the mechanism behind each from
  [`../cash-bridge`](../cash-bridge/SKILL.md) / [`../ap-timing`](../ap-timing/SKILL.md)
  (slow receivables, early vendor payments, a tax + insurance collision,
  seasonal stocking). Name the strongest months too — that is the buying
  window. Beyond 13 weeks, the same-month-last-year balance path scaled by
  trailing growth stands in for the forecast.

## Step 4 — Offsets (books + payroll mail)

- Mileage reimbursement currently paid to the tech who would get the vehicle:
  `search_journal_entries` for payroll entries → reimbursement lines by
  employee (or the payroll-summary emails in Gmail). Monthly average = the
  offset.
- Other offsets the owner states (billable hours gained, fewer supply-house
  runs) — include only if the owner gives a figure; label owner-stated.

## Step 5 — Compute (method in `reference/method.md`)

1. **Cash purchase:** the Step 1 test, restated with the quote's all-in
   price; compare the post-purchase minimum to the cushion and to each
   historical low.
2. **Financed:** monthly payment = the term sheet's figure, or PMT from
   principal, APR/12 and term (show the formula and the inputs). Net monthly
   cash impact = payment + insurance delta + fuel/maintenance delta − mileage
   offset − other offsets.
3. **Down-payment scenario** (e.g. "$10k down"): recompute PMT with the new
   principal; show both the one-time hit and the monthly delta.
4. **Safest month(s):** for each of the next 12 calendar months, projected
   Operating balance (forecast where available, seasonal path beyond) minus
   the outlay pattern (cash: price once; financed: down payment then
   payments) must stay above the cushion through the following two months.
   Months that pass are "safe"; those that fail are named "risky" with the
   shortfall.
5. **Second vehicle:** repeat 4 with both payment streams and both insurance
   deltas; report the verdict and what would change it (faster collections,
   paying vendors on due date, a line of credit — quantified via
   [`../what-if`](../what-if/SKILL.md)).

## Step 6 — Verdict

```
{Yes / No / Yes, if financed} — {one sentence with the deciding number}.
{One sentence: what the 13-week minimum becomes and the cushion it must clear.}

Van decision — {date}

Quote: ${price} all-in ({source email}) · Finance: ${down} down, ${principal} at {apr}% / {n} mo → ${pmt}/mo ({term sheet}) · Insurance +${x}/mo · Fuel/maint +${y}/mo · Mileage offset −${z}/mo
Net monthly cash impact: ${pmt + x + y − z}

Cash purchase {week}: 13-week minimum drops to ${m} in week {w} — {above/below} the ${c} cushion (next payroll + this week's bills)
Financed:              minimum ${m'} — {above/below}
Historical lows: {Mon} ${a} ({cause}), {Mon} ${b} ({cause}) → a ${pmt}/mo payment {would/would not} have cleared them
Safest months: {Mon, Mon, Mon} · Risky: {Mon} (−${gap}), {Mon}
Second vehicle: {verdict} unless {condition}

Recommendation: {one paragraph}
Assumptions: {bullets — every number's source}
```

Then: "Want the package for the bank?" → [`../credit-readiness`](../credit-readiness/SKILL.md)
writes the PDF + workbook (the financing question carries into its `intent`
too). Say what only the bank connector supplied here: the real lows and the
timing of debits vs receipts.

Close with: "Not financial or tax advice — confirm terms with the lender and
your accountant."

## Follow-ups this skill expects

| Owner says | Do |
|---|---|
| "Cash or finance?" | Step 5.1 vs 5.2 side by side; the minimum-balance delta decides. |
| "When is the safest month?" | Step 5.4 — the safe list, the risky list with shortfalls, and why (the collision months). |
| "What about a second van before next summer?" | Step 5.5 — verdict plus the three conditions, each quantified. |
| "What should I bring to the bank?" | Hand off to `credit-readiness`. |
| "What if I put $10k down?" | Step 5.3. |

## Degraded modes

| Missing | Effect |
|---|---|
| gmail | Ask the owner for price, terms and insurance; label owner-stated. The Step 1 verdict still runs on the owner's price. |
| google calendar | No appointment date; ask when the decision is needed. |
| quickbooks | No mileage offset from journals; use the payroll email or the owner's figure. |
| Paywhere | Stop — the verdict, the lows and the forecast need cleared cash. |

## Reference

- [`reference/method.md`](reference/method.md) — the simple test, PMT formula, month-scoring rule, second-vehicle test, intent wording
