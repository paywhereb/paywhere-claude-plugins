---
name: demo-inject
version: 2.0.1
disable-model-invocation: true
description: >
  PRESENTER-ONLY, demo deployments only. Prepares live "money just landed" or
  "payment bounced" events for the presenter to post into their own mock-bank
  world from the Paywhere demo seeder page (Live inject), so the next owner
  prompt sees them: simulate a late customer paying, an emergency-call card
  settlement, a failed autopay. Reads the amounts from the live world; never
  hardcodes them. Not an owner skill. Use when the presenter says "inject a
  deposit," "simulate a customer paying," "simulate Westport paying," "post a
  demo deposit," "make the autopay fail," "demo inject," or "live inject."
---

# Demo Inject (presenter)

Mid-demo drama. The **Paywhere demo seeder page** posts the transaction (its
**Live inject** section); this skill works out exactly what to post, from the
live world, and the owner-voice follow-up to paste afterwards. The MCP server
has no inject tools. A posted row is **immediate and permanent** for the
presenter's world; the next balance or AR check sees it. To undo, rebuild the
world (`/demo-setup`).

**The seeder page:** `https://paywhere-demo-seeder.poc.dev.paywhere.com`.

**Progress tracking:** call `TaskCreate` once for each of the four phases
below ("1. Read the live world", "2. Guard", "3. Inject", "4. Confirm")
before starting the first, then `TaskUpdate` each to `in_progress` when you
begin it and `completed` when it is done. It drives Cowork's progress display
and does not happen unless you do it explicitly.

## 1. Read the live world first

The **setup summary** the presenter pasted for `/demo-setup` in this
conversation (or pastes now, from the page's "Copy setup summary for
/demo-setup") carries `accounts[]`, `dateModel` and
`answerKeySummary`: `ar.largestOverdue {customer, amount, invoiceRef}`,
`liveSurface.overdueInvoices[]` (sorted by days past due; the largest amount
is `ar.largestOverdue`, not `[0]`), `liveSurface.unbookedCheck`,
`liveSurface.billsDueThisWeek[]`, `trueAvailable`. The summary does **not**
carry `settlements.*`; the failed-autopay customer and amount are read from
the books instead (`search_invoices` for that customer's current agreement
invoice). Without the summary, read the same facts through the owner's tools
(`get_aged_receivables` for the largest overdue) or ask the presenter for the
amount. **Never invent an amount.**

The summary is a snapshot from the build: it does **not** reflect injects
posted since. Keep a list of the injects posted in this conversation and
never repeat one for the same customer (the books are read-only, so the
largest overdue invoice stays "overdue" in QuickBooks after (a); posting (a)
twice credits the customer twice).

## 2. Guard: only against the presenter's own built world

1. The page shows the world **ready** (Live inject is greyed out until then).
2. The Paywhere connector is signed in with that world's demo login:
   `list_accounts` shows the summary's `accounts[]` numbers. A mismatch →
   stop; the presenter reconnects with the page's login.

## 3. Inject: the ready injects

Each block: what the presenter enters in **Live inject** on the seeder page,
what changes in the answer key, then the owner-voice follow-up to paste.
Show the values as a short table the presenter can copy field by field. The
page asks for confirmation before it posts. **Post date** is always the
world's `dateModel.today` from the summary (normally today; the page fills
in the presenter's local date, so change it only if they differ).

### (a) "Westport just paid": the largest overdue customer pays

The page has a one-click preset for this: **Preset: <customer> pays $…**
fills the form from the world's largest overdue invoice. Otherwise:

| Field | Value |
|---|---|
| Account | Operating Checking |
| Direction | Money in |
| Type | Transfer |
| Amount | `ar.largestOverdue.amount` |
| Statement description | `ACH CR <the customer's AP descriptor, e.g. AVIDXCHANGE CORNERSTONE PM>` |

Changes: `ar.largestOverdue` disappears from the chase list on the next run
(the credit now matches the open invoice → "received, not yet booked");
`trueAvailable` rises by the amount; payroll headroom rises by the same. The
books still show the invoice open (read-only); the agent should say so.

Owner follow-up:
```
Westport just paid — check again
```
(or "am I good for payroll now?")

### (b) "Emergency call invoice": a Saturday compressor swap gets paid by card

An invoice is a books event and the demo books are read-only, so inject the
**cash side**: the card settlement.

| Field | Value |
|---|---|
| Account | Operating Checking |
| Direction | Money in |
| Type | Transfer |
| Amount | the emergency job the owner just described, net of a 2.99% + $0.30 card fee |
| Statement description | `INTUIT PYMT SOLN DEPOSIT` |

Changes: `trueAvailable` rises; the next `month-end-prep` /
`settlement-reconcile` shows one more settlement with **no QBO deposit** to
match (narrate: "outside a demo the invoice, payment and deposit would be
booked"). Nothing in AR changes.

Owner follow-up:
```
I did an emergency call this morning and they paid by card — did it land?
```

### (c) "Blue Line autopay failed": a card autopay bounces

| Field | Value |
|---|---|
| Account | Operating Checking |
| Direction | Money out |
| Type | Transfer |
| Amount | the customer's agreement amount |
| Statement description | `INTUIT PYMT SOLN RETURN <CUSTOMER>` |

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

Live inject posts **posted** rows only; a `pending` authorization cannot be
injected live. The seeded world already carries a few pending
authorizations in the current week; point at those instead.

## Other useful injects

- **A bill's debit** (to make `pay-bills` surface a "potential duplicate"):
  money out of Operating for the bill's amount with `ACH DEBIT <VENDOR>`.
  Changes: `trueAvailable` falls; the next pay-bills run flags the bill.
- **A wire in** for a project milestone: money in with `WIRE IN <CUSTOMER>`,
  then a second, money-out row for the bank's inbound wire fee with
  `WIRE FEE IN`.

## 4. Confirm

After the presenter posts, read it back on the connector before the owner
follow-up: `query_transactions {descriptionContains: <the statement
description>, dateFrom: <dateModel.today>}` shows the row. If it is missing, the page
showed an error; read it out and stop.

## Rules

- Presenter-only; never offer this to an owner voice.
- Read amounts from the live world; never fabricate.
- State every time: "this is permanent for this world; a rebuild on the
  seeder page resets it."
- The owner-voice follow-up is a separate prompt; the inject itself is not
  an owner action and must not be narrated as one.
- Injects never touch QuickBooks; say what the books would show.
