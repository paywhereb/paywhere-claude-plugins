# Bill-pay scenario manifest — the overdue-AP surface for /pay-bills

Layers on the base world. The six base bills are **canonically defined in
[../../demo-setup-base/seed/qbo-manifest.md](../../demo-setup-base/seed/qbo-manifest.md)**
(M0 "Open bills" table) — they are restated here only to draw the full demo
picture, and the base manifest wins on any conflict. Date tokens per
[../../demo-setup-base/seed/date-tokens.md](../../demo-setup-base/seed/date-tokens.md);
all counterparty payment details mirror
[../../demo-setup-base/seed/persona.md](../../demo-setup-base/seed/persona.md).

## The six base open bills (seeded by /demo-setup-base)

| Bill | Vendor | Rail | Amount | TxnDate | DueDate | Bucket |
|---|---|---|---|---|---|---|
| PWD-BILL-0308 | DigitalOcean | ACH | 940.00 | M-1:15 | **W-1:Mon** | OVERDUE |
| PWD-BILL-0309 | Sutter Hill Properties | Wire | 1,850.00 | M-1:20 | **EOM-1** | OVERDUE |
| PWD-BILL-0310 | Grant Henderson CPAs | ACH | 3,200.00 | M-1:25 | **W-1:Fri** | OVERDUE |
| PWD-BILL-0311 | Amazon Web Services Inc | ACH | 2,450.00 | W-1:Wed | W+0:Fri | coming due |
| PWD-BILL-0312 | Google Workspace | ACH | 480.00 | W-1:Wed | W+0:Fri | coming due |
| PWD-BILL-0313 | Slack Technologies | ACH | 4,500.00 | W-1:Thu | W+0:Fri+7 | coming due |

Base totals: **$5,990.00 overdue + $7,430.00 coming due = $13,420.00**.

## Extra drama bills (seeded by THIS skill — `create-bill`, search-before-create)

Two more overdue bills so the aging table has five overdue rows, typically
across five distinct day-counts (pairs can coincide in a month-start week,
when several past tokens roll back onto the same Friday). DocNumbers continue the base M0 sequence; the `PWD-` id
also goes at the start of `PrivateNote` (the base DocNumber-persistence
fallback, qbo-manifest.md).

| Bill | Vendor | Rail | Amount | TxnDate | DueDate | Memo |
|---|---|---|---|---|---|---|
| PWD-BILL-0314 | HubSpot Inc | ACH | 890.00 | M-1:10 | **M-1:25** | CRM contact-tier overage true-up |
| PWD-BILL-0315 | Google Workspace | ACH | 390.00 | M-1:18 | **W-1:Tue** | Workspace storage add-on, billed separately |

Both vendors are base master data (matched by DisplayName, never deleted).
Two deliberate wrinkles, worth narrating in the demo:

- **Google Workspace carries TWO open bills** — 0315 overdue and 0312 coming
  due — so widening the selection pays the same vendor twice in one batch.
- **HubSpot already has a paid M0 bill** (PWD-BILL-0306, qbo-manifest.md), so
  the vendor history looks lived-in: current sub paid, an older true-up slipped.

## The aging picture after this setup

| Bucket | Bills | Total |
|---|---|---|
| OVERDUE | 0308 ($940) + 0309 ($1,850) + 0310 ($3,200) + 0314 ($890) + 0315 ($390) | **$7,270.00** |
| Coming due | 0311 ($2,450) + 0312 ($480) + 0313 ($4,500) | **$7,430.00** |
| **Total open AP** | 8 bills | **$14,700.00** |

Days-overdue ranges (exact values computed at run time; deterministic within
any given week): 0310 due W-1:Fri → 2–8 days; 0315 due W-1:Tue → 5–11;
0308 due W-1:Mon → 6–12; 0309 due EOM-1 → roughly today's day-of-month;
0314 due M-1:25 → the oldest, roughly day-of-month plus the tail of last month.

## Vendor payment-rail table — demo resolution for /pay-bills

