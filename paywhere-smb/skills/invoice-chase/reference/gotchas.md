# Gotchas

Known failure modes for invoice-chase.

---

**Customer paid via stablecoin or an account not yet connected.**

The Paywhere cross-reference covers every account returned by `list_accounts`. If the owner uses a separate banking relationship for one payment rail, those credits won't appear. Note this in the summary: "Paywhere accounts checked: [list]." Let the owner confirm before sending if a payment looks possible but uncorroborated.

---

**QuickBooks AR includes internal or test accounts.**

Some setups include internal billing accounts or test records in AR. Before drafting, filter out customers whose email domain matches the owner's domain, and flag any customer name containing "Test," "Internal," or "Demo."

---

**Multiple overdue invoices from the same customer — send one email only.**

Never draft two separate reminders to the same customer in one batch. Consolidate all overdue invoices into one email with a total amount and a list of invoice numbers. Two emails to the same person in one batch looks disorganized and may trigger a spam filter.

---

**Two open invoices share the same amount.**

When two invoices from different customers both equal a Paywhere credit you found, you can't reliably attribute it to one customer by amount alone. Surface the ambiguity to the owner — "I found a $1,200 credit on 2026-05-09 from `ACH Acme Corp / INV-?`; it could match Acme INV-112 or BlueSky INV-117" — and let them pick. Better to ask once than chase the wrong customer.

---

**Identifying the counterparty on a Paywhere credit.**

Try `get_transaction_detail` for the line first, but its enriched `detail` is best-effort — usually sparse (at most a reference number) or `null` for incoming customer payments, so don't count on it naming the customer. When it doesn't, the customer name lives in the free-text `description` / `statementDescription`: match by amount first, then confirm via the parsing notes in `month-end-prep/reference/paywhere-bank-lines.md`. When that misses too, fall back to showing the full `description` to the owner — don't silently drop the row.

---

**Pending Paywhere transactions are not settled.**

`get_account_transactions` returns settled lines. If the customer initiated a payment that's still pending (ACH in flight, wire not yet landed), it won't appear here yet — check `get_ach_payment_status` / `get_wire_payment_status` for receivables the owner expects soon, and treat them as "in transit, do not chase."
