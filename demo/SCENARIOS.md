# Nick's HVAC — setup, the FI seat and the injects (SCENARIOS.md)

What the presenter needs that is not a prompt. The prompts, in order, with
timings and what to point at, are [`LIVE-SCRIPT.md`](LIVE-SCRIPT.md). Persona
and data: [`../paywhere-smb/DATASET.md`](../paywhere-smb/DATASET.md).

**How to read the answer key.** `/demo-setup` prints `answerKeySummary`; its
paths are the `AnswerKey` shape in
`paywhere-mcp-api/src/demo/world/types.ts`, and the full key for a demo date
is `paywhere-mcp-api/src/demo/world/fixtures/answer-key-<today>.json`.
Numbers roll with the date model, so read them from the setup report or the
fixture, never from a document. The **fixed** figures — agreement amounts and
the staged live-surface amounts — are in DATASET.md.

**Voice.** In the room the owner is talking to his finance agent in Claude
Cowork; only `/demo-setup` and the injects are presenter commands. A vendor
payment ends with a `/confirm/<id>/<nonce>` link, opened on the bank,
approved with a passkey. Say once, early: *"Nothing pays a vendor from chat.
The bank's page is where the approval happens."*

---

## Act 0 — Setup (presenter, before the meeting)

### Accounts and connectors

| Connector | What it is | Sign in as |
|---|---|---|
| **Paywhere** (`https://demo.dev.paywhere.com/mcp`) | The demo bank via the Paywhere MCP; carries the demo-seeder tools | The bank user `/demo-setup` returns (rotates per run; also posted to the demo Slack channel and kept in 1Password) |
| **quickbooks** (`https://qbo.dev.paywhere.com/mcp`) | Custom, read-only QBO MCP over the shared sandbox company; reseeds daily 5am ET | QBO sandbox OAuth (1Password) |
| **gmail** (`https://gmailmcp.googleapis.com/mcp/v1`) | Google's Gmail MCP | **demo-nick@paywhere.com** ("Nick Adler (Nick's HVAC)") |
| **google calendar** (`https://calendarmcp.googleapis.com/mcp/v1`) | Google's Calendar MCP | demo-nick@paywhere.com |

No Google Drive. Files (briefs, sweep records, the bank package — all
markdown) are written into the **Cowork working folder** by Cowork itself.

The mailbox and calendar are **shared** across presenters (like the books);
only the bank world is per presenter. Mail and events are inserted by the
Google seed script (`paywhere-qbo-mcp/scripts/seed-google.mjs`, runbook
`paywhere-mcp/docs/runbooks/demo-gmail-token.md`) with dates relative to the
same `dateModel`; run `--check` in the demo week.

### The Cowork project

1. In Cowork, create a project for the demo and paste
   [`cowork-project-prompt.md`](cowork-project-prompt.md) into its
   instructions (persona, answer style, money-movement rules, tool-field
   hygiene — the steer the skills deliberately do not carry; the scenario
   eval reads the same file as its system prompt).
2. Connect the four connectors above in that project, signed in as
   **demo-nick@paywhere.com** for the Google pair.
3. Build and side-load the plugin:

   ```bash
   git clone https://github.com/paywhereb/paywhere-claude-plugins.git
   cd paywhere-claude-plugins
   ./scripts/package.sh paywhere-smb        # → dist/paywhere-smb-1.0.23.plugin
   ```

   In Cowork, use the "side-load a plugin file" picker and choose
   `dist/paywhere-smb-1.0.23.plugin`; pick a working folder (the skills write
   `briefs/`, `sweeps/`, `savings/` and `bank/` under it). Any plugin change
   bumps the version, or clients keep the old behaviour.
4. **Set the model to Claude Sonnet 5 at MEDIUM effort.** This is measured,
   not a preference: medium was the only setting where the pay-bills beat
   passed every run; low degraded even a plain balance question, and high
   put every beat over the wall clock. The scenario eval is locked to the same
   setting so the grading run and the demo behave alike — do not change one
   without the other.
