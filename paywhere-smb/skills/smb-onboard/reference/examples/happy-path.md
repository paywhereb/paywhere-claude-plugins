# Happy path: Retail shop owner, first session

## Setup

- **Owner:** Maria, sole operator of a hardware store with 3 part-time employees
- **Session type:** First session ("get me started")
- **Connectors before start:** None connected

---

## Transcript

**Claude:** Welcome! I'm going to walk you through getting set up — takes about 15 minutes and ends with me knowing enough about your business to be immediately useful. Ready?

**Maria:** Sure.

**Claude:** What are your biggest day-to-day headaches — money stuff, keeping up with customers, scheduling, or something else?

**Maria:** Cash flow. I never know where I stand until the end of the month, and by then it's too late.

**Claude:** That's the most common one. Let's connect Paywhere first — that's your bank, and it'll let me show you your cash position across every account in real time. Here's how to authorize the connection…

*[Maria connects Paywhere — ~2 minutes]*

**Claude:** Paywhere is live. Let me pull your balances and last 30 days of activity right now.

*[runs cash-flow-snapshot]*

**Claude:** Here's your snapshot: $14,800 across your operating and reserve accounts, $4,200 net inflow over the last 30 days, and $6,100 in outstanding invoices from QuickBooks once that's connected. Two contractor accounts owe most of it. Does that match what you're seeing?

**Maria:** Yes, exactly. I didn't know I could see that so fast.

**Claude:** That's available anytime. Second tool: let's connect QuickBooks so I can pair the bank lines with your invoice book and run month-end close.

*[Maria connects QuickBooks — ~3 minutes]*

**Claude:** Good. A few questions so I know your business — one at a time. What's the one-liner for what you do?

**Maria:** Hardware store. Retail and light contractor supply.

**Claude:** How many people work with you, including yourself?

**Maria:** Four total — me and three part-timers.

**Claude:** What are your top three headaches right now?

**Maria:** Cash flow, slow-paying contractors, and scheduling the part-timers around school.

**Claude:** Which tools do you already use day-to-day?

**Maria:** Paywhere and QuickBooks, which we just connected. Also Gmail for everything email.

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

**Claude:** Saved. Every skill from here will know your business. Each Monday, just say "weekly check-in" and I'll pull your cash snapshot, flag urgent invoices, and remind you what's due that week. Want to try the invoice reminder skill right now? Say "invoice chase."

---

## Pass criteria

- [ ] Triggered on "get me started"
- [ ] Asked headache question before recommending connectors
- [ ] Recommended Paywhere first (matched cash-flow headache)
- [ ] Ran `cash-flow-snapshot` immediately after Paywhere connected, before interview
- [ ] Connected second tool (QuickBooks) before starting interview
- [ ] Asked all 5 interview questions one at a time
- [ ] Showed profile draft before writing
- [ ] Wrote context under `## Business context` in `~/.claude/CLAUDE.md`
- [ ] Named the weekly cadence trigger phrase explicitly
- [ ] Offered a next skill naturally at the end

---

# Branch B: Owner uses an unsupported tool

## Setup

- **Owner:** Dev, freelance design studio (2 people)
- **Session type:** First session
- **Primary headache:** Customer follow-up
- **Current CRM:** Pipedrive (no Cowork connector)

## Transcript

**Claude:** What are your biggest day-to-day headaches — money stuff, keeping up with customers, scheduling, or something else?

**Dev:** Customer follow-up. Leads slip through.

**Claude:** For customer follow-up, the two pieces I'd want are a CRM and your inbox. Are you on HubSpot today, or something else?

**Dev:** Pipedrive.

**Claude:** Got it — we don't have a Pipedrive connector yet. If you stayed on Pipedrive, you'd still get cash-flow work and calendar work from Claude, but I wouldn't be able to score leads or draft follow-ups from inside the CRM. If you'd be open to trying HubSpot's free tier, here's what'd unlock: a top-5 call list every morning, drafted follow-ups after every meeting, and stale-deal alerts. Up to you — want to try it, or skip the CRM for now?

**Dev:** Skip for now. I'll stick with Pipedrive.

**Claude:** No problem. Then let's connect Gmail — that'll still let me surface customer threads waiting on a reply and draft replies for you. Sound good?

**Dev:** Yeah.

*[Dev connects Gmail — ~2 minutes]*

**Claude:** Gmail is live. Let me pull the three oldest unread customer threads…

## Pass criteria

- [ ] Named the function ("a CRM and your inbox"), not the platform
- [ ] Asked what the owner uses before pitching anything
- [ ] On unsupported tool, listed gain/loss concretely without pushing
- [ ] Accepted the owner's decision and pivoted to the next supported tool
- [ ] No paragraph-long descriptions of HubSpot, Gmail, or Pipedrive
