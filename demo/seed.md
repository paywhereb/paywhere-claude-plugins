# Demo Kit — Seeding the Sandbox

> **No real money. No real customers. Demo connectors only.**

The demo world has four sources that seed differently:

- **QuickBooks books** — **shared and read-only**; the QBO demo deployment
  reseeds them **server-side daily** (5am ET) from the same world module.
  Nobody seeds the books by hand; skills read them and *narrate* any write.
- **Paywhere bank world** — **per presenter**: `/demo-setup` seeds an isolated
  mock-bank world for the caller, so parallel demos and re-runs work.
- **Gmail + Google Calendar** — the shared `demo-nick@paywhere.com` account,
  seeded by `paywhere-qbo-mcp/scripts/seed-google.mjs` (manual before a demo
  week, nightly later) with dates relative to the same date model.

Install `paywhere-smb`, connect the connectors, and run:

```
/demo-setup
```

That builds **your own** bank world for the **Nick's HVAC LLC** persona
(three accounts: Operating Checking opens at a per-window calibrated figure
so the year's low is exactly $14,000 — ≈ $44k for a September start; Tax
Reserve opens $3,200 and Business Savings $12,000; 12 months + the current
month; ≈ 1,000 rows; ≈ 30 saved payees; enrichment):

1. Preflight — the seeder tools are present on the Paywhere connector;
   `get_demo_dates` (quickbooks, read-only) returns the standing books'
   `dateModel`. `seeded: false` ⇒ wait for the daily reseed.
2. Approval gate, then `seed_demo_world {confirm:true, dateModel, username?}`
   — **asynchronous**: it resets your mock bank, writes payees and
   enrichment, returns credentials + `expectedClosing` + `answerKeySummary`
   at once, and posts the rows in a background job.
3. The skill polls `get_demo_world` (`seedJob.state/posted/total/etaSeconds`)
   every ~20 s, ≈ 4–6 minutes, with Cowork progress.
4. Readback through the connector: balances == `expectedClosing`; saved
   payees == `recipientsConfigured` (wire/ACH spot-check); enrichment on the
   recurring debit; the unbooked check found.
5. Report: credentials, balances, the answer-key summary (true available,
   reserve shortfall, largest overdue, bills due this week, Friday payroll),
   beats ready, and a pointer to [`SCENARIOS.md`](SCENARIOS.md).

The optional `username` is a label folded into your generated bank login
(`demo-<label>-<uid>-gN`). Re-running `/demo-setup` is always safe — it
orphans your prior world and builds a fresh one (do this after rehearsing
with live injects).

What the dataset contains is documented in
[`../paywhere-smb/DATASET.md`](../paywhere-smb/DATASET.md). The run-of-show
is [`SCENARIOS.md`](SCENARIOS.md); setup and troubleshooting are in
[`presenter-kit.md`](presenter-kit.md).

## Connectors

All wired in [`paywhere-smb/.mcp.json`](../paywhere-smb/.mcp.json):

- **quickbooks** — hosted Paywhere QBO fork at `qbo.dev.paywhere.com/mcp`
  over a QBO sandbox company. **Read-only**; plus `get_demo_dates`.
- **Paywhere** — hosted demo MCP at `demo.dev.paywhere.com/mcp`, backed by
  the mock bank; carries the demo-seeder tools (`seed_demo_world`,
  `get_demo_world`, `deposit_to_mock_account`, `withdraw_from_mock_account`,
  `seed_transactions`) used by `/demo-setup` and `demo-inject`. Propose-only
  sends are on: payment tools stage a `/confirm` proposal.
- **gmail** and **google calendar** — Google's MCP servers, signed in as
  `demo-nick@paywhere.com`. Drafts only; no Google Drive.

## Credential boundaries

- `seed_demo_world` **rotates** the bank credentials: a fresh mock bank user,
  the connector session repointed transparently, the new username/password
  in the response (and posted to the demo Slack channel for 1Password).
  Mock-only credentials — but keep them current or the next presenter can't
  sign in.
- Google-login users who haven't seeded browse a **shared read-only
  backdrop**; demo-mutating tools refuse until their first `/demo-setup`
  (`migratedFromSharedDemo: true`).
- **Re-connecting the Paywhere connector re-captures whatever credentials you
  type.** Old credentials ⇒ old world ⇒ balances won't match. Re-run
  `/demo-setup`.
- The QBO fork wraps a real sandbox company: no real customer data, but don't
  commit its credentials. The Google seed token stays in 1Password / Secrets
  Manager; the user-facing MCP servers never hold it.
- Never point the demo plugin at production Paywhere; the seeder tools only
  exist on demo deployments.

## Running the demo

Install in Cowork (side-load) or Claude Code, authorize the connectors, run
`/demo-setup`, pre-run the two scheduled agents, then walk
[`SCENARIOS.md`](SCENARIOS.md). For the live "money just landed" moment use
`demo-inject`'s ready prompts (they call `deposit_to_mock_account` on the
Paywhere connector; posted immediately). Injects are permanent for the
world — re-run `/demo-setup` afterwards.