Mirrors persona.md's vendor table exactly (persona.md is canonical for ABA /
account / type; a divergence here is a bug). Email addresses are defined
**here** — persona.md doesn't list vendor emails — for the ACH `recipient`
block's `emailAddress` field. Every ACH item uses `recipientIdType: "Inline"`
with the full block (mock recipients are global and permanent, so DisplayName
is ambiguous).

| Vendor | Rail | aba | accountNumber | accountType | emailAddress |
|---|---|---|---|---|---|
| Amazon Web Services Inc | ACH | 121000248 | 445566778899 | Checking | ar@aws.example.com |
| DigitalOcean | ACH | 021000021 | 223344556677 | Checking | billing@digitalocean.example.com |
| Google Workspace | ACH | 121000248 | 334455667788 | Checking | payments@workspace.example.com |
| Grant Henderson CPAs | ACH | 021000021 | 112233445566 | Checking | accounts@granthenderson.example.com |
| HubSpot Inc | ACH | 021000021 | 990011223344 | Checking | ar@hubspot.example.com |
| Slack Technologies | ACH | 121000248 | 667788990011 | Checking | billing@slack.example.com |

**Sutter Hill Properties — Wire** (call `get_wire_config` first for a valid
`processDate`):

- `recipient`: name `Sutter Hill Properties`, accountNumber `880099112233`,
  address1 `1 Embarcadero Center, Suite 400`, city `San Francisco`, state
  `CA`, postalCode `94111`
- `recipientBank`: name `Pacific Crest Bank NA`, **`aba`** `121000358`
  (the field is `aba`, never `routingNumber`)

## Expected demo numbers

- **Default selection (all overdue): $7,270.00** — four ACH items totaling
  $5,420.00 (940 + 3,200 + 890 + 390) + one wire of $1,850.00.
- Widened ("also what's due Friday", + 0311 and 0312): **$10,200.00**.
- Everything open: **$14,700.00**.
- Operating Checking closes the full base seed at **$96,291.97**
  (bank-manifest.md closing check; horizon-dropped M0 rows are mostly debits,
  so a partial-seed week closes *higher*). Projected post-batch:

| Selection | Batch total | Projected balance (full-seed close) |
|---|---|---|
| Default (overdue) | 7,270.00 | 96,291.97 − 7,270.00 = **89,021.97** (± wire fee) |
| + due Friday | 10,200.00 | **86,091.97** (± wire fee) |
| Everything | 14,700.00 | **81,591.97** (± wire fee) |

Each selection includes the Sutter Hill wire; the mock bank's own history
posts a **$45 fee per outbound wire** (bank-manifest `M-2:01`/`M-1:01`/
`M0:01`), so expect the live close ~$45 lower (e.g. **$88,976.97** on the
default selection). `/pay-bills` step 8 surfaces the fee row when it posts.

The live balance always comes from `get_account_balance` at run time — these
are presenter expectations, never inputs. The next known obligation is the
Gusto payroll run, $11,700 due `W+0:Fri` (persona.md): even the
pay-everything selection leaves ≥ $81k, so /pay-bills' low-balance warning is
*narrated*, not triggered, in this demo.

## Determinism note

All due dates above are tokens; per
[../../demo-setup-base/seed/date-tokens.md](../../demo-setup-base/seed/date-tokens.md),
future-relative tokens (`W+0:Fri`, `W+0:Fri+7`) are allowed for **DUE DATES
only**, and due-date fields are exempt from the horizon drop. This manifest
seeds **no posted transactions** (open bills have no bank rows), so nothing
here is ever dropped. The two extras seeded here and the OVERDUE bucket
(membership and the $7,270 / $7,430 totals) are identical Monday–Sunday of
a given week — but the base bills' `W+0:Fri`-anchored due dates are
**today**-anchored, not horizon-anchored: resolved on the same week's
Friday (or weekend) they land one week later. Buckets and totals don't
change; the concrete coming-due dates can. The extras' due dates
deliberately use **past** tokens
(`M-1:25`, `W-1:Tue`) — never `M0:dd`, which early in a month can resolve
after today and silently stop being overdue.
