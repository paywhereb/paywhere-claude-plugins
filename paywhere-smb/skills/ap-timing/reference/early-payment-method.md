# Early-payment definitions

These are the definitions `get_vendor_payment_timing` applies server-side. The skill reports them; it never recomputes them from `search_bills` / `search_bill_payments`.

| Field | Definition |
|---|---|
| window | the last `months` whole months before today (default 12), every vendor unless `vendor_ref` is given |
| `daysUntilDue` (open bill) | due date − today; negative = overdue |
| `dueWithin7Days` | open bills with due date ≤ today + 7 days (includes overdue) |
| `notYetDue` | the other open bills, each flagged `vendorHabituallyPaidEarly` |
| `billsPaid` | bills closed by a bill payment inside the window |
| `paidEarly` | of those, bills whose closing payment posted **≥ 5 days before `DueDate`** |
| `meanDaysEarly` | mean of (due date − payment date) over the **early-paid bills only**; `null` when none. On-time and late bills are not averaged in, so a seasonal habit is not diluted |
| `dollarsPaidEarly` | sum of the early-paid bills' totals |
| `monthsPaidEarly` | calendar months (by payment date) in which a bill was paid early |
| `habituallyPaidEarly` | **≥ 3** early-paid bills in the window |

Bills due on receipt have due date = bill date and cannot be early; they never create a habit.

## Hold rule

`HOLD` = open bill in `notYetDue` whose vendor is `habituallyPaidEarly`. Pay it on the due date; stage it in pay-bills about 2 business days before (ACH takes 1–3 business days). Cash kept in Operating until then = the bill's open balance. Never hold past the due date, and never hold a tax authority or a due-on-receipt subcontractor.