5. Then, in the project:

   ```
   /demo-setup
   ```
   (optional: `/demo-setup username: brett`)

   Approve the gate. The seed is **asynchronous**: the skill polls
   `get_demo_world` for ≈ 4–6 minutes and shows progress, then reads the
   world back through the connector and reports. Record the **bank
   username/password** (also posted to the demo Slack channel).

   You should see, from the report:

   | Report line | Answer-key path |
   |---|---|
   | Operating / Tax Reserve / Business Savings balances (read back == `expectedClosing`) | `balances.operating`, `balances.taxReserve`, `balances.savings` |
   | True available cash and its formula | `trueAvailable.amount`, `trueAvailable.formula` |
   | Reserve balance, collected-not-remitted, **shortfall**, missed sweeps, next remittance | `tax.reserveBalance`, `tax.collectedNotRemitted.total`, `tax.shortfall`, `tax.missedSweeps`, `tax.nextRemittance` |
   | Largest overdue invoice; the received-but-unbooked check | `ar.largestOverdue`, `ar.unbookedReceipt` |
   | Bills due this week with rails; hold candidates | `ap.dueThisWeek`, `ap.holdCandidates` |
   | Payroll date, estimate, headroom | `payroll.nextPayDate`, `payroll.estimatedTotal`, `payroll.headroomAfterPayroll` |
   | Readback ✓ ×4: balances, payees (count + wire/ACH spot-check), enrichment, unbooked check | — |
   | `dateModelSource: "provided"` | — |

   If `get_demo_dates` says `seeded: false`, the books have not reseeded yet —
   wait or ping the QBO demo owner; do not demo on unaligned dates.

6. Run `/demo-inject` ("simulate Westport paying") if the tax sweep is on the
   agenda — the demo bank posts nothing after the most recent Sunday, so
   without a deposit this week the sweep is a correct but dull $0.
7. **Pre-run the agents** (`Run the tax sweep`, `Run the savings sweep`) so
   their files and staged proposals exist before the room fills; do not
   approve them yet. Enrol the passkey for the demo bank user by opening any
   `/confirm` page once.
8. For the opener, sign a claude.ai or Claude Desktop window in with the same
   bank user and only the Paywhere custom connector — no plugin loads there,
   which is the point of the beat.

### The never-send safeguards (a demo never sends email)

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

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `/demo-setup` stops at preflight: seeder tools absent | Not a demo deployment / wrong connector URL | Point Paywhere at `demo.dev.paywhere.com/mcp` |
| `get_demo_dates` → `seeded: false` | Books not reseeded yet | Wait for 5am ET or ask the QBO demo owner to run the manual reseed |
| Balances ≠ `expectedClosing` in readback | Seed job had failures, or the connector re-authorized with old credentials | Re-run `/demo-setup`; re-auth with the NEW credentials |
| `get_transaction_detail` → `null` on the recurring debit | Enrichment keyed to another world (old creds) | Re-run `/demo-setup` |
| A saved wire payee reported as "ACH" or unresolved | Payee rail mismatch | Readback catches it; re-run `/demo-setup` |
| `/confirm` link 404 | Nonce dropped after `?` or copied partially, or proposal expired | Copy the full path form `/confirm/<id>/<nonce>`; re-stage if expired |
| Money tool returns `{ error: "…no proposal store (stdio mode)…" }` | Running against a local stdio server | Use the HTTP demo deployment |
| A transfer line fails on the confirm page with `Upstream HTTP 500` | Old connector build: the bank requires a transfer `description` the connector did not send | Redeploy the connector with the ENG-437 fix; the skills pass a description on every transfer |
| A skill says "paid ✓" for a staged payment | Stale skill text | You are on an old plugin build; rebuild and side-load the current version |
| Intents shows no `financing_debt` move during the van beat | Project prompt missing — the skills do not word the `intent` field | Check the Cowork project's instructions carry `cowork-project-prompt.md` (§Tool fields) |
| Gmail draft shows up as sent | Client denies not applied | Stop; check the never-send layers; the Workspace restriction should have bounced it |
| Scheduled task did not fire | Cowork must be open; local schedule | Pre-run before the meeting; in the room show the schedule and the file |
| Cowork picked the wrong skill | Phrase too far from the description triggers | Use the exact LIVE-SCRIPT.md text; or name the skill |
| A beat runs long (> 6 calls, or well past its LIVE-SCRIPT timing) | Skill drifted from its call plan | Compare the tool calls with the skill's Quick start; report it — the eval budgets every case |
| `query_transactions` → `truncated: true` | > 4,000 rows scanned | Skills read scoped and bounded; if it persists the world is oversized — report |

