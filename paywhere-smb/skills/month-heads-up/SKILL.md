---
name: month-heads-up
description: Runs on the 25th — shows the next 30-day cash-flow outlook and flags anything that needs attention before month-end. Accepts optional 30 or 60 day horizon.
allowed-tools: Read, WebFetch, Bash
---

Run the month-end heads-up. Pull forward-looking cash data and give the owner a clear "here's what the next 30 days look like" picture with specific things to watch.

Parse arguments:
- `--horizon` (default: `30`) — forecast window in days (`30` or `60`)

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Current cash position"),
then `TaskUpdate` it to `in_progress` when you begin that step and
`completed` when it's done. This is what drives Cowork's visible progress
display — it does not happen unless you do it explicitly.

## Step 1 — Current cash position

Using the `cash-flow-snapshot` skill workflow:

1. Pull Paywhere available + pending balances across every account (`list_accounts` → `get_account_balance`).
2. Pull QuickBooks receivables balance.
3. Combine for total available cash + incoming receivables.

## Step 2 — Upcoming obligations

1. Pull recurring expenses from QuickBooks (payroll, subscriptions, rent/lease) due in the next 30 days.
2. Pull any outstanding invoices past due or due within 14 days.
3. Flag any payment that would push the balance below a comfortable buffer (default: <$2,000 or owner's QB average monthly expense × 0.5).

## Step 3 — Cash-flow forecast

1. Project 30-day net cash: current balance + expected inflows − known obligations.
2. Identify the single tightest week (lowest projected balance).
3. Flag if any week projects negative.

## Step 4 — Two things to watch

Surface no more than two specific, actionable watches:
- Which invoice(s) to chase now
- Which expense(s) to defer or negotiate

Format as:

```
Month-End Heads Up — {current date}
Horizon: next {X} days

Cash today: ${amount}
Projected end-of-period: ${amount}
Tightest week: {date range} — projected ${amount}

TWO THINGS TO WATCH
1. {item} — {why it matters} — suggested action: {action}
2. {item} — {why it matters} — suggested action: {action}
```

## Connector failures

If QuickBooks is unreachable, stop — the cash forecast requires QB as the books-side source of truth. If Paywhere is missing, run the forecast from QB-only data and note "Paywhere not connected — real-time bank balance excluded from forecast; using QB cash account as proxy."

## Approval gates

- **Never initiate payments or send emails automatically.** Surface the data and actions for the owner to take.
- **Never project revenue that hasn't been confirmed in QB.** Use conservative estimates only.

## Output

Present the formatted brief and offer to draft chase emails for any flagged overdue invoices.
