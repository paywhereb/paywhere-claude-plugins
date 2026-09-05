# Tone matching

The tone comes from the customer's row in `get_aged_receivables` — where its open balance sits across the aging buckets. No payment history is pulled.

## Aging → tone

| Where most of the customer's balance sits | Tone | Character |
|---|---|---|
| Current or 1–30 days | Gentle | Friendly, assumes oversight, opens with grace |
| 31–60 days, or spread evenly across buckets | Neutral | Professional, factual, no judgement |
| 61+ days, or open balances in three or more buckets at once | Firm | Direct, names a remit-by date, no warmth, no accusation |
| retainage or a contractual release date not yet reached | — | Do not chase before the release date; after it, Neutral and cite the term |

"Most" = more than half the customer's total open balance. A single invoice's tone is the bucket it sits in.

## Subject lines

- Gentle: `Quick reminder: Invoice #[N] for $[amount]`
- Neutral: `Following up: Invoice #[N] — $[amount] past due`
- Firm: `Past due notice: Invoice #[N] — $[amount] ([X] days overdue)`

With several invoices in one email, use the oldest invoice's number and the combined total.

## Body (all tones)

Invoice number(s), total due, original due date(s), days overdue, how to pay (the method the invoice offers — online link, ACH, check). One call to action.

- Gentle adds one acknowledgement sentence ("if it's already on its way, please disregard").
- Neutral adds nothing.
- Firm adds one deadline sentence ("Please remit by [date]", 7 calendar days out).

## Consolidation

Multiple overdue invoices for one customer → one email listing each (number, amount, due date) and the combined total. Tone follows the customer's aging profile, not the oldest invoice alone.

## Never

Never mention another customer, never threaten collections or legal action, never quote the tone label or the aging bucket to the customer, never reference the bank.
