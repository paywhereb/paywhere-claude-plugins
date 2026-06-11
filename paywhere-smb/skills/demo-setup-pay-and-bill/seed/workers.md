# Workers seed manifest — register rows + W-1 hour notes

The seed for `/demo-setup-pay-and-bill`. All worker names, client
assignments, rates, and rail details come from
[../../demo-setup-base/seed/persona.md](../../demo-setup-base/seed/persona.md)
— that file is the single source of truth; the tables below tabulate it into
the shapes the register and notes need. Date tokens resolve per
[../../demo-setup-base/seed/date-tokens.md](../../demo-setup-base/seed/date-tokens.md).
The register and marker schemas live in
[../../pay-and-bill/DATA-MODEL.md](../../pay-and-bill/DATA-MODEL.md).

## `workers-register.xlsx` — sheet `Workers` (4 rows)

Wide-column schema per DATA-MODEL.md. Common columns:

| Worker | Client | BillRate | PayRate | Rail |
|---|---|---|---|---|
| Priya Raman | Thames Fintech Ltd | 130 | 100 | ACH |
| Marcus Webb | Alderbrook Ventures LLC | 104 | 80 | ACH |
| Elena Sorokina | Zurich Dynamics AG | 156 | 120 | Wire |
| Devon Okafor | Mitsui Digital KK | 117 | 90 | Stablecoin |

Rail-detail columns (only the row's own rail is filled; values verbatim from
persona.md):

| Worker | Rail details |
|---|---|
| Priya Raman | `AchABA` 021000021, `AchAccountNumber` 700100200300, `AchAccountType` Checking, `Email` priya.raman@example.com |
| Marcus Webb | `AchABA` 121000248, `AchAccountNumber` 700200300400, `AchAccountType` Checking, `Email` marcus.webb@example.com |
| Elena Sorokina | `WireAccountNumber` 700300400500, `WireAddr1` 88 Leonard St, Apt 12B, `WireCity` New York, `WireState` NY, `WirePostalCode` 10013, `WireBankName` Citibank NA, `WireBankABA` 021000089 |
| Devon Okafor | `WalletAddress` 0xc838058cc6c71db99c9ac001e6f003e65ffbcca4, `Chain` POLY, `Currency` USD |

Sheet `PaidLog` is created **empty** (header row only):
`PeriodStart | PeriodEnd | Worker | Hours | PayRate | GrossPay | Rail | PaywherePaymentId | QBOBillId | QBOInvoiceIds`.

**Devon's wallet is intentionally the same POLY test wallet CryptoConsult DAO
uses** (persona.md — only a handful of verified test wallets exist). If the
recipient record needs creating, use `create_stablecoin_recipient` with
`wallet {address: <above>, chain: "POLY", currency: "USD"}`, `walletOwner
{type: "Individual", name: "Devon Okafor", address: "419 Fulton St, Brooklyn,
NY 11201"}` (mock address, same spirit as persona.md's fabricated bank
details). If /demo-setup-commissions already registered the wallet under
CryptoConsult DAO, that single record serves both flows — all either needs is
VERIFIED status.

## Drive hour notes — one per worker, the W-1 week

Filename convention (resolved at seed time): **`Hours - {Worker} - Week of
{W-1:Mon}`**, with `{W-1:Mon}` as the resolved ISO date — e.g. with the
date-tokens.md worked example (today Wed 2026-06-10), `Hours - Priya Raman -
Week of 2026-06-01`. This is the same convention `/pay-and-bill` searches on
both paths (Gmail subject = Drive filename), so the demo notes are found
exactly like real mail would be.

Plain-text body template (dates resolved at seed time; `{W-1:Mon..Fri}` per
date-tokens.md):

```
Hours report — {Worker}
Client: {Client}
Week of {W-1:Mon} (Mon {W-1:Mon} – Fri {W-1:Fri})

Mon {W-1:Mon}: {h}
Tue {W-1:Tue}: {h}
Wed {W-1:Wed}: {h}
Thu {W-1:Thu}: {h}
Fri {W-1:Fri}: {h}

Total: {total} hours
```

