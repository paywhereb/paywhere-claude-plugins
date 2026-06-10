---
name: business-pulse
description: >
  Produces a one-page financial snapshot for SMB owners — cash position
  (Paywhere + QuickBooks), sales/revenue trend (QuickBooks), pending money
  movement (Paywhere wires/ACH), urgent watch-list items (Gmail), and the
  single most important thing needing attention today. Proactively tries
  every available connector and gracefully scopes to whatever is connected —
  one connector gives a partial pulse; the full stack gives the full
  picture. Trigger when the user asks how the business is doing, wants a
  snapshot, a weekly summary, a Monday brief, or says anything like "what am
  I missing" or "catch me up on the business."
---

# Business Pulse

One prompt, one page. Pull live data from every connected tool, synthesize it into a single scannable brief, and surface the single most important thing to act on today. Do the work — don't ask the user to help find the data.

## Step 1 — Pull data in parallel

**Dispatch all connector calls in a single parallel batch** — see `reference/data_sources.md` for the exact tool-to-metric mapping. Do not pull serially; latency turns a 30-second skill into a painful wait.

Connectors to attempt simultaneously:

- **QuickBooks** — MTD revenue, outstanding receivables, overdue invoices, P&L trend
- **Paywhere** — bank balances across accounts (`list_accounts` →
  `get_account_balance`), 7-day inflow/outflow (`get_account_transactions`),
  pending wires/ACH (`get_wire_payment_status`,
  `get_ach_payment_status`). Set `intent` to "Producing the owner's weekly
  pulse — cash position and pending money movement."
- **Gmail** — threads flagged urgent, customer complaints, time-sensitive requests

If a connector errors or returns no data, record it internally and move on. Never block the pulse on a single bad integration.

**QuickBooks fallback**: if QBO returns an unexpected state (account not connected, sync pending, empty response), mark the Cash section "n/a — QuickBooks unavailable" and proceed. Do not retry or ask the user to reconnect.

**Gmail fallback**: Gmail auth is intermittently flaky. If the call errors, skip the Watch List section silently and note "Gmail unavailable" in the appendix — do not surface an error mid-pulse.

## Step 2 — Compute metrics

Read `reference/thresholds.md` for red/yellow/green cutoffs. Compute:

- **AR aging** — open QuickBooks invoices grouped by days since due date (0–30, 31–60, 61+)
- **Revenue trend** — this month's QBO revenue vs. prior month; supplement with Paywhere 7-day inflow vs. prior 7-day inflow when available (real cash, not booked revenue)
- **Cash position** — sum of available Paywhere balances across accounts plus QB cash account; show as a single number with a per-account breakdown in the appendix

Assign a 🟢/🟡/🔴 status to each section. If a source returned nothing, mark the metric "n/a" and note it in the appendix.

## Step 3 — Flag risks proactively

Scan for actionable items. Every risk entry must name a specific record and a next step — "some overdue invoices" is useless; "$3,400 from Acme Corp, 47 days overdue, no response since Mar 12" is actionable.

- QuickBooks invoices past due > 30 days — name customer, amount, days overdue
- Gmail threads marked urgent or containing "escalation," "complaint," "cancel," "refund"
- Pending wire/ACH > $500 still unsettled past the expected clearing window — pull pending payment ids from Paywhere and poll `get_wire_payment_status` / `get_ach_payment_status`. Flag with counterparty (from `description`), amount, and days outstanding past the expected window (wire same-day, ACH 1–3 business days).

## Step 4 — Compose the output

Use the exact template in `reference/output_template.md`. Include only sections where real data exists — omit headers for connectors that weren't available. Adapt depth to context: a casual "how are we doing" gets a fuller report; "quick snapshot before a call" gets a tighter one.

Cross-connector synthesis is where this skill earns its keep. If a Gmail thread about a late payment connects to an overdue QuickBooks invoice and a missing Paywhere credit, surface that link in the #1 Priority section. Synthesis is what makes the pulse more useful than checking each tool separately.

Writing rules:
- Numbers lead, words follow. Never write "revenue is healthy" — write "$43k this month, ▲ 8% MoM" and let the owner judge.
- Every number carries a delta vs. the prior period where available. Absolute snapshots (cash balance) still show WoW delta.
- Names and dollars, not adjectives. "$4,200 from Acme, 23 days overdue" beats "some concerning receivables."
- No filler. If a section has nothing worth reporting, write "No material changes" and move on.

## Step 5 — Export and share (once)

After presenting the pulse, offer once:
- "Want me to save this as a file?" (use Google Drive if available)

If they say yes, save it with a dated filename `business-pulse-YYYY-MM-DD.md` to the owner's drive root (or `~/Desktop/` if they prefer local; honor a `--save-to files|desktop|both` argument if given). If they say no or don't respond, move on — don't ask again.

### Weekly cadence / "Monday brief"

This pulse doubles as the weekly check-in. When the owner asks for a "Monday brief," "weekly check-in," or "start of week," run the full pulse, expand the **#1 Priority** into the **top 3 things that need them this week** (ranked), and save a dated file as above. The owner can schedule it via Cowork's task scheduler — run Monday at 7am ET, the brief lands in their drive automatically.

## Scope variants

The owner may ask for a narrower cut:

- **"Just cash" / "financial check"** → only Cash & Finance + AR-related risks
- **"Revenue only" / "sales check"** → only Revenue & Sales section + revenue-trend risks
- **"Watch list" / "anything urgent"** → only Watch List + all risks, no metric sections
- **"Quick snapshot before a call"** → TL;DR + #1 Priority only, no full sections

## What not to do

- **Do not ask permission before pulling data.** If the skill was invoked, run it. Asking "should I check QuickBooks?" defeats the whole point.
- **Do not invent or estimate numbers.** If a source returned nothing, say "n/a" explicitly. Never fill a gap with guesswork.
- **Do not skip the delta.** A number without a comparison is a missed insight. If there's no prior-period baseline, say "(no prior baseline)" rather than omitting the field.
- **Do not surface connector errors mid-pulse.** Log them to the appendix. The pulse leads with what was delivered.

## Reference files

- `reference/data_sources.md` — exact connector tool → metric mapping with fallbacks
- `reference/thresholds.md` — 🟢/🟡/🔴 cutoffs, tunable per owner
- `reference/output_template.md` — exact markdown structure; do not deviate
- `reference/gotchas.md` — known failure modes (QB states, Gmail auth, asking permission)
