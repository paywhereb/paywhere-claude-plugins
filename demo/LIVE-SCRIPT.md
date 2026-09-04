# Live script — Nick's HVAC

The short version of [`SCENARIOS.md`](SCENARIOS.md): three beats typed live,
three shown from saved transcripts. Everything else in that file is background,
troubleshooting and the beats that are not in this cut.

**Before the room:** Cowork project with
[`cowork-project-prompt.md`](cowork-project-prompt.md) pasted into the
instructions · four connectors signed in as demo-nick · side-load
`dist/paywhere-smb-1.0.19-poc.plugin` · **model Claude Sonnet 5 at MEDIUM
effort** · `/demo-setup` and wait for it to finish · `/demo-inject` if you are
also showing the Friday tax sweep.

---

## Live 1 — Show my balances (~10 s)

```
Show my balances
```

Three accounts arrive as a **card**. The assistant should not read the figures
back to you — it says what the accounts are *for* and stops. That is the point
to make out loud: the card is the interface, the text is the judgement.

If someone asks "so what can he actually spend?", that is the opening for the
reserve check — say the name, do not run it. It is not in this cut.

## Live 2 — Pay the bills due this week (~40 s, the anchor)

```
Pay the bills due this week
```

You get a table: four bills selected, the fifth (Trane, $11,400) left out
because it is not due yet, the batch total against the operating balance. No
money has moved and no card has appeared — that is deliberate.

```
Yes, stage them
```

**One** batch is staged: ACH for three vendors, **wire for Ironclad**, chosen
per payee from what the bank holds. The bank's card and the `/confirm` link
arrive after the sentence, not before it.

Open the link, approve with the passkey, and let the room watch the money
move. This is the beat the whole demo exists for: one approval, mixed rails,
nothing executed by the model.

## Live 3 — Can I afford the van (~25 s)

```
Can I afford the monthly payment on the van quoted in the email from Blue Springs Ford?
```

It reads the dealer's quote out of Gmail, checks the operating account against
twelve months of monthly cash, and answers **yes** in a line or two — the
$989/month against what the van replaces, netting to roughly $316/month.

Short is the feature. If someone wants the full picture — cash versus finance,
the safest month to buy, a second van — that is the next question, and the
answer arrives without re-reading anything.

---

## Saved transcript 1 — Payroll headroom

```
Am I good for payroll Friday?
```

Roughly a minute and a half of work: the payroll run sized from the
processor's own debits, the bills due by payday, the sales tax that is
collected but not yet swept, and a yes/no with the arithmetic shown. Same
terms as the sweep — [`_shared/AVAILABLE-CASH.md`](../paywhere-smb/skills/_shared/AVAILABLE-CASH.md)
— so the two never disagree.

## Saved transcript 2 — Loan application prep

```
/credit-readiness I'm going to the bank about financing the van.
```

**Type the slash command.** The skill is explicitly invoked; asking "what
should I bring to the bank" gets the van skill's short answer naming it
instead.

The deliverable is the **file** — `bank/credit-readiness-<date>.md` — sized
from the year's deepest peak-to-trough drop rather than today's balance, with
the troughs and what caused them. Show the file, not the chat.

## Saved transcript 3 — Sweep to savings (overnight)

The agent runs while nobody is watching and leaves a figure and a staged
transfer for the morning: what is safe to move to savings, net of everything
committed through the next pay cycle, the operating buffer, and the sales tax
that is not the owner's money.

The reason it shows its work is that nobody is there to ask.

> **Not yet true:** `sweep-to-savings` is currently an *interactive* beat with
> a "Stage it?" gate, not a scheduled agent. Running it overnight means
> converting it the way `tax-sweep-agent` works — the agent stages directly and
> the owner approves the proposal in the morning. Small change; not made yet.

---

## Also available, not in this cut

- **Bare connector, no plugin** (SCENARIOS §1.0) — payments work from the
  connector alone, before any skill exists. The strongest opener for a
  technical room.
- **Friday tax sweep** (3.5) — the other scheduled agent, and the most
  reliable beat in the suite. Needs `/demo-inject` first or it correctly
  stages nothing.
- **The FI seat** (SCENARIOS Act 4) — paywhere-admin's Intents screen showing
  `financing_debt` rising during the van beat. This is the part that is about
  the bank's business rather than Nick's.
- **Tax reserve check** and **daily cash brief** — both real, both currently
  parked with known defects.