---

## Act 4 — The FI seat (paywhere-admin)

Everything in LIVE-SCRIPT is Nick's story; this is the bank's. Walk, in order:

1. **Intents** — category mix over the session: `cash_flow_management` from
   the balance question, `accounts_payable` and `payment_operations` from
   pay-bills, `payroll_compensation` from the payroll beat,
   `transfers_treasury` / `tax_compliance` from the two sweeps, and the
   **`financing_debt` rise during the van beat** (the classifier keys on loan
   / lease / financ- / line of credit / debt in the `intent` text — with the
   project prompt in place, the van beat's calls carry Nick's question in his
   own words). Filter `sessionType: scheduled` to show the two agents' runs.
2. **Connections** — the demo owner's consent grant to Claude; the bare
   connector session from the opener.
3. **Money Movement** — the batches from the opener and pay-bills: staged →
   approved (passkey) → executed, the wire beside the ACH lines; the agents'
   staged transfers awaiting a human; a direct transfer (a payroll top-up,
   say) as an executed internal move with no proposal.
4. Fraud Review is left out this round.

Talking point: the bank sees aggregates and money movement, never
conversation text. `sessionType` is asserted by the client, not verified by
the server — say so if asked. The screens' background is the generic
multi-business snapshot; Nick's HVAC is one business in it, and everything
just done is appended live.

---

## Live injects (presenter, via `demo-inject`)

Presenter-voice prompts (they call the demo-seeder tools on the Paywhere
connector; the skill resolves the Operating account and reads amounts from
the live answer key). Injects are permanent for this world — re-run
`/demo-setup` before the real demo if you inject in rehearsal.

**Westport just paid** (before the tax sweep, or to move the payroll headroom live):
```
Inject a deposit: simulate Westport paying its largest overdue invoice — post an ACH credit to Operating with the customer's AP descriptor.
```
Then, owner voice: `Westport just paid — check again`. Effect:
`ar.largestOverdue` clears; `trueAvailable` and payroll headroom rise by the
amount; the tax sweep has real tax to stage.

**Emergency call invoice** (cash side only — the books are read-only):
```
Inject a deposit: an emergency-call card settlement landed today — post a merchant settlement deposit to Operating for the emergency job amount.
```
Owner voice: `Anything new land today?`

**Blue Line autopay failed**:
```
Inject a withdrawal: Blue Line's card autopay failed — reverse the agreement amount from Operating with a merchant return descriptor.
```
Owner voice: `Did Blue Line's payment go through?`

Pending card authorizations cannot be injected (posted rows only).

---

## Not in this build

Deferred agents, in the blueprint's priority order. None has an interim
answer in the plugin; the interactive skills that once stood in for them were
archived (see [`archive/README.md`](archive/README.md)).

| Agent | Why deferred |
|---|---|
| `ar-chase-agent` (Monday 8am reminder drafts) | time; the bank contributes nothing to a chase list |
| `tax-remittance-agent` (stages the remittance on the filing day) | time |
| `settlement-reconcile-agent` (nightly gross-to-net matching) | time |
| Pre-warmed world pool (instant `/demo-setup`) | server; the async seed is ≈ 4–6 min |
| `query_transactions groupBy: counterparty` | server; recurring-debit detection needs it |
| Fraud beat | left out this round |
