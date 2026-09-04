---
name: credit-readiness
version: 1.0.3
description: >
  Answers "what should I bring to the bank" with one markdown one-pager built
  from cleared cash: twelve month-end balances of the operating account
  derived from the bank's monthly aggregates, the three troughs and what
  caused them, the deepest peak-to-trough drop as the working-capital gap, a
  line of credit sized from that gap (gap times 1.25, rounded up to $5k), the
  repayment source, the receivables and the books' P&L and balance sheet the
  lender will ask for, and the lender's own document checklist read from the
  email thread. Six read calls in one parallel turn, then one file:
  bank/credit-readiness-YYYY-MM-DD.md, and nothing else. Read-only, stages
  nothing. Use when the owner says "what should I bring to the bank,"
  "prepare a package for the bank," "how much credit do I need," "what's my
  working capital gap," "would a line of credit have helped," or "when am I
  most likely short." NOT for "can I afford this purchase" — that
  is big-purchase-decision, which hands the bank meeting here.
---

# Credit Readiness

A lender reconstructs the year from statements; this skill hands it over
already assembled, from the bank's cleared transactions and the books' open
items. Six reads in one turn, one markdown page, under half a minute.
Nothing here moves money or writes to the books.

**Answer the question first.** The first two lines of the reply are the
sized request and the gap that sizes it. The file carries the rest.

