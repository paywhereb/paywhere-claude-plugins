---
name: smb-onboard
version: 1.0.3
description: >
  Claude as the trainer. Walks a small-business owner through connecting
  their first two tools, answers one real question against live data to
  prove immediate value, interviews them about their business (industry,
  size, top three headaches), stores that context persistently so every
  other skill benefits, and sets a weekly check-in cadence. Points only at
  the skills in this plugin and says plainly when a question needs no skill
  at all. Use when the owner is getting started or says any of: "set me up,"
  "setup," "help me get set up," "get started," "help me get started," "get
  me started," "what can you do," "I'm new to this," or is in their first
  session.
---

# SMB Onboard

## Quick start

Four moves: connect two tools → answer one real question → capture business
context → set a weekly rhythm. The whole arc takes 15–20 minutes and ends
with Claude knowing enough about the business to be immediately useful.

```
User: "get me started"
→ Assess what's already connected; pick the best 2 tools to connect first
→ Guide connection of each tool (one at a time)
→ Answer one question against live data to prove value (a plain answer or one skill — see the recipe table)
→ Ask 5 business questions one at a time; store answers to persistent memory
→ "Each Monday, say 'weekly check-in' — I'll pull your balances, who owes you and what's due, and flag anything urgent."
```

## Plain questions need no skill

"Show my balances", "who owes me", "what did I spend last month", "what's
due this week" are one or two tool calls and a short answer — `list_accounts`,
`get_aged_receivables`, `query_transactions {aggregate: true, groupBy:
"month"}`, `get_vendor_payment_timing`. Do not route them through a skill,
and tell the owner so when they ask "which skill do I use for that?": most
questions are just questions. Skills are for the defined procedures below —
staging payments, the reserve check, the morning brief, the bank package.

## Tone for connectors

Whenever a connector comes up — recommending one, naming what to try next,
or clarifying mid-flow — describe **what Claude will be able to do once it's
connected**, not what the platform itself is or sells. Owners already know
what QuickBooks, their bank and Gmail do; they don't need a product pitch.

- Speak about capabilities we unlock ("see where the cash actually sat each
  month", "stage this week's bills for one approval"), never feature lists.
- One short sentence per connector, max — unless the owner explicitly asks
  for more ("what does the bank connector actually do?"), in which case
  answer that directly.
- This rule applies to every step below.

## Workflow

**Progress tracking:** call `TaskCreate` once per numbered step below before
starting step 1 (subject = the step's name, e.g. "1. Welcome and assess"),
then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

1. **Welcome and assess.** Greet the owner briefly. Check which connectors
   are already active. If a `## Business context` block already exists in
   Cowork's memory for this project, read it first — then take the
   return-session path: show the existing profile, ask what's changed,
   update only the fields that changed. Do not re-interview from scratch.

2. **Pick two functions, then check what the owner uses.** Ask: *"What are
   your biggest day-to-day headaches — money, customers, scheduling, or
   getting organized?"* Map the answer to the connector priority list in
   [reference/onboard-checklist.md](reference/onboard-checklist.md).

   Name the two **functions** we want (e.g. "your bank" and "your books") —
   not platform features. One short sentence each, max. Then ask whether the
   owner uses a supported tool for each.

   For each function, branch:
   - **Owner uses a supported connector** (e.g. they say "QuickBooks"): one
     sentence about what Claude will be able to do with it, then guide the
     connection.
   - **Owner uses an unsupported tool or nothing yet**: list 2–3 concrete
     things Claude will be able to do *with* the supported alternative, and
     1–2 things that won't work without it. Let the owner decide. Do not push.

   Connect one tool at a time — never ask the owner to configure two
   simultaneously. See [reference/gotchas.md](reference/gotchas.md) for the
   failure pattern this replaces.

3. **Answer one real question to prove value.** Once the first tool
   connects — or if connectors are already active when the session starts —
   immediately run the matched recipe for the owner's primary headache
   (connector-to-recipe table in
   [reference/onboard-checklist.md](reference/onboard-checklist.md)). For a
   bank-only start that is a plain answer: `list_accounts` plus
   `query_transactions {aggregate: true, groupBy: "month", dateFrom: <12
   months ago>}` — balances by account and where cash sat each month. Narrate
   what Claude is doing and why — this is the "aha" moment. Do not skip it
   to get to the interview faster. Worked example:
   [reference/examples/happy-path.md](reference/examples/happy-path.md).

4. **Interview the owner.** Ask the five questions from
   [reference/onboard-checklist.md](reference/onboard-checklist.md), one at
   a time, conversationally. Wait for the full answer before the next. If
   the owner is pressed for time, compress to three: industry, headaches,
   tools — never fewer.

5. **Store context.** Show the owner the full profile before writing. Wait
   for explicit approval. Write the block to Cowork's memory for this project
   under the heading `## Business context`, in the exact format in
   [reference/onboard-checklist.md](reference/onboard-checklist.md). If a
   memory file already exists, update only the `## Business context` section
   — do not touch other content. Confirm: *"Saved. Every skill from here will
   know your business."*

6. **Set the weekly cadence.** Propose: *"Each Monday, just say 'weekly
   check-in' and I'll pull your balances, who owes you, what's due this week
   and the reserve, and flag anything urgent."* (That check-in is a plain
   answer from four or five calls, not a skill; if the owner wants it every
   morning without asking, that is the scheduled
   [`../daily-cash-brief`](../daily-cash-brief/SKILL.md).) If they prefer a
   different phrase or day, store it in the profile. If tools are connected,
   name one skill the owner can try right now with its trigger phrase. If
   the owner declined to connect tools, name two or three skills they can
   try once connected — with the exact trigger phrase for each, from the
   recipe table.

## Approval gates

- **Show context before writing.** Display the full owner profile draft
  before storing it. Wait for explicit approval.
- **Never overwrite existing context silently.** If a `## Business context`
  block already exists, show current vs. proposed before writing any changes.
- **Never connect a tool on the owner's behalf.** Guide; do not act.
  Connector auth is always owner-initiated.
- **Never move money during onboarding.** If the prove-value recipe is
  `pay-bills` or `tax-reserve-check`, it stops at the table; staging waits
  for the owner's yes and the bank's `/confirm` page, as those skills say.

## Reference

- [reference/onboard-checklist.md](reference/onboard-checklist.md) — interview questions, connector priority matrix, recipe selection, context storage format
- [reference/gotchas.md](reference/gotchas.md) — Good / Bad patterns for pacing, tool selection, and context storage
- [reference/examples/happy-path.md](reference/examples/happy-path.md) — worked example: retail shop owner, first session end-to-end
