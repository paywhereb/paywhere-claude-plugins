# Presenter kit — Nick's HVAC demo

Everything the presenter needs that is not a prompt. Prompts are in
[`SCENARIOS.md`](SCENARIOS.md). Data is in
[`../paywhere-smb/DATASET.md`](../paywhere-smb/DATASET.md).

## 1. Accounts and connectors

| Connector | What it is | Sign in as |
|---|---|---|
| **Paywhere** (`https://demo.dev.paywhere.com/mcp`) | The demo bank via the Paywhere MCP; carries the demo-seeder tools | The bank user `/demo-setup` returns (rotates per run; also posted to the demo Slack channel and kept in 1Password) |
| **quickbooks** (`https://qbo.dev.paywhere.com/mcp`) | Custom, read-only QBO MCP over the shared sandbox company; reseeds daily 5am ET | QBO sandbox OAuth (1Password) |
| **gmail** (`https://gmailmcp.googleapis.com/mcp/v1`) | Google's Gmail MCP | **demo-nick@paywhere.com** ("Nick Adler (Nick's HVAC)") |
| **google calendar** (`https://calendarmcp.googleapis.com/mcp/v1`) | Google's Calendar MCP | demo-nick@paywhere.com |

No Google Drive. Files (dashboard, model, briefs, bank package) are written
into the **Cowork working folder** by Cowork itself.

The mailbox and calendar are **shared** across presenters (like the books);
only the bank world is per presenter. Mail and events are inserted by the
Google seed script (`paywhere-qbo-mcp/scripts/seed-google.mjs`, runbook
`paywhere-mcp/docs/runbooks/demo-gmail-token.md`) with dates relative to the
same `dateModel`; run `--check` in the demo week.

## 2. Install the plugin

**Cowork (the demo client):** build and side-load.

```bash
git clone https://github.com/paywhereb/paywhere-claude-plugins.git
cd paywhere-claude-plugins
./scripts/package.sh paywhere-smb        # → dist/paywhere-smb-1.0.2.plugin
```

