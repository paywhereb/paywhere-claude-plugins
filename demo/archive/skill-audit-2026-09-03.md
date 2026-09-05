# paywhere-smb skill audit — generic-only, ≤ 6 calls, no Excel/HTML

Audited: every directory under `paywhere-claude-plugins-worktrees/nicks-hvac/paywhere-smb/skills/` (23 skills + `_shared`), against `demo/cowork-project-prompt.md` and `demo/SCENARIOS.md`. Paths below are relative to `paywhere-smb/skills/` unless stated; line numbers are from the files as of this audit.

Tool budget used for the estimates: bank — `list_accounts`, `get_account_balance`, `query_transactions` (filters + `aggregate/groupBy`), `list_saved_payees`, `make_batch_payment` (`dryRun`), `get_transaction_detail`; QuickBooks (read-only) — `search_invoices/bills/payments/bill_payments/purchases/customers/vendors/journal_entries`, `read_invoice`, `get_aged_receivables`, `get_aged_payables`, `get_profit_and_loss`, `get_balance_sheet`, **`get_vendor_payment_timing`**, **`get_sales_tax_collected(date_from, date_to)`**; Gmail — `search_threads`, `get_thread`, `create_draft`; Calendar — `list_events`, `search_events`. Tools a skill names that are *not* in this set (`search_deposits`, `search_transfers`, `search_credit_memos`, `search_estimates`, `search_time_activities`, `search_employees`, `get_customer_sales`, `get_general_ledger`, `get_account_transactions`) are counted as a defect, not as calls.

## Summary

| Skill | Verdict | Est. calls today | Est. calls after | One-line reason |
|---|---|---|---|---|
| `pay-bills` | **KEEP** | 6 | 6 | The model skill: open AP → dry run → one staged batch → `/confirm`. Scrub demo vendor names/amounts only. |
| `big-purchase-decision` | **KEEP** | 5 | 5 | Owner's call; already ≤ 6. Rename "van" wording to a generic purchase. |
| `tax-reserve-check` | **REWRITE** | 12 + N | 4 (+1 to stage) | Real reserve-shortfall + catch-up-transfer procedure; `get_sales_tax_collected` collapses Step 3; drop balance-sheet/calendar/IRS side trips; parameterize "Friday"/"20th". |
| `plan-payroll` | **REWRITE** | 15+ | 6 (+1 on yes) | Real headroom equation + staged top-up path; drop Gmail/JE corroboration, calendar, Mode B, the "check again" inject section, and sibling-skill dependencies. |
| `invoice-chase` | **REWRITE** | 7 + N drafts | 3 + ≤ 3 drafts | Real drafts-only chase with bank exclusion; strip the seeded check #4471 / $7,200 / $520 figures and the `ar-health` profile dependency. |
| `ap-timing` | **REWRITE** | 10–15+ | 3–4 | Becomes a thin pay/hold table on top of `get_vendor_payment_timing`; drop the 12-month pairing, per-vendor bank loop, 4-week projection, and the $41k equipment-supplier example. |
| `cash-bridge` | **REWRITE** | 10+ | 5 | Reconciliation method worth keeping, but rebuilt on two `get_balance_sheet` snapshots; remove the "$14k in August" / $9k-distribution demo text. |
| `month-end-prep` | **REWRITE** | 14+ | 6 reads | The gross-to-net / unposted-fee / unrecorded-purchase method is real; drop the xlsx+PDF close packet, P&L narrative, receipts step, and mock-bank field docs. Still > 30 s — flag as non-live or scheduled. |
| `daily-cash-brief` | **REWRITE** (agent) | 20+ | ~11 (agent) | Scheduled agent's contract stays; remove dashboard regeneration, live-surface exceptions, KS/MO hard-coding; use the two new reports. |
| `tax-sweep-agent` | **REWRITE** (agent) | 8 + N | 5 | Scheduled agent's contract stays; `get_sales_tax_collected(Mon, today)` replaces payments→invoices→deposits; remove KS/MO and the "one week the owner did that" line. |
| `tax-season-organizer` | **REWRITE** (light) | 3 / 7 | 3 / 6 | Generic CPA-prep procedure, markdown output; fix stale 2025 tables, `get_account_transactions`, stablecoin text. |
| `smb-onboard` | **REWRITE** (light) | n/a (conversational) | n/a | Generic onboarding script; recipe table and examples point at cut skills and a nonexistent QB tool. |
| `what-if` | **CUT** | 15+ | — | Owner decided. Scenario levers over the forecast + Excel `Levers` sheet; names Westport and the van. |
| `business-pulse` | **CUT** | ~16 | — | "How is my business doing" is a summary the model composes from 5–6 calls; its only method (true available) belongs to `tax-reserve-check`; #1-issue table is the seeded live surface. |
| `ar-health` | **CUT** | 8 | — | Pure analysis (aging, DSO series, profiles, concentration); uses `search_credit_memos`; the profile rules move into `invoice-chase/reference/`. |
| `cash-flow-snapshot` | **CUT** | 15+ | — | 13-week forecast whose mandatory deliverable is `models/cash-13w.xlsx`; per-customer lag timing needs `ar-health`; consumers (`what-if`, dashboard, credit-readiness) are all cut. |
| `build-cash-dashboard` | **CUT** | 30+ | — | Static HTML + two xlsx files built by running five other skills' data steps. |
| `credit-readiness` | **CUT** | 20+ | — | PDF + xlsx bank package; depends on four cut/rewritten skills; SCENARIOS admits "~2 minutes". |
| `quarterly-review` | **CUT** | 10+ | — | PDF deck + 500–800-word narrative; HVAC job-costing and referral-Notes logic; `allowed-tools` frontmatter would block the connectors. |
| `subscription-audit` | **CUT** | 4 + 4N | — | Recurring-debit summary the model can do from one 12-month pull; "$349 ANGI LEADS" in the description; Step 4 is a seeded-QB workaround with rubric language. |
| `smb-router` | **CUT** | 0 | — | The skill catalog routes; the router adds a confirmation turn, contradicts "simple questions stay simple", and its table carries demo prompts verbatim. |
| `demo-setup` | **PRESENTER** | — | — | Demo tooling; leave. |
| `demo-inject` | **PRESENTER** | — | — | Demo tooling; leave. |
| `_shared/` | conventions (not a skill) | — | — | Keep. One dangling reference to `dashboard/cash.html` (AUTONOMY.md:43) to remove. |

