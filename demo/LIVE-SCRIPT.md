# Live script — Nick's HVAC

The short version of [`SCENARIOS.md`](SCENARIOS.md): what to type, in order,
and what to point at. Everything else in that file is background,
troubleshooting and beats that are not in this cut.

**Before the room:** Cowork project with
[`cowork-project-prompt.md`](cowork-project-prompt.md) pasted into the
instructions · four connectors signed in as demo-nick · side-load
`dist/paywhere-smb-1.0.20-poc.plugin` · **model Claude Sonnet 5 at MEDIUM
effort** · `/demo-setup`, wait for it to finish · `/demo-inject` (the Friday
tax sweep needs it, or it correctly sweeps nothing).

---

# Opener — the bare connector, no plugin

In **claude.ai or Claude Desktop**, with only the Paywhere connector attached —
no plugin, no skills, no QuickBooks:

```
Pay Johnstone Supply $6,850 from Operating
```

It resolves the payee from what the bank holds, stages the ACH, and returns a
`/confirm` link. **Nothing here is ours except the connector.** Everything that
follows is upside on top of a floor that already works — which is the argument
a technical room actually wants to hear.

---

# Live beats (typed in Cowork)

## 1 — Show my balances (~10 s)

```
Show my balances
```

Three accounts arrive as a **card**. The assistant does not read the figures
back — it says what the accounts are *for* and stops. Make that point out
loud: the card is the interface, the text is the judgement.

If someone asks "so what can he actually spend?", that is the opening for the
reserve check. Say the name; don't run it.

## 2 — Pay the bills due this week (~40 s, the anchor)

```
Pay the bills due this week
```

A table: four bills selected, the fifth (Trane, $11,400) left out because it is
not due yet, the batch total against the operating balance. No money has moved
and no card has appeared — deliberate.

```
Yes, stage them
```

**One** batch: ACH for three vendors, **wire for Ironclad**, each rail chosen
from what the bank holds for that payee. The card and the `/confirm` link
arrive after the sentence, not before.

Open the link, approve with the passkey, let the room watch the money move.
One approval, mixed rails, nothing executed by the model. This is the beat the
demo exists for.

## 3 — Can I afford the van (~25 s)

```
Can I afford the monthly payment on the van quoted in the email from Blue Springs Ford?
```

It reads the dealer's quote out of Gmail, checks the operating account against
twelve months of monthly cash, and answers **yes** in a line or two — $989/month
against what the van replaces, netting to roughly $316/month.

Short is the feature. Cash versus finance, the safest month to buy, a second
van — all one question away, and none of it volunteered.

---

# The agents (scheduled tasks)

Both are set up in **Cowork Desktop → scheduled tasks**. Show the schedule
first, then the run — scroll back to the last real run in Cowork, or fire it
live with the same prompt.

## 4 — Friday tax sweep

| Field | Value |
|---|---|
| Schedule | `Every Friday at 4:00pm` |
| Prompt | `Run the tax sweep` |

Totals the sales tax inside the payments that *arrived this week*, writes
`sweeps/<date>.md`, and stages one Operating → Tax Reserve transfer. The money
was never Nick's; the agent just stops it being spent. Needs `/demo-inject`
first or the honest answer is "nothing came in — nothing to sweep".

## 5 — Savings sweep, overnight

| Field | Value |
|---|---|
| Schedule | `Every Friday at 6:00am` |
| Prompt | `Run the savings sweep` |

Works out what is genuinely spare — net of everything committed through the
next pay cycle, the operating buffer, and the sales tax that isn't his money —
writes `savings/<date>.md`, and stages the transfer. Nick approves it over
coffee.

It shows its arithmetic in full **because nobody was there to ask.** That is
the line to say out loud; it is why an overnight agent is trustworthy at all.

---

# The long ones

Nothing here is checked in: there are no saved transcript files in this repo.
Show these from the scrollback of a real Cowork run, or run them live and let
the room wait. The eval writes its own transcripts under
`paywhere-mcp-api/evals/out/scenario-*/transcripts/` in paywhere-mcp, but that
directory is untracked and every run overwrites it — it is a debugging
artefact, not a presentation asset.

## 6 — Payroll headroom

```
Am I good for payroll Friday?
```

About a minute and a half: the payroll run sized from the processor's own
debits, the bills due by payday, the sales tax collected but not yet swept, and
a yes/no with the arithmetic shown. Same terms as the savings sweep
([`_shared/AVAILABLE-CASH.md`](../paywhere-smb/skills/_shared/AVAILABLE-CASH.md)),
so the two can never disagree on screen.

## 7 — Loan application prep

```
/credit-readiness I'm going to the bank about financing the van.
```

**Type the slash command.** The skill is explicitly invoked; asking "what
should I bring to the bank" gets the van skill's short answer naming it
instead.

The deliverable is the **file** — `bank/credit-readiness-<date>.md` — sized
from the year's deepest peak-to-trough drop rather than today's balance, with
the troughs and what caused them. Show the file, not the chat.

---

# 8 — The FI seat (paywhere-admin → Intents)

Everything above is Nick's story. This is the bank's: during the van beat, the
`intent` on every call carries what he was actually trying to decide, and
**`financing_debt` rises on the Intents screen** — a warm loan lead the bank
never had to ask for.

If it stays flat, the calls did not carry the financing words: check that the
project instructions are in place (see SCENARIOS Act 4).
