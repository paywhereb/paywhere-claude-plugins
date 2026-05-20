# Gotchas

## Gotcha: Treating revenue as profit

An owner sees $50K in QuickBooks revenue and thinks that's what they made. It isn't — it's what they invoiced.

**Why it matters:** If you surface revenue figures without immediately pairing them with costs, the owner may misread the analysis and feel reassured when they shouldn't be.

### ✗ Bad
"Your revenue last quarter was $50,000."

### ✓ Good
"Your revenue last quarter was $50,000. After direct costs of $31,000, your gross profit was $19,000 — a 38% gross margin."

---

## Gotcha: Using list price instead of effective price

Owners often have discounts, refunds, and promotions that reduce what they actually receive per transaction. QuickBooks invoices may show list price; the cash that actually hit the bank (visible in Paywhere) is what matters.

**Why it matters:** If you compute margins using list price but the customer actually paid less (or refunded part), your cost-per-unit math will look better than reality.

### ✗ Bad
Use list-price invoice totals from QB as collected revenue → margin appears inflated.

### ✓ Good
Use QB invoice line items net of any credit memos or refunds for revenue. If the owner is unsure whether QB captures discounts cleanly, cross-check the deposit total against Paywhere credits for the same period — a meaningful gap means the QB invoice total is overstating what actually came in.

---

## Gotcha: Elasticity from a single price change

A business raised prices once, volume dipped for a month, then rebounded. Declaring that as "a 5% increase causes 3% volume loss" is overfit to one event.

**Why it matters:** One data point isn't a pattern. Seasonal dips, external events, or marketing changes may have caused the volume move, not the price change.

### ✗ Bad
"In March 2024, you raised prices 8% and volume fell 4%. Elasticity = −0.5."

### ✓ Good
"In March 2024, you raised prices 8% and the following month showed a 4% volume drop. Note: this is a single observation — the actual relationship between price and demand likely varies. I'll use this as a rough guide and show a range of scenarios."

---

## Gotcha: Ignoring service delivery costs for service businesses

For product businesses, COGS is usually clear (materials, manufacturing). For service businesses, owners often undercount their real cost — especially their own labor.

**Why it matters:** A service business can show 80% gross margin on paper while the owner is effectively paying themselves nothing after accounting for time.

### ✗ Bad
A freelance designer reports $0 COGS because they have no physical materials. Gross margin shows 100%.

### ✓ Good
Ask service businesses: "For this service, what does it cost you in time and any direct expenses to deliver it? Including your own labor at a rough hourly rate?" Use that as COGS for the analysis.

---

## Gotcha: QuickBooks COGS not broken down by product/service

Many small businesses use QuickBooks but record COGS as a single line item, not broken out by product. `profit-loss-quickbooks-account` may not return item-level cost data.

**Why it matters:** You can't compute per-product margins if COGS is lumped together.

### ✗ Bad
Call `profit-loss-quickbooks-account` → Get total COGS $22,000 → Try to divide across 12 products → Numbers are meaningless.

### ✓ Good
If QB doesn't have item-level COGS, ask the owner: "QuickBooks has your total costs but not a breakdown by product. Do you have a rough sense of what each item costs you to make or deliver? Even ballpark figures work." Proceed with owner-provided figures and flag the limitation in the output.

---

## Gotcha: Presenting scenarios as forecasts

The pricing scenario tables are math, not predictions. Volume elasticity is estimated from limited data, and real-world responses depend on competition, customer sensitivity, and timing.

**Why it matters:** An owner might act on the table as if it's a forecast, then feel misled when actual results differ.

### ✗ Bad
"If you raise prices 10%, you'll make $55,000 next quarter."

### ✓ Good
"If you raise prices 10% and volume drops ~5% (based on available history), revenue would be approximately $53,000. This is a rough projection — actual results will depend on your specific customers and competitive environment."
