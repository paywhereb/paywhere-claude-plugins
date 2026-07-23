# Demo Kit — Seeding the Sandbox

> **No real money. No real customers. Demo connectors only.**

The demo world has two halves that seed differently:

- **The QuickBooks books** are **shared and read-only** — the QBO demo
  deployment reseeds them **server-side daily** (5am ET). Nobody seeds the
  books by hand, and no seeding tool for them exists on the connector; every
  skill reads them freely and *narrates* any bookkeeping write that would
  happen outside a demo.
- **The Paywhere bank world** is **per-runner**: each presenter seeds and owns
  an isolated mock-bank world, so **parallel demos** and **re-runs** are both
  supported.

Install the `paywhere-smb` plugin, connect the demo connectors, and run:

```
/demo-setup
```

That builds **your own** bank world for the **Meridian Staffing & Advisory
LLC** persona, scaled ~0.30× (Operating opens $40,000 → closes ≈ $23,000,
Reserve ≈ $20,000):

1. `get_demo_dates` (quickbooks, read-only) — fetches the `dateModel` the
   standing books were last seeded with. If it reports `seeded: false`, the
   daily server-side seed hasn't run yet — wait for it (or ping whoever runs
   the QBO demo deployment); nothing to do client-side.
2. `seed_demo_world {confirm:true, dateModel, username?}` (Paywhere) — resets
   your mock bank to a fresh world, pre-configures ACH/Wire recipients, seeds
   ~6 months of date-relative bank history, writes transaction enrichment,
   and returns your bank credentials. Passing the books' `dateModel` through
   is what keeps bank and books on **identical dates** (the response confirms
   with `dateModelSource: "provided"`).

The optional `username` is a friendly label folded into your generated bank
login (`demo-<label>-<uid>-gN` — sanitized to lowercase letters/digits/hyphens,
max 20 chars). It labels **your own** world only.

There are **no per-scenario setup commands** — one run readies every beat
(balances, categorize spending, transfer, investigate a charge, pay bills,
payroll crunch) plus the phase-2 getting-paid / pay-and-bill / commissions
flows. All orchestration and date math is server-side; nothing is
hand-resolved. The seeds resolve identically Monday through Friday of a given
week (the horizon is the most recent Sunday), so demos behave the same all
week. Re-running `/demo-setup` is always safe — it orphans your prior world
and builds a fresh one.

What the dataset contains (numbers, persona, recipient map, reconciliation) is
documented in [`../paywhere-smb/DATASET.md`](../paywhere-smb/DATASET.md). The
copy-paste run-of-show is in [`demo-script.md`](demo-script.md).

## Connectors

All wired in [`paywhere-smb/.mcp.json`](../paywhere-smb/.mcp.json):

- **QuickBooks** — hosted Paywhere QBO fork at `qbo.dev.paywhere.com/mcp`
  (wraps a QBO sandbox company). **Read-only**: only `get_*` / `search_*` /
  `read_*` tools are advertised, plus the read-only `get_demo_dates`. The
  books reseed server-side daily; there is nothing to seed or reset here.
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
- Google-login users who haven't seeded yet browse a **shared read-only
  backdrop** of the bank; demo-mutating tools (e.g. `deposit_to_mock_account`)
  refuse until their first `/demo-setup`, which migrates them onto their own
  world (`migratedFromSharedDemo: true` in the response).
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
authorize the connectors, run `/demo-setup` (optionally with a username
label), then walk [`demo-script.md`](demo-script.md). Several presenters can
run this in parallel — each `/demo-setup` builds its own bank world against
the same standing books. For the live "money just landed" moment mid-demo,
post a deposit with the seeder's `deposit_to_mock_account` — the seeds
themselves never depend on today's date.
