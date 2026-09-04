# Descriptor normalization

Goal: turn `statementDescription` into a **stem** stable across months for the same vendor. Work on the uppercase string.

## Strip, in order

1. Rail prefixes: `POS DEBIT `, `RECURRING DEBIT `, `ACH DEBIT `, `DEBIT CARD `, `CHECKCARD `.
2. Processor codes: anything before and including `*` is a processor prefix when the part after it is the readable name (`INTUIT *QBOOKS ONLINE` → `INTUIT QBOOKS ONLINE`); keep both tokens, drop the `*`.
3. Store / terminal numbers: `#\d+`, standalone digit runs of 3+ characters.
4. Locations: a trailing `<CITY> <ST>` pair (two-letter state code at the end) and the city before it.
5. Dates and reference ids: `\d{2}/\d{2}`, `\d{6,}`, tokens that are half letters half digits at the end.
6. Collapse whitespace; take the first three tokens as the stem.

Examples (illustrative, not facts about any business):

| statementDescription | stem |
|---|---|
| `RECURRING DEBIT ANGI LEADS` | `ANGI LEADS` |
| `POS DEBIT HOME DEPOT PRO #3008 KANSAS CITY MO` | `HOME DEPOT PRO` |
| `RECURRING DEBIT INTUIT *QBOOKS ONLINE` | `INTUIT QBOOKS ONLINE` |
| `POS DEBIT QUIKTRIP 0211 KANSAS CITY MO` | `QUIKTRIP` |
| `ACH DEBIT VERIZON WIRELESS` | `VERIZON WIRELESS` |

Two stems that share the first two tokens and have the same amount are the same vendor (merge); the same stem with two distinct stable amounts is two subscriptions (two seats or two plans) — a **duplicate** candidate.

## Spacing test

Sort a stem's debits by date; compute gaps in days.

| Cadence | Median gap | Tolerance |
|---|---|---|
| weekly | 7 | 5–9 |
| monthly | 30 | 25–35 |
| quarterly | 91 | 80–100 |
| annual | 365 | 340–390 (needs ≥ 2 occurrences, flag as annual) |

Recurring = ≥ 3 occurrences (≥ 2 for annual), ≥ 80% of gaps inside tolerance, amount stable (max/min ≤ 1.10) or a single step up (price creep).

## What is not a subscription

Fuel, hardware-store and consumable stems recur weekly with varying amounts — report their count and 12-month total under "variable spend", not in the run-rate. Bills paid to saved payees (equipment, parts, subcontractors) vary by invoice — they belong to `ap-timing`. Payroll processor, tax and transfer stems are excluded up front.