Per-worker day lines (chosen so the totals below tie out; Devon's Friday off
gives the demo a natural partial-week row):

| Worker | Mon | Tue | Wed | Thu | Fri | Total |
|---|---|---|---|---|---|---|
| Priya Raman | 8 | 8 | 8 | 8 | 8 | **40** |
| Marcus Webb | 7.5 | 7.5 | 7.5 | 7.5 | 7.5 | **37.5** |
| Elena Sorokina | 7.5 | 8 | 7.5 | 7 | 7.5 | **37.5** |
| Devon Okafor | 8 | 8 | 6 | 8 | 0 (off) | **30** |

## The W-1 arithmetic — verified against persona.md rates

Invoices (hours × BillRate, one per client):

| Marker (DocNumber) | Client | Line | Total |
|---|---|---|---|
| `PWD-PB-INV-{period}-thames` | Thames Fintech Ltd | 40 × $130 | $5,200.00 |
| `PWD-PB-INV-{period}-alderbrook` | Alderbrook Ventures LLC | 37.5 × $104 | $3,900.00 |
| `PWD-PB-INV-{period}-zurich` | Zurich Dynamics AG | 37.5 × $156 | $5,850.00 |
| `PWD-PB-INV-{period}-mitsui` | Mitsui Digital KK | 30 × $117 | $3,510.00 |
| | | **Invoiced total** | **$18,460.00** |

Worker pay (hours × PayRate, one batch item + one bill per worker):

| Marker (DocNumber) | Worker | Line | Gross | Rail |
|---|---|---|---|---|
| `PWD-PB-BILL-{period}-priya` | Priya Raman | 40 × $100 | $4,000.00 | ACH |
| `PWD-PB-BILL-{period}-marcus` | Marcus Webb | 37.5 × $80 | $3,000.00 | ACH |
| `PWD-PB-BILL-{period}-elena` | Elena Sorokina | 37.5 × $120 | $4,500.00 | Wire |
| `PWD-PB-BILL-{period}-devon` | Devon Okafor | 30 × $90 | $2,700.00 | Stablecoin (+$27.00 fee, 1%) |
| | | **Pay total** | **$14,200.00** | |

`{period}` = the resolved `W-1:Mon` ISO date. Identity check: **$18,460 =
1.3 × $14,200 exactly** (every persona rate pair is exactly 1.3×) — margin
**$4,260.00**, a 30% markup on pay (~23.1% gross margin on revenue). Total
bank debit when `/pay-and-bill` runs: $14,200.00 + $27.00 stablecoin fee =
**$14,227.00** from Operating Checking.

## Why these hours don't collide with the base world

**The W-1 weekly hours are NOT yet invoiced anywhere in the base seed.** The
base M0 invoices (`PWD-INV-0301…0305` in
[../../demo-setup-base/seed/qbo-manifest.md](../../demo-setup-base/seed/qbo-manifest.md))
bill the standard **monthly** cycle at full monthly hours (160/150/150/120
— not the W-1 weekly hours), were issued on `W-1:Mon`, and are already
(partly) collected — Thames and Zurich closed, Mitsui half-paid, Alderbrook
open. An invoice issued on `W-1:Mon` cannot include hours worked during
W-1 itself. The hour notes seeded here describe the **last complete week**, a fresh
period with no invoice, no worker bill, and no worker payment in the base
world. So `/pay-and-bill` creates genuinely new `PWD-PB-INV-…` /
`PWD-PB-BILL-…` documents — a distinct DocNumber family from the base
`PWD-INV-…` / `PWD-BILL-…` — and a first run never reports false
"already processed" rows.

Note the weekly hours (40 / 37.5 / 37.5 / 30) are deliberately *not* the
persona's standard monthly hours — they are one week's worth, sized so every
line above is whole-dollar.
