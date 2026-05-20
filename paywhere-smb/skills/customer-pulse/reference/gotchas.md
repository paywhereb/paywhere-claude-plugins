# Gotchas — customer-pulse

## Gotcha: Verbatim quotes paraphrased or summarized

**Why it matters:** The owner needs to see the actual customer words — not Claude's interpretation. Paraphrase destroys the credibility of the report.

### ✗ Bad
**Theme: Slow shipping** (8 signals)
> Customers reported that deliveries arrived later than expected.

### ✓ Good
**Theme: Slow shipping** (8 signals)
> "Ordered 2 weeks ago and still nothing — this is unacceptable." — [Gmail]
> "Package was 10 days late and support never responded." — [Intercom]

---

## Gotcha: HubSpot returning 0 tickets treated as an error

**Why it matters:** Test portals and new accounts legitimately have 0 tickets. Surfacing a warning creates noise and erodes trust.

### ✗ Bad
> ⚠️ HubSpot returned 0 tickets. Check your connection or permissions.

### ✓ Good
Record `HubSpot tickets: 0` in the Sources section and continue. Only flag a connector issue if authentication itself fails.

---

## Gotcha: Gmail keyword list too narrow

**Why it matters:** Customers don't use standard complaint keywords. A 1-star experience often surfaces as "took forever" or "never again," not "disappointed."

### ✗ Bad
Search only for: `refund cancel unhappy`

### ✓ Good
Use the full seed list from Workflow step 3: `refund cancel unhappy issue problem disappointed frustrated broken late slow wrong missing`. Let theme-extraction filter signal from noise — over-inclusion is cheaper than missed themes.
