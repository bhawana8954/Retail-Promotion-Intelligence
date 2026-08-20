# Retail Promotion Intelligence — Power BI Dashboard

> **Are promotions driving real incremental sales, or are they simply subsidizing purchases customers would have made anyway?**

The Power BI report is the final analytical and visualization layer of the **Retail Promotion Intelligence** project. It transforms the curated Gold-layer data into an interactive four-page dashboard covering executive performance, campaign effectiveness, promotion mechanics, and household-segment response — moving from **business-level performance → campaign performance → promotion effectiveness → customer/household response**.

For full metric definitions, formulas, and analytical conventions (grain, campaign overlap, reliability thresholds, etc.), see [`docs/gold_layer_business_logic_and_terminology.md`](../docs/gold_layer_business_logic_and_terminology.md).

---

## 📊 Dashboard Access

**[View / Download the Power BI Dashboard PDF](./Retail_Promotion_Intelligence_Dashboard.pdf)** — static snapshot of all four pages, including slicer, switch, and dynamic-filter views.

**[Download the Interactive Power BI Report](YOUR_PBIX_DOWNLOAD_LINK_HERE)** — hosted externally, since the `.pbix` exceeds GitHub's file-size limit. Open in Microsoft Power BI Desktop.

---

## 📑 Dashboard Pages

| Page | Focus | Main Business Question |
|---|---|---|
| `1. Executive Overview` | Overall promotion economics | Are promotions generating incremental sales relative to the behavioral baseline? |
| `2. Campaign & Coupon Performance` | Campaign and coupon effectiveness | Which campaigns generated incremental lift, and how efficiently were coupons redeemed? |
| `3. In-Store Promotion Effectiveness` | Display and mailer performance | Which promotion mechanics actually drive incremental sales? |
| `4. Household Segments & Loyalty` | Customer/household response | Which household segments respond most strongly to promotions? |

---

## 1. Executive Overview
Compares discount spend against incremental sales over time, with headline KPIs and daily/monthly/quarterly/yearly drill-down.

- Total discount spend: `~$1.45M` vs. total incremental sales: `~$230.66K` (~6× spend-to-lift, roughly $0.16 incremental sales per $1 spent)
- Wasted spend: `18.97%` of discount spend
- Coupon mix: `3.46%` of total discount spend
- Incremental sales PoP change: `4.52%`

**Takeaway:** Promotional spend is substantially larger than the incremental sales it produces — efficiency needs to be evaluated at a more granular level, not assumed to scale with spend.

---

## 2. Campaign & Coupon Performance
Evaluates individual campaign performance and coupon redemption efficiency; filterable by Campaign Type.

- Total incremental lift: `~-$24.86M`; most campaigns run `85–93%` **below baseline**
- Coupon redemption rate: `39.80%`
- Top 5 campaigns contribute only `2.28%` of total lift

**Takeaway:** Campaigns can overlap — a household may belong to several at once — so campaign-level totals aren't a unique business-wide sum. Interpret at the campaign level, not by summing across all campaigns.

---

## 3. In-Store Promotion Effectiveness
Compares display vs. mailer promotion mechanics, switchable between Store and Category perspectives.

- Total actual sales under promotion: `~$8.06M`, covering `19.33%` of category sales
- Mailer lift: `~$1.15K/day` (positive) vs. display lift: `~-$167.71/day` (negative)
- Effectiveness varies meaningfully by store and category — not uniform

**Takeaway:** Sales activity under a promotion isn't the same as incremental sales from that promotion; the two mechanics shouldn't be treated as interchangeable.

---

## 4. Household Segments & Loyalty
Compares promotional response across age group, income, household size, marital status, homeownership, composition, and kid category, with an adjustable significance threshold.

- `1,584` targeted households, `$1.09M` total segment lift, `$690.28` average incremental lift per household
- Age group shows an inverted-U pattern: middle-age segments `+59–78%` above average; younger, older, and unknown-demographic groups underperform

**Takeaway:** Shifts the question from "did the promotion work?" to "for whom did the promotion work?" — enabling segment-level rather than uniform promotional strategy.

---

## 🔍 Interactive Features

- **Navigation:** top nav across Executive / Campaigns / Promotions / Customers
- **Date filtering:** range selector on the Executive page
- **Campaign Type:** dynamic selector on the Campaign page
- **Promotion Perspective:** All / Store / Category switch on the Promotion page
- **Household Segment Dimension:** dynamic dimension selector on the Customer page
- **Significance Threshold %:** configurable control on the Customer page to highlight statistically differentiated segments

---

## 📁 Files in This Folder

```text
powerbi/
│
├── README.md
└── Retail_Promotion_Intelligence_Dashboard.pdf
```

---

## ▶️ How to Use the Report

1. Download the `.pbix` report and open it in **Microsoft Power BI Desktop**.
2. Navigate between the four pages via the top navigation (hold `Ctrl` while clicking in Desktop).
3. Use date filters and page-specific slicers to explore different views.
4. Hover over visuals for detailed values.
5. Use the campaign, promotion, and household-segment selectors to drill into specific business questions.
6. Use the dynamic dimension selector and significance threshold on the Customer page to compare household segments.

---

## ⚠️ Interpretation Notes

- Incremental lift is measured relative to a **behavioral baseline**, not a simple promoted-vs-non-promoted comparison.
- Negative lift indicates performance below the behavioral baseline.
- Campaign totals should be read carefully — campaigns may overlap.
- An absent causal record doesn't necessarily mean no promotion occurred.
- Category-level analysis excludes the `COUPON/MISC ITEMS` catch-all category.
- See [`docs/gold_layer_business_logic_and_terminology.md`](../docs/gold_layer_business_logic_and_terminology.md) for full metric definitions, formulas, and analytical conventions (grain, unknown records, reliability thresholds, etc.).