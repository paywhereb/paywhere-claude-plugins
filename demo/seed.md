# Demo Kit — Seeding the Sandbox

> **No real money. No real customers. Demo connectors only.**

Demo seeding is one skill making **two server-side calls**. Install the
`paywhere-smb` plugin, connect the demo connectors, and run:

```
/demo-setup
```

That builds the **entire** demo world — the **Meridian Staffing & Advisory LLC**
persona, scaled ~0.30× (Operating opens $40,000 → closes ≈ $23,000, Reserve
≈ $20,000) — in two calls:

1. `seed_demo_world {confirm:true}` (Paywhere) — resets the mock bank to a
   fresh world, pre-configures ACH/Wire recipients, seeds ~6 months of
   date-relative bank history, writes transaction enrichment, and returns the
   bank credentials + a **`dateModel`**.
2. `seed_demo_books {dateModel, confirm:true}` (quickbooks) — mirrors the QBO
   books on the **same dates** (the shared `dateModel` is what keeps bank and
   books aligned). No token needed.

There are **no per-scenario setup commands** anymore — one run readies every
beat (balances, categorize spending, transfer, investigate a charge, pay bills,
payroll crunch) plus the phase-2 getting-paid / pay-and-bill / commissions flows.
All orchestration and date math is server-side; nothing is hand-resolved. The
seeds resolve identically Monday through Friday of a given week (the horizon is
the most recent Sunday), so demos behave the same all week.

What the dataset contains (numbers, persona, recipient map, reconciliation) is
documented in [`../paywhere-smb/DATASET.md`](../paywhere-smb/DATASET.md). The
copy-paste run-of-show is in [`demo-script.md`](demo-script.md).

## Connectors

All wired in [`paywhere-smb/.mcp.json`](../paywhere-smb/.mcp.json):

- **QuickBooks** — hosted Paywhere QBO fork at `qbo-demo.dev.paywhere.com/mcp`
  (wraps a QBO sandbox company). The `seed_demo_books` tool needs no token — it
  is gated by `confirm:true`, like the connector's other write tools.
- **Paywhere** — hosted demo MCP at `demo.dev.paywhere.com/mcp`, backed by a
  mock bank. On demo deployments it also carries the demo-seeder tools
  (`seed_demo_world`, `reset_demo`, …) that only `/demo-setup` uses — one
  connector, one sign-in.
- **Gmail** — throwaway sandbox Google account (phase-2 "getting paid" drafts).

## Credential boundaries

- Sign in to the Paywhere connector with the demo bank credentials from
  1Password. `seed_demo_world` (like `reset_demo`) **rotates** those
  credentials: it creates a fresh mock bank user, repoints your connector
  session transparently (no re-auth), returns the new username/password in its
  response, and posts them to the demo Slack channel so 1Password can be
  updated. Mock-bank-only credentials — no real money — but keep the Slack
  channel private and 1Password current, or the next person can't sign in.
- **Re-connecting the Paywhere connector re-captures whatever credentials you
  type.** If you re-OAuth with the old (pre-reset) credentials, your session
  points back at the old world — run `/demo-setup` again.
- The QBO fork wraps a real QBO sandbox company: no real customer data, but
  don't commit its credentials.
- Never point the demo plugin at production Paywhere. The seeder tools only
  exist on demo deployments.

## Running the demo

Install in Claude Code or Cowork (Claude Desktop / claude.ai chat don't run
plugins — see [`paywhere-smb/README.md`](../paywhere-smb/README.md#installation)),
authorize the connectors, run `/demo-setup`, then walk
[`demo-script.md`](demo-script.md). For the live "money just landed" moment
mid-demo, post a deposit with the seeder's `deposit_to_mock_account` — the seeds
themselves never depend on today's date.
