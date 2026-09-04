# AUTONOMY.md — how a skill behaves when nobody is watching

Cowork Desktop runs skills on a schedule ("every weekday at 7:30am run my
morning cash brief"). The app must be open; the run uses the owner's own
connectors; the output lands as a notification and as files in the working
folder. Nobody is in the chat to answer a question, so every `*-agent` skill
(and any skill a schedule might call) follows these conventions. Each agent
skill links here **and** repeats the load-bearing sentences inline.

> **Unattended, a skill proposes and never executes.** Payments and transfers
> are staged with `make_batch_payment` (transfers as `{rail: "transfer", …}`
> items, never `transfer_funds`) and the `/confirm` URL is printed in the run
> output as the approval step — the owner opens it and approves with a
> passkey. Every tool call carries `sessionType: "scheduled"` and a stable
> `taskId`. The run writes its output file, skips if today's already exists,
> degrades gracefully when a connector is missing, and creates **drafts only**
> (Gmail `create_draft`; never send, reply or forward).

## 1. Detecting the mode

You are unattended when the run was started by a schedule (the prompt says
so, there is no conversational turn from the owner, or the run is a Cowork
scheduled task). When in doubt and the prompt is a bare command with no
owner present, behave as unattended. An interactive run may still follow
these rules; an unattended run **must**.

## 2. Stamp every tool call

Every Paywhere tool (and any tool that accepts them) gets:

- `sessionType: "scheduled"` — tells the bank the call came from a scheduled
  job rather than a person in the chat, so approvals route accordingly. (The
  server records what you assert; it cannot verify it. Say so if asked.)
- `taskId`: a stable id per schedule, e.g. `daily-cash-brief`,
  `tax-sweep-agent`, `ar-chase-agent`. Same id every run so the bank can see
  the series.

Interactive runs use `sessionType: "interactive"` (or omit it).

## 3. Write a file, dedupe on it

Each agent skill names its output file (`briefs/YYYY-MM-DD.md`,
`sweeps/YYYY-MM-DD.md`). Resolve the date from the
actual current date. **If today's file already exists, stop and say so** in
one line ("Today's brief exists at briefs/2026-09-02.md — skipping."). A
re-run that must regenerate is an owner's explicit ask, not a schedule.

## 4. Propose, never execute

- The only money tools are `make_ach_payment` / `make_wire_payment` /
  `make_batch_payment`; they stage lines and return a confirmation URL. See [`APPROVAL.md`](APPROVAL.md).
- Internal transfers (reserve top-up, sweep, savings) are staged as
  `{rail: "transfer", fromAccountNumber, toAccountNumber, amount}` items in
  the same `make_batch_payment` call as any bills — **never `transfer_funds`**,
  which executes immediately.
- Stage only what the skill defines (e.g. bills due within 7 days that are
  not habitually-early, plus the computed reserve top-up). Never stage a
  discretionary or judgment-call payment unattended — list it under "needs
  you" instead.
- Before staging, check for a same-day duplicate: `query_transactions`
  (`direction: "debit"`, today, the amount) and the server's duplicate flag.
  If a matching debit or staged line already exists, list it as "already
  staged/posted" rather than staging again.
- **Print the URL verbatim** in the run output, with its `confirmation_title`,
  and the sentence "Nothing has moved until you approve this on the bank's
  page." Cowork surfaces the run output as the notification; that is how the
  owner finds the link.

## 5. Degrade gracefully

A missing or failing connector removes a section, not the run:

| Missing | Effect |
|---|---|
| Paywhere | Stop — there is no bank truth to report. Write a one-line file saying the bank was unreachable. |
| quickbooks | Bank-only brief: balances, debits/credits, reserve check from bank rows; AR/AP sections say "QuickBooks unavailable". |
| gmail | No drafts; the brief lists who *would* have been drafted. |
| google calendar | No dated-obligation overlay; say so. |

Never retry in a loop, never ask a question, never abort because one source
was down.

## 6. Drafts only, no invites

Gmail: `create_draft` (and the read tools `search_threads`, `get_thread`,
`get_message`, `list_drafts`). Never `send_message`, `reply`, `forward`.
Calendar: read tools (`list_events`, `search_events`, `get_event`);
`create_event` only when the owner explicitly asked for a reminder, always
without attendees. This plugin never sends email.

## 7. Output shape (the run's chat/notification text)

```
<Skill name> — <date> (scheduled)
Written: <path>
Staged for approval: <n> lines, $<total> → <confirmation_title>
<confirmation_url>
Nothing has moved until you approve this on the bank's page.
Needs you: <bullets>   |  Unavailable: <connectors>
```

## 8. Showing a run on request

Cowork scheduled runs fire only while the app is open. If the owner wants to
see a run without waiting for the schedule, run the same prompt
interactively: the output file and the staged proposal are identical, and
the approval still happens on the bank's page.
