# Date tokens — the date-relative manifest convention

Every demo-setup manifest (bank rows, QBO transactions, due dates) is written in
**date tokens**, never concrete dates. Setup skills resolve tokens against
today's actual date at run time, so the seeded world always looks fresh no
matter when setup runs — and resolves identically all week (see "Seed horizon
and same-week determinism" below). All demo-setup skills (`demo-setup-base` and
every `demo-setup-*` extension) MUST follow this file.

## Tokens

| Token | Meaning |
|---|---|
| `M0:dd` | Day `dd` of the current month |
| `M-1:dd` | Day `dd` of the previous month |
| `M-2:dd` | Day `dd` of the month two months back |
| `W-1:Mon` … `W-1:Fri` | The last complete week — the Mon–Fri block ending on the most recent Sunday |
| `EOM-1` | Last day of the previous month (sugar for `M-1:31` after clamping) |
| `W+0:Fri` | The upcoming Friday strictly after today — **due dates only** |
| `W+0:Fri+N` | N calendar days after that Friday — **due dates only** |

**Day overflow clamps.** `M-1:31` in a 30-day month resolves to the 30th; in
February to the 28th/29th. Clamp to the month's last day; never spill into the
next month.

**Business-day rule.** Any resolved date landing on Saturday or Sunday rolls
**back** to the Friday before. Apply after clamping. (`W-1:*` and `W+0:Fri`
are weekdays by construction.)

## Seed horizon and same-week determinism

**Seed horizon = the most recent Sunday on or before today.** (If today is
Sunday, the horizon is today.)

Any token whose resolved date (after clamping and weekend roll-back) lands
**after** the horizon is **DROPPED** from the seed — the row is not posted at
all, never clamped to the horizon. Due-date *fields* (bill `DueDate`, payroll
dates) are exempt: they describe obligations, not posted history, and may be in
the future.

Because "the most recent Sunday on or before today" is the same date on every
day from Monday through Sunday of a given week, **the resolved set of POSTED
rows is byte-identical whether setup runs Monday or Friday of that week**.
That is the same-week determinism guarantee: re-running setup any day mid-week
reproduces the exact same transaction history, so demos rehearsed on Tuesday
look identical on Friday.

**Scope: the guarantee covers posted rows, not `W+0` due-date fields.**
`W+0:Fri` is anchored to *today* by design (a payroll date must be strictly
in the future on the day you run): setup on Monday stores this week's Friday,
setup on Friday stores next Friday. Bucket classifications stay stable —
"overdue" compares a stored due date against *today*, and both move together
inside the week — but the concrete stored due dates differ by setup day, and
a world seeded last week will show this week's runs a bigger overdue bucket
than the cheat sheets assume. Scenario manifests that quote expected bucket
totals must state this (see demo-setup-bill-pay/seed/bills.md).

Consequences worth knowing:

- `W-1` rows are **never dropped** — `W-1:Fri` is two days before the horizon
  by construction. The freshest demo-critical activity (last week's client
  receipts) is therefore always anchored to `W-1` tokens, never `M0:dd`.
- Early in a month (any day before the month's first Sunday), the horizon is
  still in the previous month: **all `M0:dd` rows drop** and `W-1` resolves
  into the previous month. The manifests are written so the demos that matter
  survive this — the `W-1` rows carry them. Flag dropped discrepancy rows to
  the user (see `bank-manifest.md`).

## Hard rules

1. **No posted transaction may ever use "today", "yesterday", or "this
   week".** The newest posted row in any seed is `W-1:Fri` or earlier.
2. Future-relative tokens (`W+0:Fri`, `W+0:Fri+N`) are allowed **only for due
   dates** — bill due dates, payroll dates — never for posted transactions.
3. For a live "money just landed" demo moment, the demo **script** posts a
   deposit mid-demo via `deposit_to_mock_account` — demo-driven, never
   seed-driven. Seeds end at the horizon, full stop.

## Resolution algorithm

Every setup skill MUST run this procedure and show the resulting table to the
user **before seeding anything**:

1. **Compute today** — the actual current date. Never assume or reuse a date
   from a prior session.
2. **Compute the horizon** — the most recent Sunday on or before today.
3. **Resolve each token** to a candidate date:
   - `M0:dd` / `M-1:dd` / `M-2:dd` → day `dd` of that month, **clamped** to
     the month's last day on overflow.
   - `W-1:Mon` = horizon − 6 days, `W-1:Tue` = horizon − 5 … `W-1:Fri` =
     horizon − 2.
   - `EOM-1` → last day of the previous month.
   - `W+0:Fri` → first Friday strictly after today; `+N` adds N calendar days.
4. **Clamp** (done in step 3), then **roll back** any Saturday/Sunday result to
   the preceding Friday.
5. **Drop** every posted-transaction row whose resolved date is after the
   horizon. Due-date fields are never dropped; the open-bill rows that carry
   them are dated in the past by construction, so they always survive.
6. **Render the resolved date table** — `token → concrete date → kept/dropped`
   — and show it to the user for approval before any seeding call.

## Worked example

Today = **Wednesday 2026-06-10** → horizon = **Sunday 2026-06-07**.
`W-1` = Mon 2026-06-01 … Fri 2026-06-05.

| Token | Resolution | Result |
|---|---|---|
| `M0:02` | Tue 2026-06-02 | kept |
| `M0:07` | Sun 2026-06-07 → weekend, roll back | kept as Fri 2026-06-05 |
| `M0:12` | Fri 2026-06-12 — after 2026-06-07 | **dropped** |
| `W-1:Thu` | Thu 2026-06-04 | kept |
| `M-2:31` | April has 30 days → clamp | kept as Thu 2026-04-30 |
| `EOM-1` | Sun 2026-05-31 → weekend, roll back | kept as Fri 2026-05-29 |
| `W+0:Fri` | Fri 2026-06-12 | allowed as a due date only |

Note `M0:07` resolves to the same concrete date on Monday 2026-06-08 and on
Friday 2026-06-12 — the horizon (2026-06-07) is constant all week, which is
exactly the determinism guarantee.
