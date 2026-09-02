# Routing table — §8 demo prompts → skill

The exact Act 1–3 prompts from the run-of-show (`demo/SCENARIOS.md`) and the skill whose description carries the matching trigger phrase.

| Beat | Owner says | Skill | Trigger phrase in that skill's description |
|---|---|---|---|
| 1.1 | "How is my business doing?" | `business-pulse` | "how is my business doing" |
| 1.2 | "QuickBooks says I made $9k last month. Why is my cash lower?" | `cash-bridge` | "QuickBooks says I made money last month, why is my cash lower" |
| 1.3 | "Who owes me money and who do I call first?" | `invoice-chase` (analysis via `ar-health`) | "who owes me money and who do I call first" |
| 1.4 | "What's due this week, and am I paying anyone early?" | `ap-timing` → `pay-bills` | "what's due this week" / "am I paying anyone early" |
| 1.4b | "Pay the bills due this week" | `pay-bills` | "pay the bills due this week" |
| 1.5 | "Am I good for payroll Friday?" | `plan-payroll` | "am I good for payroll Friday" |
| 1.6 | "How much of my balance is actually mine?" | `tax-reserve-check` | "how much of my balance is actually mine" |
| 1.7 | "What's this $349 'ANGI LEADS' debit?" / "What subscriptions am I paying?" | `subscription-audit` | "what's this <amount> <descriptor> debit" / "what subscriptions am I paying" |
| 1.8 | "Can I afford the van? Cash or finance? When? And a second one?" | `big-purchase-decision` | "can I afford the van" / "cash or finance" |
| 1.8b | "What should I bring to the bank?" | `credit-readiness` | "what should I bring to the bank" |
| 1.9 | "What if revenue drops 10%… Westport pays 30 days late… I hire a tech… I stop paying vendors early?" | `what-if` | "what if revenue drops 10%" … |
| 2.1 | "Build me a cash dashboard I can open every morning" | `build-cash-dashboard` | "build a cash dashboard I can open every morning" |
| 2.2 | "Build a 13-week cash model in Excel I can play with" | `build-cash-dashboard` | "build a 13-week cash model in Excel" |
| 2.3 | "Build a collections tracker" | `build-cash-dashboard` | "build a collections tracker" |
| 3.1 | "Run my morning cash brief" (scheduled: every weekday 7:30am) | `daily-cash-brief` | "run my morning cash brief" |
| 3.5 | "Run the Friday tax sweep" (scheduled: Fridays 4pm) | `tax-sweep-agent` | "run the Friday tax sweep" |
| 0 | "/demo-setup" | `demo-setup` | "set up the demo" |
| inject | "Westport just paid" (presenter) | `demo-inject` | "simulate <customer> paying" |

Other common asks: "13-week forecast" → `cash-flow-snapshot`; "close the books" → `close-month`; "Friday recap" → `friday-brief`; "QBR" / "most profitable customers" → `quarterly-review`; "estimated taxes" / "1099s" → `tax-prep`; "how do approvals work" → `conventions`.
