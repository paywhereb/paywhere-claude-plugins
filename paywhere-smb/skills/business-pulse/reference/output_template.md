# Output Template

This is the exact structure every pulse must follow. Do not reorder sections. Omit a section only if its connector returned no data — never leave an empty header.

Variables in `{{double braces}}` are placeholders — replace with computed values. Arrow convention: ▲ up, ▼ down, ▬ flat (<1% change). Always show the delta value after the arrow.

---

```markdown
# Business Pulse — {{Day, Month Date, Year}}

**Overall: {{🟢|🟡|🔴}} {{one-line status, e.g. "Cash healthy, one overdue invoice needs attention."}}}**

## TL;DR

- {{Most important number-backed fact, e.g. "Cash balance $84k, down $6k WoW — two large vendor payments cleared."}}
- {{Second most important, e.g. "$3,400 from Acme Corp is 47 days overdue — no response since Mar 12."}}
- {{Third, e.g. "$2,000 wire to a vendor is pending past its same-day window — confirm it cleared."}}

---

## 💰 Cash & Finance — {{🟢|🟡|🔴}}

- **Cash position**: ${{TOTAL_AVAILABLE}} available ({{▲|▼|▬}} ${{DELTA}} WoW){{; ${{TOTAL_PENDING}} pending if nonzero}}
- **Accounts**: {{per-account breakdown — operating $X / payroll $X / reserve $X — from Paywhere `list_accounts` + `get_account_balance`}}
- **7-day inflow / outflow**: ${{INFLOW_7D}} in / ${{OUTFLOW_7D}} out (Paywhere settled lines)
- **MTD revenue (QB)**: ${{MTD}} vs. ${{PRIOR_MTD}} last month ({{▲|▼|▬}} {{PCT}}%)
- **Outstanding AR**: ${{AR_TOTAL}} across {{N}} open invoices

**AR aging**
- 0–30 days: ${{AR_0_30}}
- 31–60 days: ${{AR_31_60}} {{🟡 if nonzero}}
- 61+ days: ${{AR_61}} {{🔴 if nonzero}}

**Overdue > 30 days**
- {{customer}} — ${{amount}} ({{days}} days overdue)
- {{customer}} — ${{amount}} ({{days}} days)

---

## 📈 Revenue & Sales — {{🟢|🟡|🔴}}

- **Revenue trend (QB)**: ${{MTD}} this month vs. ${{PRIOR_MTD}} prior month ({{▲|▼|▬}} {{PCT}}%)
- **Cash inflow trend (Paywhere)**: ${{INFLOW_7D}} last 7 days vs. ${{INFLOW_PRIOR_7D}} prior 7 ({{▲|▼|▬}} {{PCT}}%)

**Pending money movement**
- {{wire/ACH}} from/to {{counterparty}} — ${{amount}} — {{days}} days past expected settle window
- {{or "Nothing unusually slow this week."}}

---

## ✉️ Watch List

- {{sender / source}} — {{one-line summary of what needs attention}}
- {{sender / source}} — {{summary}}
{{Or: "No urgent threads detected." — include this explicitly so the owner knows the check ran.}}

---

## ⚠️ #1 Priority

{{One specific thing to act on today. Name amounts, people, deadlines.
Not "review cash flow" — say "The $4,200 invoice from Acme Corp is 23 days
overdue. Call Sarah Chen at 415-555-0192 today."}}

---

## Appendix

**Window**: {{date range}}

**Sources pulled**: {{list of connectors that returned data}}

**Sources unavailable**: {{list with reason, e.g. "Gmail — auth error" or "QuickBooks — sync pending"}}

**Thresholds used**: {{note any TODO thresholds that are still defaults}}
```

---

## Formatting rules

1. **Dollar amounts**: `$43k` for thousands, `$1.2m` for millions. No unnecessary decimals.
2. **Percentages**: one decimal for trends (e.g. "▲ 8.3%"), integers elsewhere.
3. **Dates**: human-readable in prose ("Apr 14"), ISO in metadata ("2026-04-14").
4. **Arrow spacing**: `▲ $2k` not `▲$2k`.
5. **Length**: aim for one page. Two pages max. If a section balloons, tighten prose.
