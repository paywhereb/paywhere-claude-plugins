# Tone matching

Profiles come from `../../ar-health/reference/profiles.md` (derived from 12 months of invoice-to-payment lags; ≥ 3 paid invoices to classify).

## Profile → tone

| Profile | Tone | Character |
|---|---|---|
| prompt | Gentle | Friendly, assumes oversight, opens with grace |
| occasionally very late | Neutral | Professional, factual, no judgment |
| insufficient history | Neutral | Same as above |
| routinely late | Firm | Direct, names a date, no warmth, no accusation |
| delinquent then cured | Firm | Direct; reference the payment plan if one existed |
| retainage | — | Do not chase before the contractual release date; after it, Neutral and cite the contract term |

## Subject lines

- Gentle: `Quick reminder: Invoice #[N] for $[amount]`
- Neutral: `Following up: Invoice #[N] — $[amount] past due`
- Firm: `Past due notice: Invoice #[N] — $[amount] ([X] days overdue)`

## Body (all tones)

Invoice number(s), total due, original due date, days overdue, how to pay (the method this customer normally uses — ACH, check, card link). One call to action.

- Gentle adds one acknowledgment sentence.
- Neutral adds nothing.
- Firm adds one deadline sentence ("Please remit by [date]").

## Consolidation

Multiple overdue invoices for one customer → one email listing each (number, amount, due date) and the combined total. Tone follows the customer's profile, not the oldest invoice.

## Never

Never mention another customer, never threaten collections or legal action, never quote the payment-profile label to the customer.
