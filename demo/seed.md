# Demo Kit — Seeding the Sandbox

> **No real money. No real customers. Demo connectors only.**

Demo seeding is no longer a manual document — it's a skill. Install the
`paywhere-smb` plugin, connect the demo connectors, and run:

```
/demo-setup-base
```

That resets the mock bank to a fresh world (clean accounts, no leftover
state from earlier demos) and seeds three months of consistent bank + QBO
history for the demo persona, **Meridian Staffing & Advisory LLC**. Then
layer on whichever scenario you're demoing:

| Scenario | Setup command | Demo flow it feeds |
|---|---|---|
| AP batch bill-pay (flagship) | `/demo-setup-bill-pay` | `/pay-bills` |
| Hours billing + contractor payouts | `/demo-setup-pay-and-bill` | `/pay-and-bill` |
| Commission payouts | `/demo-setup-commissions` | `/pay-commissions "last week"` |
| Payroll cash crunch | `/demo-setup-payroll-crunch` | `/plan-payroll` |

Everything the setups seed is defined by the manifests in
[`paywhere-smb/skills/demo-setup-base/seed/`](../paywhere-smb/skills/demo-setup-base/seed/)
— persona, date-token convention (the seeds resolve identically Monday
through Sunday of a given week, so demos behave the same all week), the
canonical bank manifest, and the QBO manifest. The setup skills are
idempotent and approval-gated; re-running one tops up or rebuilds rather
than duplicating.

## Connectors

All wired in [`paywhere-smb/.mcp.json`](../paywhere-smb/.mcp.json):

- **QuickBooks** — hosted Paywhere QBO fork at `qbo-demo.paywhere.com/mcp`
  (wraps a QBO sandbox company).
- **Paywhere** — hosted demo MCP at `demo.paywhere.com/mcp`, backed by a
  mock bank.
- **paywhere-mock** — the demo seeder at `demo.paywhere.com/mock-mcp`.
  Same OAuth server and the same bank sign-in as the Paywhere connector,
  but it must be **authorized separately** in the client. Only the
  `/demo-setup-*` skills use it.
- **Gmail / Google Drive** — throwaway sandbox Google account (hour-report
  notes, reminder drafts).

## Credential boundaries

- Sign in to both Paywhere connectors with the demo bank credentials from
  1Password. `reset_demo` **rotates** those credentials: it creates a fresh
  mock bank user, repoints your connector session transparently (no
  re-auth), returns the new username/password in its response, and posts
  them to the demo Slack channel so 1Password can be updated. They are
  mock-bank-only credentials — no real money — but keep the Slack channel
  private and keep 1Password current, or the next person can't sign in.
- **Re-connecting the Paywhere connector re-captures whatever credentials
  you type.** If you re-OAuth with the old (pre-reset) credentials, your
  session points back at the old world — run `/demo-setup-base` again.
- The QBO fork wraps a real QBO sandbox company: no real customer data,
  but don't commit its credentials.
- Never point the demo plugin at production Paywhere. The seeder surface
  (`/mock-mcp`) only exists on demo deployments.

## Running the demo

Install in Claude Code or Cowork (Claude Desktop / claude.ai chat don't run
plugins — see [`paywhere-smb/README.md`](../paywhere-smb/README.md#installation)),
authorize the connectors, run `/demo-setup-base`, then a scenario setup,
then its demo flow. For a live "money just landed" moment mid-demo, post a
deposit with the seeder's `deposit_to_mock_account` — the seeds themselves
never depend on today's date.
