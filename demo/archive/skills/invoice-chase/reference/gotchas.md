# Gotchas

**A check was deposited but never applied in the books.** The most common false chase. A posted bank credit (`MOBILE CHECK DEPOSIT <check#>`, `ACH CR <payer>`, `WIRE IN <sender>`) whose amount equals an open invoice's balance within $0.50 is the evidence; exclude the invoice, quote the row, narrate the QuickBooks payment application (the connector is read-only: the item reappears in AR until the payment is applied).

**Card payments do not match by amount.** They arrive in grouped merchant-processor deposits net of fees. Mark card-paid invoices "not matchable at the bank" and chase or not on the books alone.

**Two open invoices share an amount.** Surface both with the bank row; let the owner pick; chase neither meanwhile.

**Direct-ACH descriptors may carry the payer's AP platform, not the customer's name.** The amount is still the key; quote the descriptor as-is and let the owner confirm who it was.

**Consolidate per customer.** Never two drafts to one customer in a batch, and never more than three drafts in a run.

**Sub-customer jobs.** An invoice on a job rolls up to the parent for the email and the aging; keep the job name in the invoice list.

**Retainage is not late.** A retainage invoice is due at the contractual release date; do not chase before it.

**Pending credits are in transit.** Only `posted` credits are pulled; if the owner mentions a payment "on its way", it is not evidence until it posts.

**Missing recipient.** An open invoice with no `BillEmail` still gets ranked; its draft is created with an empty To line and the reply says so.

**Internal or test customers.** Skip customers whose email domain matches the owner's or whose name contains "Test" or "Sample".
