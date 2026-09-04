# Onboard checklist

## The five interview questions

Ask one at a time. Wait for the full answer before moving on. One follow-up is fine if an answer is vague; do not drill further.

1. **Industry and business type.** "What kind of business do you run? Give me the one-liner."
2. **Team size.** "How many people work with you, including yourself?"
3. **Top three headaches.** "What are your three biggest headaches right now — the things that eat your time or keep you up at night?"
4. **Tools already in use.** "Which tools do you already use day-to-day? Your books, your bank, email, calendar…"
5. **Preferred cadence.** "How would you like me to check in — daily, weekly, or only when you ask?"

If the owner is short on time, compress to questions 1, 3, and 4 — those three feed the most downstream skills.

---

## Connector priority matrix

Map the owner's stated headache to the best two connectors to link first, and to the one thing to run once the first is live. "Plain answer" means no skill: the named calls and a short reply.

| Primary headache | First connector | Second connector | Prove-value recipe | Trigger phrase |
|---|---|---|---|---|
| "I never know where I stand" / cash flow | Paywhere | QuickBooks | Plain answer: `list_accounts` + `query_transactions {aggregate, groupBy: "month", 12 months}` — balances and where cash sat each month | "show my balances", "how did cash move this year" |
| "How much of this is actually mine" / sales tax | Paywhere | QuickBooks | `tax-reserve-check` | "how much of my balance is actually mine" |
| Making payroll | Paywhere | QuickBooks | `plan-payroll` | "can I make payroll Friday" |
| Paying vendors on time (not early) | QuickBooks | Paywhere | `ap-timing` → `pay-bills` | "what's due this week", "pay the bills due this week" |
| Chasing unpaid invoices | QuickBooks | Gmail | `invoice-chase` (drafts only) | "chase my overdue invoices" |
| Profit on paper, no cash in the bank | QuickBooks | Paywhere | `cash-bridge` | "where did the cash go" |
| A big purchase or a bank meeting | Paywhere | Gmail | `big-purchase-decision`, then `credit-readiness` | "can I afford …", "what should I bring to the bank" |
| Income taxes / 1099s | QuickBooks | Paywhere | `tax-season-organizer` | "quarterly taxes", "1099s" |
| General / unsure | Paywhere | QuickBooks | Plain answer (balances + 12-month aggregate), then offer `daily-cash-brief` as the schedule | "run my morning cash brief" |

If the owner names a connector not in this table, add it as the second connector and use the plain balances answer as the recipe.

**Connector capability blurbs (one short sentence each, used when introducing a connector to the owner):**

- **Paywhere** — See balances and cleared activity across accounts, and stage payments and transfers the owner approves on the bank's page with a passkey.
- **QuickBooks** — Read the books: who owes you, what you owe, the P&L and balance sheet, and the sales tax inside the payments that landed (read-only).
- **Gmail** — Search threads for quotes, term sheets and invoice conversations, and draft reminders — drafts only, never sent.
- **Google Calendar** — Read payroll days, tax deadlines and appointments so the morning brief carries dated obligations.

---

## Recipe selection

Run the prove-value recipe immediately after the **first** connector is live — do not wait for the second. If connectors are already active at session start, run the matched recipe for the owner's primary headache before beginning the interview. Priority order:

1. Paywhere alone → plain answer: `list_accounts` + `query_transactions {aggregate: true, groupBy: "month", dateFrom: <first day of the month 12 months ago>}`; two calls, balances by account and the twelve monthly nets.
2. Paywhere + QuickBooks → the headache's skill from the table (`tax-reserve-check` is the strongest first impression: a number the owner has never seen).
3. Gmail → `search_threads` for unread invoice-related mail, surface the top 3 (no drafts during onboarding unless asked).
4. Google Calendar → `list_events` for the next 14 days, surface the dated obligations.

The QuickBooks connector is **read-only**; if it reports missing company profile details, note them and run the recipe anyway. Nothing in this plugin writes to the books.

---

## Owner profile — storage format

Write this block to Cowork's memory for this project under the heading `## Business context`. Every other skill reads this section by heading match. Do not rename the heading or change the field names.

```markdown
## Business context

- **Business:** <one-liner — industry, product/service>
- **Size:** <number of people, including owner>
- **Top headaches:** <headache 1> · <headache 2> · <headache 3>
- **Connected tools:** <comma-separated list of active connectors>
- **Weekly cadence:** <trigger phrase and day, e.g. "weekly check-in every Monday">
- **Onboarded:** <YYYY-MM-DD>
```

If a memory file already exists, append or update only the `## Business context` section. Do not touch other content.