Net: 2 KEEP, 10 REWRITE (2 of them agents, 2 light), 9 CUT, 2 PRESENTER. The plugin drops from 23 skills to 14 (12 product + 2 presenter).

Files outside `skills/` that name cut skills and must be edited: `paywhere-smb/README.md`, root `README.md`, `paywhere-smb/.claude-plugin/plugin.json` (description lists "cash bridge, AR health … 13-week forecast, cash dashboard"; keyword `hvac` violates rule 1), `demo/SCENARIOS.md` (beats 1.1, 1.3-analysis, 1.7, 1.8 follow-up, 1.9, all of Act 2), `demo/presenter-kit.md` (dashboard pre-run), `_shared/AUTONOMY.md:43`.

---

## Per-skill

### `pay-bills` — KEEP

**Why.** This is the reference for a good skill: an approval path for moving money that the model would not reliably reproduce unaided (open `Balance` not `TotalAmt`, pay saved payees by name, never default a rail, one dry run then one real batch, print the `/confirm` URL verbatim, never say "paid"). It is already budgeted: "Quick start — six calls, two owner turns" (`pay-bills/SKILL.md:33-48`). Tailoring is cosmetic but present: the description triggers on "pay Johnstone and Voltage" (`:14-15`), Step 2 says "pay Trane now too" (`:93`), and the example table rows are the demo's fixed amounts — `$6,850.00`, `$2,150.00`, `$1,900.00`, `$3,860.00` (`:127-130`; SCENARIOS.md:17-19 lists Johnstone $6,850 / Voltage $2,150 / Ironclad $1,900).

**Plan (6 calls, unchanged).** Turn 1, parallel: `search_bills {Balance > 0}` ∥ `list_saved_payees` ∥ `list_accounts` ∥ `query_transactions {debit, last 7 days}` → `make_batch_payment {dryRun: true}`. Turn 2 on "yes": `make_batch_payment`. Optional swap: `get_vendor_payment_timing` in place of `search_bills` gives days-until-due and the due-within-7 split pre-computed; same count.

**Remove.** Named vendors from the description (keep "pay X and Y (any named vendors)"); "pay Trane now too" → "pull a not-yet-due bill in"; replace the four table amounts with placeholders.

**Depends on.** `_shared/APPROVAL.md` (kept). Optional: `get_vendor_payment_timing`. Reference to `../ap-timing` (`:52-53, :192`) survives if `ap-timing` is rewritten; otherwise point at the report tool.

**Cross-references (inbound).** `what-if/SKILL.md`, `demo-setup/SKILL.md`, `demo-inject/SKILL.md`, `smb-router/*`, `smb-onboard/reference/onboard-checklist.md`, `ap-timing/SKILL.md`, `tax-season-organizer/SKILL.md`, `business-pulse/SKILL.md`, `month-end-prep/SKILL.md`, `paywhere-smb/README.md`.

---

### `big-purchase-decision` — KEEP (owner's decision; wording nits)

**Why.** Just rewritten to five calls and a verdict-first reply (`big-purchase-decision/SKILL.md:22-23, :33-57`); it encodes a real test (cushion = one payroll run + a week of debits; month-ends derived from one aggregate; cash / financed / not-now conditions in `reference/method.md:28-39`). Residual tailoring is vocabulary, not logic: "A profitable year on paper does not mean the van fits" (`:20`), the Gmail example query `"Transit"` (`:54`), the reply header `Van decision — {date}` (`:100`), `Second van:` (`:111`), and `method.md:88-89` "a January insurance + tax collision, the July payroll stack" (the seeded HVAC seasonality).

**Plan (5 calls, unchanged).** Parallel: `list_accounts` ∥ `query_transactions {Operating, aggregate, groupBy: month, 12 mo}` ∥ `query_transactions {Operating, debit, descriptionContains: <payroll stem>, limit: 6}` ∥ `search_threads <item/dealer>` → `get_thread`.

**Remove.** "van" → "{purchase}" in headers and follow-ups; drop the seasonal-cause examples in `method.md:88-89` or make them generic ("an annual premium landing on a slow month").

**Depends on.** Nothing in the plugin. Hands off to `credit-readiness` (`:113, :128`) — **that hand-off dangles after the cut**; replace with "Want a plain-text summary of twelve months of cleared cash for the bank meeting?"

**Cross-references (inbound).** `what-if/SKILL.md:53`, `cash-flow-snapshot/reference/model-layout.md:22`, `smb-router/*`, `demo/SCENARIOS.md`, `paywhere-smb/README.md`.

---

### `tax-reserve-check` — REWRITE

**Why.** A real, reusable procedure for any business that parks collected sales tax in a separate account: collected-on-received vs reserve balance → shortfall → staged catch-up transfer through the approval path. It is also the single most expensive interactive skill today: Step 3 follows every payment to its invoices (`tax-reserve-check/SKILL.md:74-81` — one `search_invoices` per payment), adds a `get_balance_sheet` / `get_general_ledger` cross-check (`:85-88`), a calendar lookup for the remittance date (`:98-101`), a 12-month sweep history (`:106-108`), a pending pull (`:122-123`) and IRS-estimate debits (`:124-128`). Tailoring: "Friday" sweeps and "the 20th" are Nick's rules from the project prompt (`cowork-project-prompt.md:25-29`) hard-wired into Steps 2 and 5; stems `DEPT OF REVENUE` (`:64`) and `TAX RESERVE` (`:107`) are the seeded descriptors; Step 5's "swept on invoiced, not received" note (`:113-115`) exists only because the dataset contains that one anomalous week (see `tax-sweep-agent/SKILL.md:51-52`).

**Plan (4 reads + 1 stage).** Parallel: `list_accounts` (balances; +2 `get_account_balance` if balances are not returned) ∥ `query_transactions {Tax Reserve, debit, descriptionContains: <remittance stem>, limit: 5}` (which month was last paid) ∥ `get_sales_tax_collected(window start, today)` (collected on received payments, by tax item and per payment) ∥ `query_transactions {Tax Reserve, credit, dateFrom: 12 mo}` (sweep history → missed sweep days). Then, on "stage the catch-up": `make_batch_payment {transfer line}` (optionally a `dryRun` first = 6).

