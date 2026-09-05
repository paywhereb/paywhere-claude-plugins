# Gotchas

## Gotcha: Skipping the prove-value step when a connection takes too long

**Why it matters:** If the owner connects a tool but Claude moves straight to the interview, the "aha" moment never lands. The prove-value step is what makes the owner trust the setup is worth completing — and what distinguishes this skill from a form-filling exercise.

### ✗ Bad

> "Great, your bank is connected! Now let me ask you a few questions about your business."

Skips the recipe entirely. Owner leaves not knowing what they just enabled.

### ✓ Good

> "Your bank is live. Let me pull your balances and where cash sat at each month-end this year — two calls, about ten seconds."
> *[`list_accounts` + `query_transactions {aggregate, groupBy: "month"}`, shows the balances and the twelve monthly nets]*
> "That's available any time you ask. Now, a few questions about your business…"

The prove-value step runs before the interview, every time, without exception.

---

## Gotcha: Routing a plain question through a skill

**Why it matters:** "Show my balances" is one call and two sentences. Wrapping it in a skill adds a confirmation turn, a progress list and a table the owner did not ask for — and teaches them that every question is slow.

### ✗ Bad

> "I'll run the tax reserve check to show your balances…" *[four calls, a table, a staging offer]*

### ✓ Good

> *[`list_accounts`]* "Operating $X, Tax Reserve $Y, Business Savings $Z. Want to know how much of the Operating balance is actually yours after sales tax? Say 'how much of my balance is actually mine'."

Answer the question; offer the skill only when it adds something the question did not ask for.

---

## Gotcha: Dumping all five interview questions at once

**Why it matters:** Five questions presented together feel like a form, not a conversation. Owners either skim-answer or drop off. Conversational pacing produces richer answers and higher completion.

### ✗ Bad

> "To get you set up, I need: (1) What kind of business do you run? (2) How many employees? (3) What are your top headaches? (4) What tools do you use? (5) How often do you want check-ins?"

### ✓ Good

Ask each question, receive the full answer, then ask the next. Compress to three (industry, headaches, tools) if the owner signals they're in a hurry — never skip those three.

---

## Gotcha: Writing context without showing the profile first

**Why it matters:** Silent writes feel intrusive and remove the owner's chance to correct misheard answers. Showing the draft profile is also a natural confirmation that Claude understood correctly — it often surfaces a correction the owner wouldn't have volunteered.

### ✗ Bad

> "Got it, I've saved your business profile!"

No preview, no approval — owner doesn't know what was written.

### ✓ Good

> "Here's what I'm about to save as your business profile — let me know if anything needs fixing:"
>
> ```
> Business: Lakewood Hardware — retail hardware store
> Size: 4 people (including owner)
> Top headaches: cash flow gaps · slow-paying contractors · scheduling part-timers
> Connected tools: Paywhere, QuickBooks, Gmail
> Weekly cadence: weekly check-in every Monday
> Onboarded: 2026-04-23
> ```
>
> "Look right? I'll save it once you confirm."

Show the block, wait for approval, then write.

---

## Gotcha: Pitching the platform instead of the capability

**Why it matters:** Owners already know what QuickBooks, their bank and Gmail do. When the recommendation reads like a product page, it lands as an ad, not advice. The owner tunes out exactly when we need their attention.

### ✗ Bad

> "1. QuickBooks — the all-in-one accounting platform that tracks income and expenses, manages invoices and bills, runs payroll, and produces every financial report your accountant needs.
>
> 2. Paywhere — a modern business bank with multiple accounts, real-time balances, and ACH and wire payments built in…"

Reads like marketing. The owner is being sold to.

### ✓ Good

> "For 'profit on paper but no cash in the bank', the two pieces I'd want are your books and your bank.
>
> Are you on QuickBooks today, or something else?"
>
> *(Owner: "Xero.")*
>
> "Got it — we don't have a Xero connector yet. If you stayed on Xero, you'd still get balances, the year's cash by month and staged payments straight from your bank, but I couldn't tell you who owes you, what's due, or reconcile profit against the cash that actually moved. If you'd be open to QuickBooks, here's what'd unlock: the profit-to-cash bridge, this week's bills staged for one approval, and overdue-invoice reminder drafts. Up to you — want to try it, or skip the books for now?"

States the function, checks what the owner uses, gives a clear gain/loss in plain English, leaves the decision with the owner. If the owner asks "what does QuickBooks actually do?" — that's an explicit invitation; answer it directly.
