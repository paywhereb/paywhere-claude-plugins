# Demo persona — Meridian Staffing & Advisory LLC

The canonical demo company for every paywhere-smb demo. All manifests
(`bank-manifest.md`, `qbo-manifest.md`) and all `demo-setup-*` extensions seed
this persona — names, rates, and rails below are the single source of truth.

**All bank details below are mock/test values** (counterparty routing and
account numbers are fabricated for the mock bank). The POLY wallet addresses
are **real test-chain wallets** — use them verbatim.

## Company profile

Meridian Staffing & Advisory LLC is a boutique consulting and staffing firm:
it places senior contractors at client companies, bills the clients for hours,
pays the contractors, and runs a small advisory retainer practice on the side.
That makes hours billing, contractor pay, AP, payroll, and referral commissions
all natural parts of one business. Historically contractors were paid through
the Gusto payroll processor and the old bank; the demo story is Meridian moving
contractor payouts onto direct Paywhere rails (ACH / Wire / Stablecoin).

## Bank accounts (the `reset_demo` defaults)

| Role | Type | Opening balance | Notes |
|---|---|---|---|
| **Operating Checking** | Checking | $50,000 | primary — all client receipts, AP, payroll |
| **Reserve Savings** | Savings | $75,000 | monthly sweeps in, interest credits |

These match `reset_demo`'s default accounts exactly, so base setup calls
`reset_demo` without an `accounts` parameter. Manifests refer to accounts by
**role**; the concrete account numbers come from `get_demo_world` at run time
and are never hardcoded.

## Clients (QBO customers)

| Client | Bank (for inboundWireData) | Routing | Pays by | Typical monthly | Payment personality |
|---|---|---|---|---|---|
| Thames Fintech Ltd | HSBC Bank USA NA | 021001088 | Wire | $20,800 | **Prompt** — wires within ~5 days of invoice |
| Zurich Dynamics AG | UBS AG NY Branch | 026007993 | Wire | $23,400 | **Prompt** — wires within ~1 week |
| Alderbrook Ventures LLC | JPMorgan Chase Bank NA | 021000021 | ACH-style credit | $15,600 | **Slow** — pays ~day 26, routinely past net-15 |
| Mitsui Digital KK | Sumitomo Mitsui Banking Corp NY | 026009687 | Wire | $14,040 | **Partial-payer** — two half payments per invoice |
| Hallsten & Berg AB | Skandinaviska Enskilda Banken NY | 026002561 | ACH-style credit | $8,500 retainer | **Prompt** — autopays day 3 of cycle |

Wire deposits are seeded as type `DomesticWire` with `inboundWireData`
`{senderName: <client>, senderBankName: <bank>, senderBankRoutingNumber:
<routing>, referenceForBeneficiary: <invoice DocNumber>}`. ACH-style credits
are seeded as type **`Transfer`** with an `ACH CR <CLIENT>` statement
description — deposits can never be type `ACH` (mock-bank limitation).

## Vendors (AP) — Inline ACH details

Every outbound ACH uses `recipientIdType: "Inline"` with the full block below
(mock recipients are global and permanent, so DisplayName is ambiguous).

| Vendor | ABA | Account | accountType | What / cadence |
|---|---|---|---|---|
| Amazon Web Services Inc | 121000248 | 445566778899 | Checking | Cloud hosting — $2,450/mo (day 5) |
| Gusto Inc | 121000248 | 556677889900 | Checking | Payroll processor — $11,700 biweekly (days 13, 27) |
| Google Workspace | 121000248 | 334455667788 | Checking | Email/docs — $480/mo (day 7) |
| Slack Technologies | 121000248 | 667788990011 | Checking | Chat — $375/mo (day 7) |
| HubSpot Inc | 021000021 | 990011223344 | Checking | CRM — $1,160/mo (day 10) |
| Grant Henderson CPAs | 021000021 | 112233445566 | Checking | Accounting — $1,500/mo (day 20) |
| DigitalOcean | 021000021 | 223344556677 | Checking | Hosting — $640/mo (day 12) |

