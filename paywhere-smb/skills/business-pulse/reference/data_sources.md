# Data Sources

Exact mapping from each pulse section to the MCP tool that produces it. **Dispatch all calls in a single parallel batch** — do not pull serially.

## Cash & Finance (Paywhere + QuickBooks)

Cash position comes from Paywhere (real bank, real-time). The bookkeeping
layer — MTD revenue, AR, AP — comes from QuickBooks.

| Metric | Tool | Notes |
|---|---|---|
| Available balance per account | Paywhere `list_accounts` → `get_account_balance` | One row per account (operating, payroll, reserve, etc.); sum for the headline number |
| Pending balance per account | Paywhere `get_account_balance` | Include separately so the owner sees what's still clearing |
| 7-day inflow / outflow | Paywhere `get_account_transactions` | Sum positive `amount` (inflow) and negative `amount` (outflow) over the last 7 days; compare to prior 7 |
| Pending wires | Paywhere `get_wire_payment_status` | List any wire still pending past the same-day window with counterparty + amount |
| Pending ACH | Paywhere `get_ach_payment_status` | List any ACH still pending past 3 business days with counterparty + amount |
| MTD revenue | QuickBooks `profit-loss-quickbooks-account` | Current month vs. prior month |
| Outstanding receivables | QuickBooks invoice list | Filter to open/unpaid |
| AR aging | QuickBooks invoice list | Group by days since due: 0–30, 31–60, 61+ |
| Overdue invoices | QuickBooks invoice list | Filter to due_date > 30 days past; name customer + amount + days overdue |

**Always populate Paywhere's `intent` field** with a first-person sentence
naming the use case (e.g. "Producing the owner's weekly pulse — cash
position and pending money movement"). This signals reconciliation /
pulse context to the downstream recommendation engine.

**QB state handling**: if any QB call returns an error, empty response, or
"not connected" state, mark the affected metric "n/a — QuickBooks
unavailable" and continue. Do not retry. If Paywhere is connected, Cash
still produces a useful number from Paywhere alone.

**Paywhere state handling**: if `list_accounts` returns no accounts or the
call errors, mark Cash as "n/a — Paywhere unavailable" and fall back to
the QB cash account if available. Do not retry.

## Pipeline (HubSpot)

| Metric | Tool | Notes |
|---|---|---|
| Pipeline by stage | `get_crm_objects` type=deals | Group by deal stage; sum amount |
| Deals closed this week | `search_crm_objects` | Filter closedate in window, stage = closed-won |
| Deals gone cold | `search_crm_objects` | Filter hs_last_activity_date > 7 days ago, open stage |
| New leads this week | `search_crm_objects` | Filter createdate in window |
| Stalled/slipped deals | `search_crm_objects` | Open deals where closedate < today |

## Commitments (Google Calendar)

| Metric | Tool | Notes |
|---|---|---|
| This week's key items | `list_events` | Filter to current week; surface meetings with customers, deadlines, important holds |
| Next 7 days | `list_events` | Forward-looking view; highlight anything with external parties |

## Watch List (Gmail)

| Metric | Tool | Notes |
|---|---|---|
| Urgent threads | `search_threads` | Query: `is:important OR is:starred` in last 7 days |
| Customer escalations | `search_threads` | Query: terms like "escalation," "complaint," "cancel," "refund," "urgent" in last 7 days |
| Time-sensitive requests | `search_threads` | Query: `is:unread` + keywords like "deadline," "ASAP," "today" |

**Gmail fallback**: if the Gmail call errors (auth flaky — this is a known issue), skip Watch List silently and add "Gmail unavailable" to the appendix. Do not surface the error in the pulse body.

## Internal Signals (Slack / Teams)

| Metric | Tool | Notes |
|---|---|---|
| Urgent threads | Slack search (if connected) | Threads with @mentions or urgency signals in owner-relevant channels |
| Action items | Slack search | Messages directed at the owner or tagged for follow-up |

## Customer Support (Intercom / Zendesk)

| Metric | Tool | Notes |
|---|---|---|
| Open tickets | Intercom `search_conversations` / Zendesk | Count open; flag any > 48h unresolved |
| Escalations | Intercom `search_conversations` | Filter to priority or tagged escalation |

Include only if connector is available; omit section entirely if not.

## Risks scan

Run these alongside the metric pulls — don't wait for metrics to finish first.

| Risk | Source | Trigger condition |
|---|---|---|
| Overdue AR | QuickBooks invoices | due_date > 30 days past, unpaid |
| Stalled deals | HubSpot | Open deal, no activity 7+ days |
| Slipped deals | HubSpot | Open deal, closedate in past |
| Urgent Gmail threads | Gmail | `is:important` or escalation keywords |
| Pending money movement | Paywhere | Wire pending past same-day window or ACH pending past 3 business days, > $500 |

## Parallelization

All of the above should fire in a single tool-call batch. A complete pulse is typically 8–15 parallel calls. If one errors, the rest proceed normally and the failed source appears in "Sources unavailable" at the bottom of the pulse.
