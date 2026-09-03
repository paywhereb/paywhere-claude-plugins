# Gotchas

**A check was deposited but never applied in the books.** The most common false chase. The bank row `MOBILE CHECK DEPOSIT <check#>` matching an open invoice's balance is the evidence; exclude the invoice, quote the row, narrate the QuickBooks payment application (the QuickBooks connector is read-only: the item reappears until the bookkeeper applies it).

**Card payments do not match by amount.** They arrive in grouped `INTUIT PYMT SOLN DEPOSIT` rows net of fees. Match through the books' Deposit (which lists the payments), not against the bank amount.

**Two open invoices share an amount.** Surface both with the bank row; let the owner pick; chase neither meanwhile.

**Direct-ACH descriptors carry the payer's AP system, not the customer.** _E.g. an `ACH CR AVIDXCHANGE …` row is a property-management customer paying through AP automation._ Use `get_transaction_detail` (may be `null`) and the customer's normal rail from history before matching.

**Consolidate per customer.** Never two drafts to one customer in a batch.

**Sub-customer jobs.** An invoice on a job rolls up to the parent for the email and the profile; keep the job name in the invoice list.

**Retainage is not late.** A retainage invoice is due at the contractual release date; do not chase before it.

**Pending credits are in transit.** A `pending` bank credit means the money is coming; mark "in transit — do not chase".

**Internal/test customers.** Skip customers whose email domain matches the owner's or whose name contains "Test" or "Sample".