**Sutter Hill Properties** (office rent — pays by **wire**, $6,800/mo on day 1
plus the bank's $45 wire fee):
- `recipient`: name `Sutter Hill Properties`, accountNumber `880099112233`,
  address1 `1 Embarcadero Center, Suite 400`, city `San Francisco`, state
  `CA`, postalCode `94111`
- `recipientBank`: name `Pacific Crest Bank NA`, **`aba`** `121000358`

## Workers (4 contractors placed at clients)

Pay rate = bill rate ÷ 1.3, rounded to whole dollars — chosen so hours × rates
arithmetic ties out exactly in invoices, payouts, and the cash-crunch math.

| Worker | Placed at | Bill rate | Pay rate | Std hours/mo | Monthly bill | Monthly pay | Rail |
|---|---|---|---|---|---|---|---|
| Priya Raman | Thames Fintech Ltd | $130/hr | $100/hr | 160 | $20,800 | $16,000 | ACH |
| Marcus Webb | Alderbrook Ventures LLC | $104/hr | $80/hr | 150 | $15,600 | $12,000 | ACH |
| Elena Sorokina | Zurich Dynamics AG | $156/hr | $120/hr | 150 | $23,400 | $18,000 | Wire |
| Devon Okafor | Mitsui Digital KK | $117/hr | $90/hr | 120 | $14,040 | $10,800 | Stablecoin |

Standard-month totals: **$73,840 billed** to placement clients (+ $8,500
Hallsten & Berg advisory retainer = **$82,340**/mo), **$56,800 paid** to
workers.

Rail details:

- **Priya Raman (ACH)** — aba `021000021`, accountNumber `700100200300`,
  accountType `Checking`, emailAddress `priya.raman@example.com`
- **Marcus Webb (ACH)** — aba `121000248`, accountNumber `700200300400`,
  accountType `Checking`, emailAddress `marcus.webb@example.com`
- **Elena Sorokina (Wire)** —
  `recipient`: name `Elena Sorokina`, accountNumber `700300400500`, address1
  `88 Leonard St, Apt 12B`, city `New York`, state `NY`, postalCode `10013`;
  `recipientBank`: name `Citibank NA`, **`aba`** `021000089`
- **Devon Okafor (Stablecoin)** — wallet
  `0xc838058cc6c71db99c9ac001e6f003e65ffbcca4`, chain `POLY`, currency `USD`

Spare POLY test wallets, in order, if a flow needs a distinct wallet:
1. `0xf9b6e65ea4e02122295253cdeaa51082e46b7613`
2. `0xaacb9205d4087ae89af823d008bbc392689dffe4`
3. `0x495ebc4aa079b959a0e9a301ad9331b98ac18219`
4. `0x18500a1c9a8864587cb751ed286e3cd23a279ef3`

## Commission payees (used by /pay-commissions and /demo-setup-commissions)

| Payee | Rail | Details |
|---|---|---|
| Jane Doe Referrals | ACH | name `Jane Doe`, aba `021000021`, accountNumber `1234567890`, accountType `Checking`, emailAddress `jane@example.com` |
| Acme Sales Partners LLC | Wire | `recipient`: accountNumber `9876543210`, address1 `100 Market St`, city `San Francisco`, state `CA`, postalCode `94105`; `recipientBank`: name `Demo Bank NA`, **`aba`** `121000248` |
| CryptoConsult DAO | Stablecoin | wallet `0xc838058cc6c71db99c9ac001e6f003e65ffbcca4`, chain `POLY`, currency `USD` |

CryptoConsult DAO intentionally shares the primary POLY test wallet with Devon
Okafor — only a handful of verified test wallets exist. Use the first spare if
a flow ever needs them distinct.

### Commission map

| Client | Commission-bearing? | Rate | Payee |
|---|---|---|---|
| Thames Fintech Ltd | yes | 0.05 | Jane Doe Referrals |
| Alderbrook Ventures LLC | yes | 0.05 | Jane Doe Referrals |
| Zurich Dynamics AG | yes | 0.10 | Acme Sales Partners LLC |
| Mitsui Digital KK | yes | 0.10 | CryptoConsult DAO |
| Hallsten & Berg AB | **no — deliberately absent from the register** | — | — |

Hallsten & Berg is the **skip-path demo**: a real paying client that earns no
commission, so /pay-commissions always has a visible "skipped — not in
register" row. Monthly invoice amounts are chosen so gross × rate is always
whole dollars: $20,800×5% = $1,040; $23,400×10% = $2,340; $15,600×5% = $780;
$14,040×10% = $1,404; a Mitsui half-payment $7,020×10% = $702.

## Payroll

Internal W-2 staff payroll runs through **Gusto Inc**: $11,700 per biweekly
run (days 13 and 27), $23,400/mo. The **next** run is always *due* on
`W+0:Fri` (a due date, never a posted seed row) — this plus the $56,800/mo
contractor payout cycle is the payroll obligation in the cash-crunch demo.
