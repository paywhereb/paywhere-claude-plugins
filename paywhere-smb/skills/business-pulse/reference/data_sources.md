# Data Sources

Exact mapping from each pulse section to the MCP tool that produces it. **Dispatch all calls in a single parallel batch** — do not pull serially.

## Cash & Finance (Paywhere + QuickBooks)

Cash position comes from Paywhere (real bank, real-time). The bookkeeping
layer — MTD revenue, AR, AP — comes from QuickBooks.

| Metric | Tool | Notes |
|---|---|---|
| Core balance per account | Paywhere `list_accounts` → `get_account_balance` | One row per account (operating, reserve); sum for the headline number |
| Pending balance per account | Paywhere `get_account_balance` | Include separately so the owner sees what's still clearing |
| 7-day inflow / outflow | Paywhere `get_account_transactions` | Sum positive `amount` (inflow) and negative `amount` (outflow) over the last 7 days; compare to prior 7 |
| Pending wires | Paywhere `get_wire_payment_status` | List any wire still pending past the same-day window with counterparty + amount |
| Pending ACH | Paywhere `get_ach_payment_status` | List any ACH still pending past 3 business days with counterparty + amount |
| MTD revenue | QuickBooks `profit-loss-quickbooks-account` | Current month vs. prior month |
| Outstanding receivables | QuickBooks invoice list | Filter to open/unpaid |
| AR aging | QuickBooks invoice list | Group by days since due: 0–30, 31–60, 61+ |
| Overdue invoices | QuickBooks invoice list | Filter to due_date > 30 days past; name customer + amount + days overdue |

**QB state handling**: if any QB call returns an error, empty response, or
"not connected" state, mark the affected metric "n/a — QuickBooks
unavailable" and continue. Do not retry. If Paywhere is connected, Cash
still produces a useful number from Paywhere alone.

**Paywhere state handling**: if `list_accounts` returns no accounts or the
call errors, mark Cash as "n/a — Paywhere unavailable" and fall back to
the QB cash account if available. Do not retry.

## Watch List (Gmail)

| Metric | Tool | Notes |
|---|---|---|
| Urgent threads | `search_threads` | Query: `is:important OR is:starred` in last 7 days |
| Customer escalations | `search_threads` | Query: terms like "escalation," "complaint," "cancel," "refund," "urgent" in last 7 days |
| Time-sensitive requests | `search_threads` | Query: `is:unread` + keywords like "deadline," "ASAP," "today" |

**Gmail fallback**: if the Gmail call errors (auth flaky — this is a known issue), skip Watch List silently and add "Gmail unavailable" to the appendix. Do not surface the error in the pulse body.

## Risks scan

Run these alongside the metric pulls — don't wait for metrics to finish first.

| Risk | Source | Trigger condition |
|---|---|---|
| Overdue AR | QuickBooks invoices | due_date > 30 days past, unpaid |
| Urgent Gmail threads | Gmail | `is:important` or escalation keywords |
| Pending money movement | Paywhere | Wire pending past same-day window or ACH pending past 3 business days, > $500 |

## Parallelization

All of the above should fire in a single tool-call batch. A complete pulse is typically 6–10 parallel calls across Paywhere, QuickBooks, and Gmail. If one errors, the rest proceed normally and the failed source appears in "Sources unavailable" at the bottom of the pulse.