In Cowork, **create a project for the demo first** and paste
[`cowork-project-prompt.md`](cowork-project-prompt.md) into the project's
instructions — that file carries the persona, the answer style and the
tool-field hygiene (the skills themselves stay generic; the same text is the
eval's system prompt via `EVAL_PROJECT_PROMPT`). Then use the "side-load a
plugin file" picker and choose the `.plugin` file, connect the four
connectors in Cowork's connector settings signed in as above, and pick a
working folder for the demo (the skills write `briefs/`, `sweeps/`,
`dashboard/`, `models/`, `bank/`, `close/` under it).

**Claude Code (engineering rehearsal):**
```
/plugin marketplace add paywhereb/paywhere-claude-plugins
/plugin install paywhere-smb@paywhere-claude-plugins
```

**Bare connector for beat 1.0:** claude.ai → Settings → Connectors → Add
custom connector → `https://demo.dev.paywhere.com/mcp`, sign in with the same
bank user. No plugin loads there — that is the point of the beat.

Any plugin change must bump the version (plugin.json + marketplace.json +
the skill's `version:`), or clients keep the old behavior.

## 3. Approval path (what the room will see)

On the demo deployment the four money tools stage **proposals**; nothing
executes from chat. Each staging returns
`https://<bank host>/confirm/<id>/<nonce>` — open it, sign in to the bank,
approve with a **passkey** (or TOTP). Enroll the passkey for the demo bank
user before the meeting (open any confirm page once; the enrollment prompt
appears). Proposals are sticky (lines accumulate on one open proposal until
approved/cancelled) and expire; if a link 404s or says expired, re-stage from
the same prompt. Internal transfers (reserve top-up, Friday sweep) stage
through the batch tool's `transfer` rail so they wait for the same passkey.
Full convention: `paywhere-smb/skills/_shared/APPROVAL.md`.

## 4. The never-send safeguards (a demo never sends email)

Three layers; all three must be in place before a live demo:

1. **Skills.** Every skill uses Gmail `create_draft` only; the eval fails any
   transcript that calls send/reply/forward. Calendar events (only when the
   owner asks for a reminder) are created without attendees.
2. **Workspace.** The Google Workspace admin restricts outbound delivery for
   `demo-nick@paywhere.com` (Gmail "Restrict delivery" to paywhere.com, or a
   routing rule rejecting outbound for its OU) so an accidental send bounces
   inside Google.
3. **Client.** Deny the send tools at the client: in Claude Code,
   `permissions.deny` for the Gmail `send_message`, `reply`, `forward` tools
   (and the Drive tools, which are not used); in Cowork, uncheck those tools
   in the Gmail connector's permissions for the demo profile.

Drafts pile up in the shared mailbox; the Google reseed clears the previous
day's demo drafts.

## 5. Order of operations on demo day

1. Morning: confirm the QBO reseed ran (`get_demo_dates` → `seeded: true`,
   `seededAt` today). Run `seed-google.mjs --check`.
2. Open the demo Cowork project (instructions = `cowork-project-prompt.md`;
   plugin 1.0.2 side-loaded; four connectors signed in as demo-nick).
3. `/demo-setup` (≈ 5 min). Record credentials. Check the four readback ✓.
4. Sign the bare-connector window in with the new bank user.
5. Pre-run Act 3 (`Run my morning cash brief`, `Run the Friday tax sweep`)
   so files and proposals exist; do **not** approve them yet.
6. Open paywhere-admin on Intents.
7. Walk SCENARIOS.md. Approve proposals live on the bank's page.
8. After: re-run `/demo-setup` if you injected; leave proposals unapproved
   or cancel them.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `/demo-setup` stops at preflight: seeder tools absent | Not a demo deployment / wrong connector URL | Point Paywhere at `demo.dev.paywhere.com/mcp` |
| `get_demo_dates` → `seeded: false` | Books not reseeded yet | Wait for 5am ET or ask the QBO demo owner to run the manual reseed |
| Balances ≠ `expectedClosing` in readback | Seed job had failures, or the connector re-authorized with old credentials | Re-run `/demo-setup`; re-auth with the NEW credentials |
| `get_transaction_detail` → `null` on the recurring debit | Enrichment keyed to another world (old creds) | Re-run `/demo-setup` |
| A saved wire payee reported as "ACH" or unresolved | Payee rail mismatch | Readback catches it; re-run `/demo-setup` |
| `/confirm` link 404 | Nonce dropped after `?` or copied partially, or proposal expired | Copy the full path form `/confirm/<id>/<nonce>`; re-stage if expired |
| Money tool returns `{ error: "…no proposal store (stdio mode)…" }` | Running against a local stdio server | Use the HTTP demo deployment |
| Skill "executed" or says "paid ✓" | Stale skill text | You are on an old plugin version; rebuild + side-load 1.0.2 |
| Intents shows no `financing_debt` move during 1.8 | Project prompt missing — the skills no longer word the `intent` field | Check the Cowork project's instructions carry `cowork-project-prompt.md` (§Tool fields) |
| Gmail draft shows up as sent | Client denies not applied | Stop; check §4 layers; Workspace restriction should have bounced it |
| Scheduled task did not fire | Cowork must be open; local schedule | Pre-run before the meeting; in the room show the schedule and the file |
| Dashboard shows old numbers | Static file; regenerated by the 7:30 brief | Run `daily-cash-brief` interactively ("Run my morning cash brief") |
| Router picked the wrong skill | Phrase too far from the description triggers | Use the exact SCENARIOS.md text; or name the skill |
| `query_transactions` → `truncated: true` | > 4,000 rows scanned | Skills slice by quarter; if it persists the world is oversized — report |

## 7. What the FI seat shows and does not

Intents (category mix, `sessionType`), Connections (consent grants), Money
Movement (proposals staged → approved → executed). No conversation text.
`sessionType` is asserted by the client, not verified by the server — say so
if asked. The background snapshot is the generic multi-business dataset;
Nick's HVAC rows layer on top and live actions append.

## 8. Frozen staffing vertical (D9)

The Meridian Staffing world, `pay-and-bill` and `pay-commissions` are kept in
the repos for reference and are **not maintained**; their books are no longer
reseeded. The old script is at the bottom of
[`demo-script.md`](demo-script.md).
