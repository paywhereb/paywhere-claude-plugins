---
name: demo-inject
version: 1.0.2
description: >
  PRESENTER-ONLY, demo deployments only. Posts live "money just landed" or
  "payment bounced" events into the presenter's own mock-bank world with the
  demo-seeder tools (deposit_to_mock_account, withdraw_from_mock_account) so
  the next owner prompt sees them: simulate a late customer paying, an
  emergency-call card settlement, a failed autopay. Reads the amounts from the
  live answer key; never hardcodes them. Not an owner skill. Use when the
  presenter says "inject a deposit," "simulate a customer paying," "simulate
  Westport paying," "post a demo deposit," "make the autopay fail," "demo
  inject," or "live inject."
---

# Demo Inject (presenter)

Mid-demo drama, triggered from chat over MCP rather than a script. The
seeder tools post **immediately** and **permanently** to the presenter's own
world; the next balance or AR check sees the change. To undo, re-run
`/demo-setup` (it rebuilds a fresh generation).

## Guard — run only against your own demo world

1. The Paywhere connector's tool list must include `deposit_to_mock_account`
   / `get_demo_world`. Absent → not a demo deployment → **stop**.
2. `get_demo_world` must return `sharedEnvWorld: false` and a `seedJob` that
   is `null` or `state: "done"`. `sharedEnvWorld: true` → the presenter is on
   the shared backdrop → stop and run `/demo-setup` first. A running seed →
   wait for it.
3. Resolve the **Operating** account via `list_accounts` (primary checking)
   — never a hardcoded number.

**Progress tracking:** call `TaskCreate` once per step below before starting
(subject = the step's name, e.g. "1. Guard"), then `TaskUpdate` to
`in_progress` / `completed` as you go — it drives Cowork's progress display.

## Read the live world first

`get_demo_world` → `answerKeySummary` (when present) supplies the numbers:
`ar.largestOverdue {customer, amount, invoiceRef}`,
`liveSurface.overdueInvoices[]` (sorted by days past due — the largest
amount is `ar.largestOverdue`, not `[0]`), `liveSurface.unbookedCheck`,
`liveSurface.billsDueThisWeek[]`, `trueAvailable`. The summary does **not**
carry `settlements.*`; the failed-autopay customer and amount
(`settlements.failedAutopay` in the full key) are read from the books
instead — `search_invoices` for that customer's current agreement invoice.
If the summary is absent, read the same facts through the owner's tools
(`get_aged_receivables` for the largest overdue) or ask the presenter for
the amount. **Never invent an amount.**

## Ready injects (copy-paste prompts)

Each block: the presenter prompt (calls the seeder), what changes in the
answer key, then the owner-voice follow-up to paste.

### (a) "Westport just paid" — the largest overdue customer pays

> *Example uses the roster's largest overdue customer; read the real one
> from `ar.largestOverdue`.*

```
Using the demo-seeder deposit tool, post a deposit into my Operating Checking
for the amount of my largest overdue invoice, with statement description
"ACH CR <the customer's AP descriptor, e.g. AVIDXCHANGE CORNERSTONE PM>" —
simulating <customer> paying.
```

Changes: `ar.largestOverdue` disappears from the chase list on the next run
(the credit now matches the open invoice → "received, not yet booked");
`trueAvailable` rises by the amount; payroll headroom rises by the same. The
books still show the invoice open (read-only) — the agent should say so.

Owner follow-up:
```
Westport just paid — check again
```
(or "am I good for payroll now?")

### (b) "Emergency call invoice" — a Saturday compressor swap gets paid by card

An invoice is a books event and the demo books are read-only, so inject the
**cash side**: the card settlement.

```
Using the demo-seeder deposit tool, post a deposit into my Operating Checking
for $<amount, e.g. the emergency job the owner just described, net of a
2.99% + $0.30 card fee> with statement description
"INTUIT PYMT SOLN DEPOSIT" — simulating today's card settlement for an
emergency call.
```

Changes: `trueAvailable` rises; the next `month-end-prep` /
`settlement-reconcile` shows one more settlement with **no QBO deposit** to
match (narrate: "outside a demo the invoice, payment and deposit would be
booked"). Nothing in AR changes.

Owner follow-up:
```
I did an emergency call this morning and they paid by card — did it land?
```

### (c) "Blue Line autopay failed" — a card autopay bounces

```
Using the demo-seeder withdraw tool, post a withdrawal from my Operating
Checking for $<the customer's agreement amount> with statement description
"INTUIT PYMT SOLN RETURN <CUSTOMER>" — simulating the merchant processor
reversing a failed card autopay.
```

Changes: `trueAvailable` falls by the amount; the customer's current
agreement invoice is now effectively unpaid even if the books show a
payment (narrate the reversal). The full answer key's
`settlements.failedAutopay` records the seeded failure; the injected one is
visible only at the bank.

Owner follow-up:
```
Did Blue Line's payment go through?
```

### (d) Not injectable: a pending card authorization

The seeder posts **posted** rows only; a `pending` authorization cannot be
injected live. The seeded world already carries a few pending
authorizations in the current week — point at those instead.

## Other useful injects

- **A bill's debit** (to make `pay-bills` surface a "potential duplicate"):
  withdraw the bill's amount with `ACH DEBIT <VENDOR>`. Changes:
  `trueAvailable` falls; the next pay-bills run flags the bill.
- **A wire in** for a project milestone: deposit with `WIRE IN <CUSTOMER>`
  and a second withdrawal of the bank's inbound wire fee with
  `WIRE FEE IN`.

## Rules

- Presenter-only; never offer this to an owner voice.
- Read amounts from the live world; never fabricate.
- State every time: "this is permanent for this world; `/demo-setup`
  resets it."
- The owner-voice follow-up is a separate prompt — the inject itself is not
  an owner action and must not be narrated as one.
- Injects never touch QuickBooks; say what the books would show.