**Remove.** Step 3 entirely (replaced by the report); the balance-sheet cross-check; the calendar call (remittance day is a parameter, default the 20th); Step 6's pending pull and IRS lines; the "swept on invoiced" test; hard-coded Friday → "sweep day (default Friday)".

**Depends on.** `get_sales_tax_collected` (new). `_shared/APPROVAL.md`. Should absorb `business-pulse/reference/true-available.md` (the short form of its own method) since `business-pulse` is cut and `plan-payroll` / `daily-cash-brief` link to that file.

**Cross-references (inbound).** `_shared/APPROVAL.md:97-100`, `tax-sweep-agent`, `tax-season-organizer`, `big-purchase-decision:40`, `business-pulse/*`, `plan-payroll`, `daily-cash-brief`, `cash-bridge:113`, `cash-flow-snapshot:45`, `build-cash-dashboard:44`, `smb-onboard/reference/onboard-checklist.md`, `smb-router/*`, `demo/SCENARIOS.md`, `paywhere-smb/README.md`.

---

### `plan-payroll` — REWRITE

**Why.** The headroom equation (`plan-payroll/SKILL.md:140-150`), the "never raid the reserve" rule and the staged savings→operating transfer (`:169-175`) are a genuine decision-plus-approval procedure. But the skill is far over budget: A2 corroborates the payroll number with a Gmail search and `search_journal_entries` (`:88-92`); A3 adds `search_bills`, `list_events` and a recurring-debit scan (`:99-107`); A4 is a five-step settlement detection needing `get_aged_receivables`, `search_invoices`, `query_transactions`, `search_payments` (`:116-127`); Mode B runs `cash-flow-snapshot` and `invoice-chase` (`:191-198`). Tailoring: the example "a church customer's check deposited Monday whose invoice is still open" (`:131-132`) is St. Anselm check #4471; A6 "Check again" (`:181-189`) exists for the "Westport just paid — check again" inject (SCENARIOS.md:176-178).

**Plan (6 reads; +1 on yes).** Parallel: `list_accounts` (balances) ∥ `query_transactions {Operating, debit, descriptionContains: <payroll stem>, 8 weeks}` ∥ `get_sales_tax_collected(window)` (reserve shortfall) ∥ `get_vendor_payment_timing` (bills due on/before payday; held bills excluded) ∥ `get_aged_receivables` ∥ `query_transactions {credit, posted, 14 days}` (received-but-unbooked exclusion by amount). Then if the owner picks the top-up: `make_batch_payment {transfer savings→operating}`.

**Remove.** Gmail and journal-entry corroboration; calendar; recurring-auto-debit scan; Mode B (no bank → "no verdict without the bank; here is what the books say is due"); A6 as a section (a re-check is one `get_account_balance` when asked); dependencies on `ar-health` profiles, `invoice-chase`, `ap-timing`, `cash-flow-snapshot`; the church example.

**Depends on.** `get_sales_tax_collected`, `get_vendor_payment_timing` (new), `_shared/APPROVAL.md`, `tax-reserve-check` (method reference only).

**Cross-references (inbound).** `smb-onboard/reference/onboard-checklist.md:24`, `demo-setup/SKILL.md:146`, `business-pulse/SKILL.md:107`, `smb-router/*`, `paywhere-smb/README.md`, root `README.md`.

---

### `invoice-chase` — REWRITE

