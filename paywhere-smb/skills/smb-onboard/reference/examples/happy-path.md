# Happy path: Retail shop owner, first session

## Setup

- **Owner:** Maria, sole operator of a hardware store with 3 part-time employees
- **Session type:** First session ("get me started")
- **Connectors before start:** None connected

Figures are illustrative.

---

## Transcript

**Claude:** Welcome! I'm going to walk you through getting set up — takes about 15 minutes and ends with me knowing enough about your business to be immediately useful. Ready?

**Maria:** Sure.

**Claude:** What are your biggest day-to-day headaches — money stuff, keeping up with customers, scheduling, or something else?

**Maria:** Cash flow. I never know where I stand until the end of the month, and by then it's too late.

**Claude:** That's the most common one. Let's connect your bank first — once it's live I can show you where you stand any time, not just at month-end. Here's how to authorize the connection…

*[Maria connects Paywhere — ~2 minutes]*

**Claude:** Your bank is live. Let me pull your balances and where cash sat at each month-end this year — two calls.

*[`list_accounts` + `query_transactions {aggregate: true, groupBy: "month", dateFrom: <12 months ago>}`]*

**Claude:** Operating $21,400, Tax Reserve $3,900, Business Savings $8,000. Over the last twelve months your Operating balance ran between about $9,000 (February) and $31,000 (August) — the low months are when the spring stocking orders clear before the season's sales land. That's the picture you were waiting until month-end for; you can ask for it any time with "show my balances" or "how did cash move this year". Does it match what you're seeing?

**Maria:** Yes, exactly. I didn't know I could see that so fast.

**Claude:** Second tool: your books. With QuickBooks connected I can tell you who owes you and what's due, and stage this week's bills for one approval.

*[Maria connects QuickBooks — ~3 minutes]*

**Claude:** Good. A few questions so I know your business — one at a time. What's the one-liner for what you do?

**Maria:** Hardware store. Retail and light contractor supply.

**Claude:** How many people work with you, including yourself?

**Maria:** Four total — me and three part-timers.

**Claude:** What are your top three headaches right now?

**Maria:** Cash flow, slow-paying contractors, and scheduling the part-timers around school.

**Claude:** Which tools do you already use day-to-day?

**Maria:** The bank and QuickBooks, which we just connected. Also Gmail for everything email.

**Claude:** Got it. Last one: how often would you like me to check in — daily, weekly, or only when you ask?

**Maria:** Weekly's good. Monday mornings.

**Claude:** Here's what I'm about to save as your business profile — let me know if anything's off:

```
Business: Hardware store — retail and light contractor supply
Size: 4 people (including owner)
Top headaches: cash flow gaps · slow-paying contractors · scheduling part-timers
Connected tools: Paywhere, QuickBooks, Gmail
Weekly cadence: weekly check-in every Monday
Onboarded: 2026-04-23
```

Look right?

**Maria:** Yep, that's it.

**Claude:** Saved. Every skill from here will know your business. Each Monday, just say "weekly check-in" and I'll pull your balances, who owes you and what's due, and flag anything urgent. Since slow-paying contractors are on your list — want to try the invoice reminders now? Say "chase my overdue invoices"; I only write drafts, nothing is sent.

---

## Pass criteria

- [ ] Triggered on "get me started"
- [ ] Asked the headache question before recommending connectors
- [ ] Recommended the bank first (matched the cash-flow headache)
- [ ] Answered the cash question plainly (`list_accounts` + the 12-month aggregate, two calls, no skill) immediately after the bank connected, before the interview
- [ ] Connected the second tool (QuickBooks) before starting the interview
- [ ] Asked all 5 interview questions one at a time
- [ ] Showed the profile draft before writing
- [ ] Wrote context under `## Business context` in Cowork's memory for this project
- [ ] Named the weekly cadence trigger phrase explicitly
- [ ] Offered a next skill naturally at the end, with its trigger phrase

---

# Branch B: Owner uses an unsupported tool

## Setup

- **Owner:** Dev, freelance design studio (2 people)
- **Session type:** First session
- **Primary headache:** Profitable on paper, never much cash in the bank
- **Current books:** Xero (no Cowork connector)

## Transcript

**Claude:** What are your biggest day-to-day headaches — making payroll, paying people, taxes, cash, or something else?

**Dev:** The books say I made money last year. The bank account doesn't look like it.

**Claude:** For that one the two pieces I'd want are your books and your bank. Are you on QuickBooks today, or something else?

**Dev:** Xero.

**Claude:** Got it — we don't have a Xero connector yet. If you stayed on Xero, you'd still get balances, the year's cash by month and staged payments straight from your bank, but I couldn't reconcile the profit in your books against the cash that actually moved, or tell you who owes you. If you'd be open to QuickBooks, here's what'd unlock: the profit-to-cash bridge ("where did the cash go"), this week's bills staged for one approval, and overdue-invoice reminder drafts. Up to you — want to try it, or skip the books for now?

**Dev:** Skip for now. I'll stick with Xero.

**Claude:** No problem. Then let's connect your bank — that still gives you balances any time and where cash sat each month, which is half of your question. Sound good?

**Dev:** Yeah.

*[Dev connects Paywhere — ~2 minutes]*

**Claude:** Your bank is live. Let me pull your balances and the last twelve months by month…

## Pass criteria

- [ ] Named the function ("your books and your bank"), not the platform
- [ ] Asked what the owner uses before pitching anything
- [ ] On the unsupported tool, listed gain/loss concretely, naming only skills that exist, without pushing
- [ ] Accepted the owner's decision and pivoted to the next supported tool
- [ ] No paragraph-long descriptions of QuickBooks, Paywhere, or Xero