**Progress tracking:** call `TaskCreate` once per step below before starting
Step 1 (subject = the step's name, e.g. "Step 1 — Read everything"), then
`TaskUpdate` it to `in_progress` when you begin that step and `completed`
when it's done. This is what drives Cowork's visible progress display — it
does not happen unless you do it explicitly.

## Quick start — six reads, one file

```
User: "what should I bring to the bank?"
→ In ONE turn, in parallel:
    list_accounts                                                                     (Operating by role, today's balance)
    query_transactions {accountNumbers:[Operating], aggregate:true, groupBy:"month",
                        dateFrom:<first day of the month 12 months ago>}             (twelve monthly nets)
    get_aged_receivables                                                              (what is collectible, and how old)
    get_profit_and_loss {trailing 12 months}                                          (revenue, net income)
    get_balance_sheet                                                                 (assets, liabilities, equity, existing debt)
    search_threads (Gmail) "term sheet OR documents requested OR line of credit"      (the lender's thread: what they asked for)
→ Compute month-ends, troughs, gap, request (below).
→ write_file bank/credit-readiness-YYYY-MM-DD.md
→ Reply: the request in two lines, the file path, the checklist gaps.
```

Six calls, all issued together. No calendar call (the meeting date, if any,
is in the lender's mail — or ask), no per-month row pulls, no forecast. If
the owner came from [`../big-purchase-decision`](../big-purchase-decision/SKILL.md)
("what should I bring to the bank?"), reuse its month-ends rather than
re-deriving them and reuse the purchase price and terms as the request's
purpose.

## Step 1 — Read everything in ONE turn

1. `list_accounts` → **Operating** (primary checking, by role, never by
   number). Tax Reserve and Business Savings are reported for context and
   excluded from the gap math: one holds customers' sales tax, the other is
   the owner's cushion.
2. `query_transactions {accountNumbers: [Operating], aggregate: true,
   groupBy: "month", dateFrom: <first day of the month 12 months ago>}` →
   per month `{count, sumCredits, sumDebits, net}`. If the result is flagged
   truncated, say so in the file and use the months returned.
3. `get_aged_receivables` → open invoices by bucket. Current + 1–30 days is
   the near-term repayment source; anything older is a collection question,
   not collateral.
4. `get_profit_and_loss` for the trailing 12 months → revenue, gross margin,
   net income. The lender reads this next to the cash picture.
5. `get_balance_sheet` → cash, receivables, existing loans and lines (the
   debt schedule the lender will ask about), equity.
6. Gmail `search_threads` once, with the lender's name if the owner gave it,
   else "term sheet", "documents requested", "line of credit". Take the
   document checklist and any deadline from the hit's snippet; call
   `get_thread` only if the snippet does not carry the list (that is a
   seventh call — say so). No hit → use the typical checklist below and
   label it "typical; replace with the lender's list".

## Step 2 — Compute

```
month_end[m]  = today's Operating balance − Σ net[k] for every month k after m
                (walk backwards from today; the current partial month is not a month-end)
troughs       = the three lowest month_end values, with their months
peak→trough   = for each trough, the highest month_end before it minus the trough
gap           = the deepest peak→trough drop, floor 0        (the working-capital gap)
request       = ceil(gap × 1.25 / 5000) × 5000                (line of credit, rounded up to $5k)
repayment     = average net of the three strongest months (from the same aggregates)
                + receivables current and 1–30 days (from the aging)
```

- Name the **mechanism** behind each trough only when the aggregates make it
  obvious (debits far above the monthly norm, a month with almost no
  credits). Do not pull the month's rows to find out; say "cause not
  determined from monthly totals" instead.
- If the gap is zero (cash only rose), say a line of credit is not
  indicated by the last twelve months and size nothing; the page still
  carries the twelve month-ends the lender asked for.
- Never fill a rate, fee or covenant from general knowledge; those come from
  the lender's term sheet or are left blank.

## Step 3 — Write `bank/credit-readiness-YYYY-MM-DD.md` (`write_file`, markdown)

One file, one page, these sections in order:

```
# Credit readiness — {business name from the books} — {date}

## Business snapshot
{Legal name, what it does (owner-stated), years operating if known} · Revenue (trailing 12 mo) ${rev} · Net income ${ni} · Cash today ${operating} (Operating)
Existing debt: {loans / lines from the balance sheet, or "none on the balance sheet"}

## Twelve month-ends (Operating, from cleared bank transactions)
| Month | Credits | Debits | Net | Month-end |
| {Mon YYYY} | ${c} | ${d} | ${n} | ${me} |
… twelve rows, oldest first …

## Troughs
| Month | Month-end | Peak before | Drop | Likely cause |
| {Mon} | ${me} | ${peak} ({Mon}) | ${drop} | {mechanism, or "not determined from monthly totals"} |
… three rows …

## Request
Working-capital gap ${gap} (deepest peak-to-trough drop, {Mon} → {Mon}).
Requested: ${request} revolving line of credit — gap × 1.25, rounded up to $5,000.
Purpose: {seasonal working capital / vendor timing / the purchase, if the owner named one}.
Repayment source: strongest three months average ${avg}/mo net; receivables current–30 days ${ar}.

## Receivables
Total open ${total} · Current ${a} · 1–30 ${b} · 31–60 ${c} · 61–90 ${d} · 90+ ${e}

## Documents the lender asked for
- [x] Twelve months of bank activity — this page (statements from the bank's site)
- [ ] {each item from the lender's thread, with "ready" / "owner to supply"}
(or the typical list: 2 years of business tax returns, YTD P&L and balance sheet, AR aging, debt schedule, owner's personal financial statement — labelled typical)

Prepared from cleared bank transactions and open items in the books; not financial advice.
```

Tell the owner the file path. Do not email or share it; the owner brings it
to the meeting.

## Step 4 — Reply (under ~12 lines)

```
Request: ${request} line of credit — the deepest drop in the last twelve months was ${gap} ({Mon} ${peak} → {Mon} ${trough}).
Repayment: the strongest three months net ${avg}/mo; ${ar} of receivables is current or under 30 days.
Written: bank/credit-readiness-{date}.md
Troughs: {Mon} ${a} · {Mon} ${b} · {Mon} ${c}
Lender asked for: {n} items — {m} ready in the page, {k} for you to supply: {list}.
Not financial advice — the lender applies its own underwriting.
```

Say once what only the bank supplied: the real month-ends and the drop,
which the P&L cannot show.

## Follow-ups this skill expects

| Owner says | Do |
|---|---|
| "How much credit do I need?" | The request line and the gap that sizes it. |
| "Would a line of credit have helped?" | For each trough: the draw needed to stay at the pre-drop level and the months until net inflows would have repaid it (from the same aggregates). |
| "When am I most likely short?" | The three trough months, with balances. |
| "Can I afford the purchase instead?" | Hand off to [`../big-purchase-decision`](../big-purchase-decision/SKILL.md). |
| "The lender wants a forecast" | Not part of this page; offer the twelve month-ends as the trend and say a forecast is the owner's call. |

## Degraded modes

| Missing | Effect |
|---|---|
| Paywhere | Stop — there is no cleared-cash basis for a credit request. |
| quickbooks | Bank-only page: month-ends, troughs, gap and request; the snapshot, receivables and financial-statement sections read "QuickBooks unavailable — supply the P&L, balance sheet and AR aging from the books". |
| gmail | No lender checklist; use the typical list, labelled, and ask the owner what the lender requested. |

## Guardrails

- Read-only. Never stages a payment or transfer; never writes to the books.
- One markdown file and nothing else — no second file of any format.
- Never invent a rate, fee, covenant, tax figure or a document the lender
  did not ask for; label the typical checklist as typical.
- Generic wording — any lender, any business; no industry assumptions.
- Close every output with: "Prepared from cleared bank transactions and open
  items in the books; not financial advice."
