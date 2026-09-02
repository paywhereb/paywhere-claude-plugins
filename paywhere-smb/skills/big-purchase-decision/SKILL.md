---
name: big-purchase-decision
version: 1.0.0
description: >
  Decides a large purchase (a work van, a truck, equipment) from cleared cash
  rather than book profit: pulls the dealer quote, lender term sheet and
  insurance quote from Gmail and the dealer appointment from Google Calendar,
  derives the year's operating lows from 12 months of bank data, runs the
  13-week forecast, nets the mileage-reimbursement offset from payroll, and
  answers cash vs finance, the safest purchase month, the down-payment
  scenario and whether a second vehicle fits — then hands "what to bring the
  bank" to credit-readiness. Read-only. Use when the owner says "can I afford
  the van," "cash or finance," "when should I buy the van," "should I buy a
  second van," "can I afford a new truck," "can I afford new equipment,"
  "what if I put $10k down," or "what should I bring to the bank."
---

# Big Purchase Decision

A profitable year on paper does not mean the van fits. This skill answers
from the bank: the months cash actually dipped, the weeks ahead, and the
carrying cost net of what the vehicle saves. It reads mail and calendar for
the numbers, never types them from memory, and stages nothing.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Gather the quotes"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

## Step 1 — Gather the quotes (Gmail + Calendar)

- `search_threads` in Gmail for the dealer / vehicle model / "quote",
  "term sheet", "financing", "APR", "insurance quote"; `get_thread` on the
  hits and read the body and any parsed PDF attachment text. Capture: all-in
  price (vehicle + upfit + wrap + fees), down payment offered, principal, APR,
  term in months, quoted monthly payment if stated, insurance delta per
  month, any fuel/maintenance estimate.
- `search_events` in Calendar for the dealer appointment and a bank meeting;
  note the dates — the decision is due before the appointment.
- Anything missing → ask the owner once, and label it owner-stated. **Never
  fill a price or rate from general knowledge.**
- Read only: no drafts, no invites from this skill.

## Step 2 — Where cash has actually been (bank, 12 months)

- `list_accounts` → Operating (primary checking); the Tax Reserve and
  Business Savings are excluded from everything below.
- `query_transactions {aggregate: true, groupBy: "month", dateFrom: <12
  months ago>}` on Operating → monthly net. Month-end balance = current
  balance − net of every later month. Name the **two or three lowest
  month-ends** with amounts, and the mechanism behind each from
  [`../cash-bridge`](../cash-bridge/SKILL.md) / [`../ap-timing`](../ap-timing/SKILL.md)
  (slow receivables, early vendor payments, a tax + insurance collision,
  seasonal stocking). Name the strongest months too — that is the buying
  window.

## Step 3 — Where cash is going (13 weeks)

Run or reuse [`../cash-flow-snapshot`](../cash-flow-snapshot/SKILL.md):
minimum close, its week, and the reserve to keep. Beyond 13 weeks, use the
same-month-last-year balance path from Step 2 scaled by trailing growth.

## Step 4 — Offsets (books + payroll mail)

- Mileage reimbursement currently paid to the tech who would get the vehicle:
  `search_journal_entries` for payroll entries → reimbursement lines by
  employee (or the payroll-summary emails in Gmail). Monthly average = the
  offset.
- Other offsets the owner states (billable hours gained, fewer supply-house
  runs) — include only if the owner gives a figure; label owner-stated.

## Step 5 — Compute (method in `reference/method.md`)

1. **Cash purchase:** minimum close after subtracting the all-in price in
   the chosen week; compare to the reserve to keep and to each historical low.
2. **Financed:** monthly payment = the term sheet's figure, or PMT from
   principal, APR/12 and term (show the formula and the inputs). Net monthly
   cash impact = payment + insurance delta + fuel/maintenance delta − mileage
   offset − other offsets.
3. **Down-payment scenario** (e.g. "$10k down"): recompute PMT with the new
   principal; show both the one-time hit and the monthly delta.
4. **Safest month(s):** for each of the next 12 calendar months, projected
   Operating balance (forecast where available, seasonal path beyond) minus
   the outlay pattern (cash: price once; financed: down payment then
   payments) must stay above the reserve to keep through the following two
   months. Months that pass are "safe"; those that fail are named "risky"
   with the shortfall.
5. **Second vehicle:** repeat 4 with both payment streams and both insurance
   deltas; report the verdict and what would change it (faster collections,
   paying vendors on due date, a line of credit — quantified via
   [`../what-if`](../what-if/SKILL.md)).

## Step 6 — Verdict

```
Van decision — {date}

Quote: ${price} all-in ({source email}) · Finance: ${down} down, ${principal} at {apr}% / {n} mo → ${pmt}/mo ({term sheet}) · Insurance +${x}/mo · Fuel/maint +${y}/mo · Mileage offset −${z}/mo
Net monthly cash impact: ${pmt + x + y − z}

Cash purchase: minimum drops to ${m} in week {w} — {above/below} the ${r} reserve to keep
Financed:      minimum ${m'} — {above/below}
Historical lows: {Mon} ${a} ({cause}), {Mon} ${b} ({cause}) → a ${pmt}/mo payment {would/would not} have cleared them
Safest months: {Mon, Mon, Mon} · Risky: {Mon} (−${gap}), {Mon}
Second vehicle: {verdict} unless {condition}

Recommendation: {one paragraph}
Assumptions: {bullets — every number's source}
```

Then: "Want the package for the bank?" → [`../credit-readiness`](../credit-readiness/SKILL.md)
writes the PDF + workbook. Say what only the bank connector supplied here:
the real lows and the timing of debits vs receipts.

Close with: "Not financial or tax advice — confirm terms with the lender and
your accountant."

## Degraded modes

| Missing | Effect |
|---|---|
| gmail | Ask the owner for price, terms and insurance; label owner-stated. |
| google calendar | No appointment date; ask when the decision is needed. |
| quickbooks | No mileage offset from journals; use the payroll email or the owner's figure. |
| Paywhere | Stop — the lows and forecast need cleared cash. |

## Reference

- [`reference/method.md`](reference/method.md) — PMT formula, month-scoring rule, second-vehicle test
