# Archive

Skills that left `paywhere-smb` and the audit that decided it. Nothing here is
loaded by the plugin (the loader walks `paywhere-smb/skills/` only); it is kept
for reference and for reviving something similar later.

## 2026-09-03 — the six-call bar

[`skill-audit-2026-09-03.md`](skill-audit-2026-09-03.md) audited every skill
against three rules from the product owner: a skill must work as-is for any
typical small business; it must encode a procedure Claude cannot improvise from
the data with good tools; and a live-demo skill must finish in six tool calls
and about thirty seconds. No Excel, no static HTML.

Archived under [`skills/`](skills/), with the reason and what replaces it:

| Skill | Why | Instead |
|---|---|---|
| `what-if` | Levers over a 13-week forecast plus an Excel `Levers` sheet; the model answers arbitrary what-ifs from the data | Ask the question; the model pulls the balance, the aging and the bills |
| `business-pulse` | A summary the model composes in five calls; its only method (true available cash) moved to `tax-reserve-check/reference/true-available.md` | "How is my business doing?" as a plain question |
| `ar-health` | Aging, DSO and profiles the aged-receivables report already gives | `get_aged_receivables`; `invoice-chase` for the chase |
| `cash-flow-snapshot` | 13-week forecast whose deliverable was `models/cash-13w.xlsx` | Ask for a 13-week table; the model builds it from open invoices, bills and the payroll pattern |
| `build-cash-dashboard` | Static HTML plus two workbooks; a dashboard must be a live artifact that calls the connectors | To be rebuilt as a live artifact |
| `quarterly-review` | PDF deck with vertical-specific job-costing logic | Ask for the quarter's P&L and the top customers |
| `smb-router` | Cowork routes from skill descriptions; the router added a turn and carried demo prompts verbatim | Nothing |
| `month-end-prep` | Real reconciliation method, but over 30 s even stripped of the packet | Revive as a scheduled agent if wanted |
| `subscription-audit` | Recurring-debit detection needs one bank call grouped by counterparty, which the bank query does not offer yet | Revive when `query_transactions` gains `groupBy: "counterparty"` |

## 2026-09-04 — the bank has to be essential

A fourth rule from the product owner: if QuickBooks alone answers the
question, it is a QuickBooks demo and not worth iterating on. The Paywhere
connector must be what makes the beat possible — real balances, rails, saved
payees, or money actually moving.

| Skill | Why | Instead |
|---|---|---|
| `invoice-chase` | The bank contributes nothing: an aging report plus a ranking is a QuickBooks answer. It also fanned out to 16–19 calls per run, chasing invoices one at a time, and in two runs of three missed the deposited check that already covered an "open" invoice | `get_aged_receivables` answers "who owes me money" in one call. Revive only with a bank-side reason — matching deposits against open invoices, say — and one parallel read turn |

To revive one: copy it back under `paywhere-smb/skills/`, rewrite it to the
rules above (one parallel read turn, ≤ 6 calls, markdown only, no demo
entities), bump its `version:` and the plugin version.