**Why.** Drafts-only chasing with a bank exclusion step is a real procedure with a safety rule the model needs told (`create_draft` only; never chase an invoice whose cash already landed). But it is written against the seeded world: "a check reads `MOBILE CHECK DEPOSIT 4471`" (`invoice-chase/SKILL.md:69-70` — the demo's check number), "7 open balances against 41 posted credits since 7/1: one match" (`:73`), the ranking example "multi-site restaurant customer: $2,100, 38 days late … check-paying church whose $520 is 9 days late" (`:81-83`), and the table rows `$7,200 | 18 | routinely late` and `$520 | 9 | prompt | excluded — check #…` (`:102-104`) which are Westport and St. Anselm exactly (SCENARIOS.md:17-19). `reference/gotchas.md:9` names `ACH CR AVIDXCHANGE … property-management customer` (Cornerstone PM). It also inherits `ar-health`'s 12-month profile computation (`:50-54`) and calls `search_credit_memos` (`:47`, not in the tool set).

**Plan (3 reads + ≤ 3 drafts = 6).** Parallel: `get_aged_receivables` ∥ `search_customers` (AR contact emails) ∥ `query_transactions {credit, posted, dateFrom: oldest open invoice}`. Exclude amount matches; rank by open × days late; `create_draft` for the top ≤ 3 customers (one per customer). Tone from the days-late bucket by default (gentle < 15, neutral 15–45, firm > 45); history-based tone only when the owner asks "who pays late" (then `search_payments` 12 mo is a 4th read and drafts are capped at 2).

**Remove.** All seeded numbers and descriptors; the cash-impact × profile-factor scoring; `search_credit_memos`; the "Unattended" section (no agent exists). Move `ar-health/reference/profiles.md` to `invoice-chase/reference/profiles.md` if history-based tone is kept; otherwise delete and simplify `tone-matching.md:3-14` to the bucket rule.

**Depends on.** Gmail `create_draft`. No other skill after the rewrite.

**Cross-references (inbound).** `ar-health`, `business-pulse/*`, `plan-payroll`, `month-end-prep:96`, `daily-cash-brief:153`, `build-cash-dashboard/*`, `demo-setup:146`, `smb-onboard/reference/onboard-checklist.md`, `smb-router/*`, `demo/SCENARIOS.md`, `paywhere-smb/README.md`.

---

### `ap-timing` — REWRITE (thin) 

**Why.** The pay / hold / not-yet-due table and the hold rule (hold a not-yet-due bill from a habitually-early vendor; stage ~2 business days before due) is a small, reusable report definition. Everything else is what `get_vendor_payment_timing` now does server-side or is analysis: pairing 12 months of `search_bills` with `search_bill_payments` (`ap-timing/SKILL.md:37, :63-75`; `reference/early-payment-method.md:5-25`), a per-vendor `query_transactions` corroboration loop (`:72-75`; method `:29`), `search_vendors` for terms, `list_events`, and a two-scenario 4-week minimum-balance projection (`:95-103`). Tailoring: the worked example "an equipment supplier: 9 bills, paid a mean of 14 days early from autumn through spring, on the due date in summer — about $41k left the account two weeks before it had to" (`:79-81`) is the seeded Trane pattern (`liveSurface.earlyPayTemptation`); `method.md:15` "A supplier paid early all winter with nothing open in September" is dataset-shaped.

**Plan (3–4 calls).** Parallel: `get_vendor_payment_timing` ∥ `list_saved_payees` (rail column) ∥ `list_accounts` (Operating balance vs the pay-now total). Optional 4th: `query_transactions {debit, descriptionContains: <top habitual vendor stem>, 12 mo}` when the owner asks "is that real at the bank".

**Remove.** Steps 2 and 4 wholesale; `reference/early-payment-method.md` (the method now lives in the report; keep a two-line statement of the hold threshold); the calendar pull; DEFER candidates; the $41k example. Acceptable alternative if the team wants fewer skills: fold the hold rule into `pay-bills` Step 2 and delete `ap-timing`.

**Depends on.** `get_vendor_payment_timing` (new). Hands off to `pay-bills`.

**Cross-references (inbound).** `pay-bills:52-53,192`, `what-if:50`, `subscription-audit/*`, `cash-bridge:82,113`, `credit-readiness:48`, `business-pulse/*`, `cash-flow-snapshot:81`, `daily-cash-brief:115,247`, `plan-payroll:101,168,231`, `smb-onboard/reference/onboard-checklist.md:26`, `smb-router/*`, `demo/SCENARIOS.md:163`, `paywhere-smb/README.md`.

---

### `cash-bridge` — REWRITE

**Why.** Bridging net income to the change in the bank balance is a textbook reconciliation method (the indirect cash-flow statement), which is the category the owner wants kept. The current implementation is expensive and half-outside the tool set: ΔAR/ΔAP are rebuilt from every invoice/payment/bill on or before two dates (`cash-bridge/reference/method.md:19-27`), distributions need `search_transfers` + `search_journal_entries` (`SKILL.md:78`), equipment needs `search_purchases` + `search_bills` (`:81`), early payments need `search_bill_payments` joined to bills (`:82`). Tailoring is explicit: Step 1 quotes the demo prompt "I made about $14k in August" (`:48-49`); the paragraph "in the month after a peak, cash rises by *more* than profit … the receivables invoiced in the busy months are collected" (`:29-37`) was written to make SCENARIOS beat 1.2 land in September; both example paragraphs carry the seeded "$9k quarterly distribution" and the Tax Reserve sweep (`:116-126`).

**Plan (5 calls).** Parallel: `get_profit_and_loss(M)` ∥ `get_balance_sheet(as of end of M)` ∥ `get_balance_sheet(as of end of M−1)` ∥ `query_transactions {Operating, aggregate, groupBy: month, dateFrom: M−1 start}` (net(M) = operating cash change; month-end derivation) ∥ `query_transactions {Operating, debit, M}` (name the big non-P&L debits: owner draws, estimated taxes, reserve sweeps, equipment). Bridge lines from the two balance sheets: ΔAR, ΔAP, Δfixed assets/inventory, Δowner equity (distributions), Δsales-tax liability; depreciation from the P&L; residual computed.

**Remove.** The historical open-AR/open-AP reconstruction; `search_transfers`; the early-vendor-payment line (or source it from `get_vendor_payment_timing` only when the owner asks); both demo example paragraphs; the "$14k in August" wording.

**Depends on.** `get_balance_sheet` accepting an as-of date (confirm; if it only returns "today", the plan falls back to ΔAR from `get_aged_receivables` today vs `search_invoices/search_payments` for M−1 and rises to ~7 calls). `get_profit_and_loss`.

**Cross-references (inbound).** `credit-readiness:50`, `month-end-prep:130`, `smb-router/*`, `paywhere-smb/README.md`.

---

### `month-end-prep` — REWRITE

**Why.** Sections 4a–4c (merchant settlements gross-to-net, unposted fee lines, unrecorded card purchases — `month-end-prep/SKILL.md:61-86`) are the owner's canonical example of a reconciliation method the model would not invent. The rest violates the rules: the deliverable is `close/close-packet-YYYY-MM.xlsx` + a one-page PDF (`:137-141`; `reference/close-packet-format.md` in full); Step 2 fans out to nine QB searches including `search_deposits`, `search_transfers`, `search_credit_memos` (`:40-43`, not in the tool set); Step 3 pulls every account for the month (`:49-50`); Step 6 asks about receipts using `AttachmentCount` (`:105-107`); Step 8 is a 150–250-word P&L narrative (`:125-131`) — summary, and its example is a candle company (`reference/examples/pl-narrative.md`). `reference/paywhere-bank-lines.md:3` documents "The mock bank's transaction record has seven fields" and the seeded stems (`INTUIT PYMT SOLN DEPOSIT`, `<STATE> DEPT OF REVENUE`, `IRS USATAXPYMT`, `:37-40`); `reference/quickbooks-reconcile.md:46-50` describes raw-API pagination (`startPosition`) that no tool exposes.

**Plan (6 reads).** Parallel: `query_transactions {Operating, posted, month}` ∥ `search_payments {month}` (grouped by deposit date → gross) ∥ `search_purchases {month}` ∥ `search_bill_payments {month}` ∥ `search_journal_entries {month}` (payroll, fees) ∥ `get_profit_and_loss(month)` (fee-expense sanity check). Match in context; output a markdown reconciliation table + narrated fixes.

**Remove.** Steps 6–9 (receipts, sign-off ceremony, narrative, packet); `close-packet-format.md`, `examples/pl-narrative.md`; the mock-bank field documentation (keep a short "descriptor stems to look for" list, labelled as patterns); `search_deposits`/`search_transfers`/`search_credit_memos`; secondary accounts (Operating only unless asked). **Budget caveat:** even at 6 reads, matching ~100 rows is a long turn (> 30 s). Either accept it as a non-live skill or move it to the deferred `settlement-reconcile-agent` (SCENARIOS.md:419) where the agent rule applies.

**Depends on.** Nothing new. Hands off to `pay-bills`; the `cash-bridge` link (`:130`) survives.

**Cross-references (inbound).** `cash-bridge:84`, `daily-cash-brief:131,247`, `tax-season-organizer/*`, `demo-inject:94`, `smb-onboard/reference/onboard-checklist.md:25`, `smb-router/*`, `demo/SCENARIOS.md:419`, `paywhere-smb/README.md`, root `README.md`. Its `paywhere-bank-lines.md:58` links `subscription-audit/reference/normalization.md` (cut) — inline the three stripping rules or drop the link.

---

### `daily-cash-brief` — REWRITE (scheduled agent; budget exempt, note it)

**Why.** A scheduled agent's contract (stamp `sessionType`/`taskId`, dedupe on the output file, propose-never-execute, one batch, print the URL) is exactly what the owner wants encoded, and the brief is the plugin's Act 3 anchor. It fails the other rules as written: Step 6 regenerates `dashboard/cash.html` (`daily-cash-brief/SKILL.md:12, :165-172, :207, :216, :246`) — rule 4; the pull list is ~20 calls including `search_bill_payments` (12 months) and `search_deposits` (`:74-90`); two exceptions exist only for seeded items — "Unknown recurring debit" and "Unreconciled merchant settlements: count of bank `INTUIT PYMT SOLN DEPOSIT` rows" (`:126-131`, the live surface); stems `DEPT OF REVENUE` / `TAX RESERVE` are hard-coded (`:80-81`); the file template prints `(KS ${k} / MO ${m})` (`:184`).

**Plan (~11 calls; agent).** Parallel: `list_accounts` ∥ `query_transactions {pending}` ∥ `query_transactions {credit, 14 d}` ∥ `query_transactions {debit, today}` (duplicate check) ∥ `query_transactions {Tax Reserve, credit, 8 wk}` (sweeps) ∥ `list_saved_payees` ∥ `get_sales_tax_collected(window)` ∥ `get_aged_receivables` ∥ `get_vendor_payment_timing` ∥ `list_events {today → +7}` → `make_batch_payment` (transfer + due bills). Note in the skill that as an agent it is allowed to exceed the interactive budget.

**Remove.** Step 6 and every dashboard mention; the two live-surface exceptions; `search_bill_payments`, `search_deposits`, `search_bills`, `get_aged_payables` (the report covers them); KS/MO → "by jurisdiction"; the links to `business-pulse`, `build-cash-dashboard`, `ap-timing`, `month-end-prep`, `subscription-audit`.

**Depends on.** `get_sales_tax_collected`, `get_vendor_payment_timing` (new); `_shared/AUTONOMY.md`, `_shared/APPROVAL.md`; `tax-reserve-check` for the method text (move `true-available.md` there).

**Cross-references (inbound).** `_shared/AUTONOMY.md:35`, `business-pulse:124`, `build-cash-dashboard/*`, `cash-flow-snapshot/*`, `smb-router/*`, `demo/presenter-kit.md`, `paywhere-smb/README.md`.

---

### `tax-sweep-agent` — REWRITE (scheduled agent)

**Why.** Same category as the brief: a scheduled agent that computes one number and stages one transfer for approval. The "received, not invoiced" rule is a sound, generic reserve policy. Cost today: `search_payments` → `search_invoices` per applied invoice → `search_deposits` for grouping (`tax-sweep-agent/SKILL.md:82-86`), plus a prior-shortfall recomputation "as in tax-reserve-check" (`:106-111`). Tailoring: "the one week the owner did that is visible in the bank history" (`:51-52`) refers to a seeded anomaly; `(KS ${k} · MO ${m})` is printed in the file and the run output (`:132, :155`); `TAX RESERVE` stem hard-coded (`:80`). "Friday" is Nick's habit — make the sweep day a parameter.

**Plan (5 calls).** Parallel: `list_accounts` (Operating + reserve, unmasked numbers) ∥ `get_sales_tax_collected(Monday, today)` (per payment, by tax item) ∥ `query_transactions {credit, posted, Monday → today}` (bank cross-check: booked payment with no credit → exclude) ∥ `query_transactions {Tax Reserve, credit, 7 d}` (already swept?) → `make_batch_payment {one transfer line}`.

**Remove.** The payments→invoices→deposits chain; Step 3.4 prior-shortfall computation (one sentence pointing at `tax-reserve-check` instead); KS/MO; the anomaly sentence; `search_deposits`.

**Depends on.** `get_sales_tax_collected` (new); `_shared/AUTONOMY.md`, `_shared/APPROVAL.md`; `tax-reserve-check` (pointer only).

**Cross-references (inbound).** `_shared/AUTONOMY.md:35`, `_shared/APPROVAL.md:99`, `tax-reserve-check:185`, `smb-router/*`, `paywhere-smb/README.md`.

---

### `tax-season-organizer` — REWRITE (light)

**Why.** Generic for any SMB (the worked examples are a designer and a marketing agency — `reference/examples/*`), markdown deliverables (`tax-season-organizer/SKILL.md:210`), and both paths are defined procedures with a mandatory assumptions disclosure rather than free analysis: SE-tax math + bracket + safe harbor (Path 1), ≥ $600 payee aggregation + W-9 status + bank cross-check (Path 2). Defects: `reference/calculation-assumptions.md:46-77` hard-codes **2025** brackets, wage base and due dates (today is 2026-09-03 — the skill will state wrong dates); `reference/connector-queries.md:52` calls `get_account_transactions` and `:67` mentions "stablecoin payouts" (stale connector text); Path 2's year-long `query_transactions {debit}` (`SKILL.md:148`) likely truncates and needs slicing.

**Plan.** Path 1 (3 calls): `get_profit_and_loss(Jan 1 → last quarter end)` ∥ `list_accounts` ∥ `query_transactions {Operating, debit, descriptionContains: IRS|EFTPS|USATAXPYMT, YTD}`. Path 2 (6 calls): `search_vendors` ∥ `search_bill_payments {year}` ∥ `search_purchases {year}` ∥ `query_transactions {debit, H1}` ∥ `query_transactions {debit, H2}` → `get_transaction_detail` on the unmatched counterparties if needed (cap at one).

**Remove / fix.** Replace the 2025 tables with "use the current tax year's published figures and state the year" or a table keyed by year; drop `get_account_transactions` and the stablecoin exclusion; drop the `month-end-prep` descriptor reference (`SKILL.md:148`, `connector-queries.md:58`) if that file is trimmed.

**Depends on.** None. Points at `tax-reserve-check` (kept) and `pay-bills` (kept).

**Cross-references (inbound).** `tax-reserve-check:186`, `smb-onboard/reference/onboard-checklist.md:28`, `smb-router/*`, `paywhere-smb/README.md`.

---

### `smb-onboard` — REWRITE (light)

**Why.** Generic (hardware store / design studio examples), no demo entities, and an onboarding script + a memory-block format is a reusable procedure the model would not standardize on its own. It is not a live-demo skill (15–20 min by design) so the call budget does not apply. Defects: the prove-value recipe is `cash-flow-snapshot` (`reference/onboard-checklist.md:30, :47`; `reference/gotchas.md:16, :40`; `reference/examples/happy-path.md:27, :81`) — cut; the recipe table names `business-pulse` and `ap-timing → pay-bills` (`onboard-checklist.md:23, :26`); it references a `quickbooks-profile-info-update` tool that does not exist (`onboard-checklist.md:52`); memory location is inconsistent (`SKILL.md:61` "Cowork session memory directory" vs `happy-path.md:85` `~/.claude/CLAUDE.md`).

**Plan.** No tool budget. Edit the recipe table: cash flow → `tax-reserve-check` or a plain balances + 12-month aggregate answer; payroll → `plan-payroll`; close → `month-end-prep`; vendors → `pay-bills`; chasing → `invoice-chase`. Remove the QB profile tool paragraph; pick one memory location.

**Depends on.** The surviving skills only.

**Cross-references (inbound).** `smb-router/SKILL.md:37,107`, `paywhere-smb/README.md`, root `README.md`.

---

### `what-if` — CUT (owner decided)

**Why.** Scenario analysis over a forecast table — rule 2's textbook cut. It re-runs `cash-flow-snapshot` Steps 1–4 as its baseline (`what-if/SKILL.md:34-36`), needs `ap-timing` data and `search_employees`/`search_time_activities` (`:50-51`, not in the tool set), and writes a `Levers` sheet into `models/cash-13w.xlsx` (`:83-87`). Tailoring: "what if Westport pays late" in the description and lever table (`:12, :48`); "buy the van cash or financed" (`:8, :53-54, :69-70`).

**Instead.** "What if revenue drops 10% / my biggest customer pays 30 days late?" → the model pulls `get_account_balance`, `query_transactions {aggregate, month}`, `get_aged_receivables`, `get_vendor_payment_timing` and does the arithmetic in the reply.

**Cross-references to fix.** `cash-flow-snapshot/SKILL.md:27-28, :139-144`, `cash-flow-snapshot/reference/model-layout.md:59-63, :68`, `build-cash-dashboard/SKILL.md:87`, `smb-router/SKILL.md:9, :84, :127, :154`, `smb-router/reference/routing-table.md:17`, `paywhere-smb/README.md`, `demo/SCENARIOS.md:258-265` (beat 1.9).

---

### `business-pulse` — CUT

**Why.** "How is my business doing?" is a summary, and the skill says so about itself — it exists to fire ~16 calls in parallel (`business-pulse/SKILL.md:38-54`: `list_accounts`, 3 balances, 4 `query_transactions`, `get_profit_and_loss`, `get_aged_receivables`, `search_invoices`, `get_aged_payables`, `search_bills`, `search_payments`, `list_events`, `search_threads`) and lay them out in a fixed template. Its one method (true available cash) is explicitly owned elsewhere ("The full method … live in `../../tax-reserve-check/SKILL.md`; this is the pulse-sized version", `reference/true-available.md:3`). Step 3's #1-issue table (`:102-108`: late customer / bill about to be paid early / reserve short / unknown recurring debit) is the seeded live surface item-for-item (SCENARIOS.md:108-115). Hard-coded stems `DEPT OF REVENUE`, `TAX RESERVE`, `GUSTO` (`SKILL.md:44-45, :92`; `reference/data_sources.md:13-15`). `reference/thresholds.md:30-39` grades a "7-day sales trend" and "Failed transactions" the skill never computes — leftover template, a quality signal.

**Instead.** Plain question → `list_accounts`, `query_transactions {aggregate, groupBy: month, 12 mo}`, `get_aged_receivables`, `get_vendor_payment_timing`, `get_sales_tax_collected(window)` (5 calls) and the model writes the page; if the owner wants it every morning, that is `daily-cash-brief`.

**Relocate.** `reference/true-available.md` → `tax-reserve-check/reference/true-available.md` (linked by `plan-payroll:79`, `daily-cash-brief:97`).

**Cross-references to fix.** `daily-cash-brief/SKILL.md:23, :72, :97, :245`, `tax-reserve-check/SKILL.md:26-27, :184`, `plan-payroll/SKILL.md:79`, `ar-health/SKILL.md:159`, `build-cash-dashboard/SKILL.md:40, :46`, `smb-onboard/reference/onboard-checklist.md:23, :32, :48`, `smb-router/*`, `paywhere-smb/README.md`, `demo/SCENARIOS.md:104-115` (beat 1.1).

---

### `ar-health` — CUT

**Why.** Analysis only ("Reads only; hands off to invoice-chase", `ar-health/SKILL.md:11-12`): aging buckets the report already gives, a monthly DSO series that requires reconstructing open AR at each month-end from all invoices and payments (`:110-118`; `reference/profiles.md:30-36`), concentration, and a scoring formula (`:121-128`). Eight calls including `search_credit_memos` (`:50-57`, not in the tool set). The behavior-profile rules (`reference/profiles.md:7-18`) are the one reusable piece and only `invoice-chase` consumes them. The worked example "a property-management customer that pays through an AP-automation batch: routinely late, mean 14 days, 11 of 11 invoices" (`:87-89`) is the seeded Cornerstone PM / AvidXchange row.

**Instead.** "Who owes me money / who pays late / what's my DSO?" → `get_aged_receivables` + `search_payments {12 mo}` + `get_profit_and_loss {12 mo by month}`; the model computes lags and DSO. Longer term the natural home is a QB report mirroring `get_vendor_payment_timing` (per-customer payment lag stats) — one call, no skill.

**Relocate.** `reference/profiles.md` → `invoice-chase/reference/profiles.md` only if history-based tone survives the `invoice-chase` rewrite; otherwise delete.

**Cross-references to fix.** `invoice-chase/SKILL.md:6, :51, :139`, `invoice-chase/reference/tone-matching.md:3`, `plan-payroll/SKILL.md:136, :230`, `business-pulse/SKILL.md:88`, `cash-flow-snapshot/SKILL.md:58`, `credit-readiness/SKILL.md:47`, `quarterly-review/SKILL.md:67`, `build-cash-dashboard/SKILL.md:42, :96`, `smb-router/*`, `demo/SCENARIOS.md:133-143` ("analysis via ar-health"), `paywhere-smb/README.md`.

---

### `cash-flow-snapshot` — CUT

**Why.** Rule 4 first: Step 7 "Write the model (once per run)" makes `models/cash-13w.xlsx` a mandatory deliverable (`cash-flow-snapshot/SKILL.md:13, :146-154`; `reference/model-layout.md` is a 6-sheet Excel spec). Rule 3: opening position (4 calls), open invoices timed by each customer's 12-month lag (`:55-62` — needs `search_invoices` + `search_payments` history), 12-month credit aggregate, open bills, payroll pattern, "12 months of descriptors" for recurring debits (`:87-91`), `list_events` + `search_events` (`:98-105`) → 15+ calls and minutes. Rule 2: a forecast is a scenario answer; every consumer of its table (`what-if`, `build-cash-dashboard`, `credit-readiness`) is cut, and `plan-payroll` Mode B (its other consumer) is cut in the rewrite.

**Instead.** "How low does my cash get in the next 13 weeks?" → `get_account_balance`, `get_aged_receivables`, `get_vendor_payment_timing`, `query_transactions {aggregate, month, 12 mo}`, `query_transactions {debit, payroll stem}`, `list_events {13 wk}` (6 calls); the model builds the week table in the reply, timing invoices at due date.

**Cross-references to fix.** `ap-timing/SKILL.md:100, :136`, `big-purchase-decision/SKILL.md:129`, `credit-readiness/SKILL.md:54`, `plan-payroll/SKILL.md:192, :231`, `smb-onboard/*` (gotchas :16,:40; checklist :30,:47; happy-path :27,:81), `what-if/SKILL.md`, `build-cash-dashboard/SKILL.md:41, :81, :118`, `smb-router/*`, `paywhere-smb/README.md`.

---

### `build-cash-dashboard` — CUT

**Why.** The deliverables are a static `dashboard/cash.html` (`build-cash-dashboard/SKILL.md:51-76`; `reference/dashboard-spec.md`), `models/cash-13w.xlsx` (`:78-88`) and `tracking/collections.xlsx` (`:90-98`) — rule 4 three times. Step 1 "run the sibling skills' data steps" invokes `business-pulse`, `cash-flow-snapshot`, `ar-health`, `tax-reserve-check`, `subscription-audit` (`:35-46`) — 30+ calls. The skill itself concedes the limitation: "A static file cannot call MCP" (`:21`).

**Instead.** A live artifact is out of scope for now; until then the owner asks for the numbers and gets a markdown table from the same 5–6 calls listed under `business-pulse`.

**Cross-references to fix.** `daily-cash-brief/SKILL.md:12, :165-172, :207, :216, :246`, `cash-flow-snapshot/SKILL.md:151-153, :173-175`, `cash-flow-snapshot/reference/model-layout.md:3`, `what-if/SKILL.md:83-87`, `_shared/AUTONOMY.md:43` (`dashboard/cash.html` as an output-file example), `smb-router/SKILL.md:9, :90, :128, :156`, `smb-router/reference/routing-table.md:18-20`, `paywhere-smb/README.md`, `demo/SCENARIOS.md:269-291` (Act 2), `demo/presenter-kit.md`.

---

### `credit-readiness` — CUT

**Why.** Deliverables are `bank/credit-readiness-YYYY-MM-DD.pdf` and `.xlsx` (`credit-readiness/SKILL.md:73, :84`) — rule 4. It depends on `ar-health`, `ap-timing`, `cash-bridge`, `cash-flow-snapshot` (`:43-55`) and adds three intra-month row pulls (`:37-39`) — 20+ calls; SCENARIOS.md:245-247 already says "This follow-up is long (two files, ~2 minutes); show it from a saved transcript". The sizing rule "LOC size = gap × 1.25, rounded up to the nearest $5,000" (`reference/sizing.md:8`) is an invented heuristic, not a procedure a bank uses. The project prompt already instructs the model on financing framing (`cowork-project-prompt.md:100-108`), so the skill duplicates prompt-level steer.

**Instead.** "What should I bring to the bank?" → `query_transactions {aggregate, month, 12 mo}`, `list_accounts`, `get_profit_and_loss {12 mo}`, `get_balance_sheet` (4 calls) → a markdown memo: twelve months of cleared cash, the three lows, a request sized from the gap.

**Cross-references to fix.** `big-purchase-decision/SKILL.md:12, :113, :128` (the hand-off), `smb-router/SKILL.md:82, :119, :127, :156`, `smb-router/reference/routing-table.md:16`, `demo/SCENARIOS.md:242-247`, `paywhere-smb/README.md`.

---

### `quarterly-review` — CUT

**Why.** Output is `reviews/qbr-{YYYY-QN}.pdf` (`quarterly-review/SKILL.md:94`) and a 500–800-word narrative (`:85-90`) — rule 4 and rule 2. The method leans on tools outside the set (`get_customer_sales` `:53`, `search_time_activities` `:60`, `search_estimates` `:75`) and on HVAC-specific structure: "PROFITABILITY BY CUSTOMER from job costing (sub-customer jobs roll up to the parent; billable parts, subcontractor bills and tech hours" (`:8-11`), revenue classes "agreements / repairs / replacements / projects" (`:48-49`), referral partners read from customer Notes with "a fee paid on revenue not yet collected" (`:63-70` — the deferred `referral-fees` item, SCENARIOS.md:421). Bug: `allowed-tools: Read, WebFetch, Bash` (`:16`) restricts the skill to non-MCP tools, so as written it cannot call QuickBooks or the bank at all.

**Instead.** "How did Q2 go / are expenses growing faster than revenue?" → `get_profit_and_loss {quarter by month}` + `get_profit_and_loss {prior quarter}` + `query_transactions {credit, aggregate, month}` (3 calls); the model narrates in the reply.

**Cross-references to fix.** `build-cash-dashboard/SKILL.md:111`, `smb-router/SKILL.md:51, :157`, `smb-router/reference/routing-table.md:26`, `demo/SCENARIOS.md:421`, `paywhere-smb/README.md`.

---

### `subscription-audit` — CUT

**Why.** Finding recurring debits in a year of descriptors is summarization; the normalization rules (`reference/normalization.md`) are sensible but the model applies them without being told. Cost is unbounded: Step 0 is six calls for one debit (`subscription-audit/SKILL.md:41-57`), and Step 4 runs `get_transaction_detail`, `search_vendors`, `search_purchases`, `search_threads` **per recurring stem** (`:110-125`) — 4 + 4N. Tailoring: the description triggers on "what's this $349 ANGI LEADS debit" (`:13`); "an 'Angi Leads' or 'Yelp' plan" (`:94-95`); `normalization.md:18-21` examples are `ANGI LEADS`, `HOME DEPOT PRO #3008 KANSAS CITY MO`, `QUIKTRIP 0211 KANSAS CITY MO`; the zero-attribution flag reads referral sources from customer Notes (`:54-57, :133`) — seeded data. Step 4's `EntityRef` paragraph (`:113-129`) is a workaround written against the seeded QB, and "flagged orphaned, with no 'not confident enough' caveat" (`:126-127`) is grading language.

**Instead.** "What's this $X debit?" → `query_transactions {debit, descriptionContains, 12 mo}` + `get_transaction_detail` + `search_threads` (3 calls, no skill). "What subscriptions am I paying?" → `query_transactions {Operating, debit, posted, 12 mo}` (+ `search_vendors` if the owner wants "is it in the books") and the model groups repeats by stem and cadence.

**Relocate.** Nothing; `month-end-prep/reference/paywhere-bank-lines.md:58` links `normalization.md` — inline the rail-prefix/store-number/location stripping in one sentence.

**Cross-references to fix.** `business-pulse/SKILL.md:108`, `cash-flow-snapshot/SKILL.md:91`, `month-end-prep/SKILL.md:86`, `month-end-prep/reference/paywhere-bank-lines.md:30, :58`, `build-cash-dashboard/SKILL.md:45, :72`, `daily-cash-brief/SKILL.md:127`, `demo-setup/SKILL.md:140`, `smb-router/*`, `demo/SCENARIOS.md:194-206` (beat 1.7), `paywhere-smb/README.md`.

---

### `smb-router` — CUT

**Why.** The skill catalog (each skill's `description`) is what routes in Cowork; the repo's own recent eval work says so ("routing cases — the model picks from the skill catalog, and plain questions must stay plain", commit 96390e1). The router adds a turn — "One recommendation, one sentence why, one confirmation ask" (`smb-router/SKILL.md:117`), "Always confirm before triggering" (`:173`) — and its quick start turns "I'm stressed about Friday" into a `plan-payroll` proposal (`:25-31`), which conflicts with the project prompt's "Simple questions stay simple … do not load a skill for it" (`cowork-project-prompt.md:52-64`). It encodes no procedure. It is also the most demo-tailored file in the plugin: "Can I afford to buy a van this week for $58,500?" (`SKILL.md:81`); `reference/routing-table.md:8` "QuickBooks says I made about $14k in August", `:14` "What's this $349 'ANGI LEADS' debit?", `:15` "$58,500", `:17` "Westport pays 30 days late" — the SCENARIOS prompts verbatim. After the cuts, 9 of its 23 rows dangle.

**Instead.** "What can you do?" → the model lists the installed skills from the catalog; "How do approvals work?" → `_shared` conventions (already routed by its own description). If the team wants a fixed capability paragraph, put it in `paywhere-smb/README.md` and the plugin description.

**Cross-references to fix.** `paywhere-smb/README.md` only (nothing else links to the router).

---

### `demo-setup` — PRESENTER

`disable-model-invocation: true` (`demo-setup/SKILL.md:4`); seeds the presenter's mock-bank world and reads back the answer key. Not a product skill; leave. Inbound: `demo-inject`, `DATASET.md`, `TEST-PAYMENTS.md`, `demo/*`, `smb-router/*`, `paywhere-smb/README.md`. Its readback names `invoice-chase`, `plan-payroll`, `pay-bills`, `subscription-audit` (`:136, :140, :146`) — update the `subscription-audit` mention to "the enrichment beat".

### `demo-inject` — PRESENTER

`disable-model-invocation: true` (`demo-inject/SKILL.md:4`); posts deposits/withdrawals into the presenter's world. Not a product skill; leave. Inbound: `demo-setup:205`, `demo/SCENARIOS.md`, `demo/seed.md`, `smb-router/*`, `paywhere-smb/README.md`. It names `month-end-prep` / `settlement-reconcile` (`:94-95`) and `pay-bills` (`:132`) — both survive.

### `_shared/` — conventions, not a skill

Keep `APPROVAL.md`, `AUTONOMY.md`, `SKILL.md` as is. Edits after the cuts: `AUTONOMY.md:43` lists `dashboard/cash.html` as an example output file — remove; `APPROVAL.md:97-100` names `tax-reserve-check` and `tax-sweep-agent` (both kept). `_shared/SKILL.md` is correctly described as a reference skill and stays the answer to "did that payment go through".

---

## Follow-through checklist (outside `skills/`)

- `paywhere-smb/.claude-plugin/plugin.json`: description enumerates cut skills; drop keyword `hvac`.
- `paywhere-smb/README.md` and root `README.md`: skill lists.
- `demo/SCENARIOS.md`: beats 1.1 (`business-pulse`), 1.3 "analysis via `ar-health`", 1.7 (`subscription-audit`), 1.8 follow-up (`credit-readiness`), 1.9 (`what-if`), Act 2 (dashboard/Excel), 3.1's dashboard regeneration, rehearsal checklist item on `dashboard/cash.html`.
- `demo/presenter-kit.md`: dashboard pre-run.
- `cowork-project-prompt.md:112-114`: "Dashboards go to `dashboard/`, models to `models/`, … bank packages to `bank/`" — remove those three folders.
