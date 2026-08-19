# Retail Promotion Intelligence — Power BI Dashboard

> **Are promotions driving real incremental sales, or are they simply subsidizing purchases customers would have made anyway?**

The Power BI report is the final analytical and visualization layer of the **Retail Promotion Intelligence** project. It transforms the curated Gold-layer data and business logic into an interactive four-page dashboard covering executive performance, campaign effectiveness, promotion mechanics, and household-segment response.

The dashboard is designed to move from **business-level performance → campaign performance → promotion effectiveness → customer/household response**, allowing users to evaluate not only how much was spent on promotions, but whether that investment generated measurable incremental sales.

---

## 📊 Dashboard Access

### Power BI Dashboard

The complete Power BI dashboard is available as a PDF, containing all four report pages along with the different slicer, switch, and dynamic-filter views.

**[View / Download the Power BI Dashboard PDF](./Retail_Promotion_Intelligence_Dashboard.pdf)**

> The PDF provides a static representation of the Power BI report and is intended for dashboard preview and documentation.

### Interactive Power BI Report

The original `.pbix` report is available separately for users who want to explore the dashboard interactively in **Microsoft Power BI Desktop**.

**[Download the Interactive Power BI Report](YOUR_PBIX_DOWNLOAD_LINK_HERE)**

> The `.pbix` file is hosted externally because its file size exceeds GitHub's repository file-size limits.


---

## 📑 Dashboard Pages

| Page                                    | Focus                             | Main Business Question                                                                 |
| --------------------------------------- | --------------------------------- | -------------------------------------------------------------------------------------- |
| **1. Executive Overview**               | Overall promotion economics       | Are promotions generating incremental sales relative to the behavioral baseline?       |
| **2. Campaign & Coupon Performance**    | Campaign and coupon effectiveness | Which campaigns generated incremental lift, and how efficiently were coupons redeemed? |
| **3. In-Store Promotion Effectiveness** | Display and mailer performance    | Which promotion mechanics actually drive incremental sales?                            |
| **4. Household Segments & Loyalty**     | Customer/household response       | Which household segments respond most strongly to promotions?                          |

---

# 1. Executive Overview

### Purpose

The Executive Overview provides the business-level view of promotional investment and its resulting incremental sales.
It compares `discount spend` against `incremental sales over time` and provides headline KPIs for:

- Total Discount Spend
- Total Incremental Sales
- Wasted Spend
- Coupon Mix
- Incremental Sales Period-over-Period (PoP)

The page can be viewed across different time granularities, including the overall daily trend as well as monthly/quarterly/ yearly drill-down views.

### Key Findings

- Total discount spend is approximately `$1.45M`.
- Total incremental sales are approximately `$230.66K`.
- Discount spend is approximately `6× incremental sales`, generating roughly `$0.16` of incremental sales for every $1 spent on discounts.
- `18.97%` of discount spend is classified as wasted spend.
- Coupons account for only `3.46%` of total discount spend.
- Incremental sales show a `4.52% PoP change` in the displayed executive view.

### Business Interpretation

The executive view indicates that promotional investment is substantially larger than the incremental sales generated from that investment. Promotional efficiency therefore needs to be evaluated at a more granular level rather than assuming that higher promotional spending automatically produces proportional incremental sales.

The next pages identify **which campaigns, promotion mechanisms, and household segments** are responsible for stronger or weaker outcomes.

---

# 2. Campaign & Coupon Performance

### Purpose

This page evaluates individual campaign performance and coupon redemption efficiency.
The main visual combines:

- Incremental lift by campaign
- Coupon redemption rate
- Campaign-level actual sales
- Lift versus behavioral baseline
- Campaign lift contribution
- Campaign Type filtering

### Key Metrics

- Top 5 Campaign Contribution
- Total Incremental Lift
- Redemption Rate
- Campaign-level actual sales
- Lift % versus baseline

### Key Findings

Across the overall campaign view:

- Total incremental lift is approximately `-$24.86M`.
- Coupon redemption rate is approximately `39.80%`.
- Many campaigns show substantial negative lift relative to their behavioral baseline.
- Campaigns shown in the dashboard are frequently `85–93%` below baseline.
- The top five campaigns contribute only `2.28%` of total lift in the displayed campaign view.

The report also allows users to filter by **Campaign Type**, revealing how campaign performance and redemption behavior change across different campaign groups.

### Important Interpretation

Campaign performance should be interpreted at the campaign level rather than by blindly summing across all campaigns.

Campaigns can overlap, and a household may legitimately belong to multiple campaigns at the same time. The project's business logic deliberately allows activity to count toward each campaign the household genuinely participated in. Therefore, campaign-level totals should not automatically be interpreted as an additive, unique business-wide total.

---

# 3. In-Store Promotion Effectiveness

### Purpose

This page evaluates the effectiveness of two promotion mechanisms:

- **Display promotions**
- **Mailer promotions**

The report allows the analysis to be switched between **Store** and **Category** perspectives.

### Key Metrics

- Total Actual Sales
- % Sales Under Promotion
- Mailer Lift per Day
- Display Lift per Day
- Promotion lift by store/category
- Actual sales over time by promotion combination

### Key Findings

- Total actual sales associated with promotions are approximately `$8.06M`.
- Promotional activity covers approximately `19.33%` of category sales.
- **Mailer promotions generate approximately `$1.15K` of incremental lift per day**.
- **Display promotions show approximately `-$167.71` of lift per day** in the displayed analysis.
- Mailer performance is therefore substantially more favorable than display performance in the overall view.

The category and store switches reveal that promotion effectiveness is not uniform. Some categories and stores show positive lift while others show weak or negative results.

### Business Interpretation

The results suggest that promotional mechanics should not be treated as interchangeable.

A promotion that generates sales activity does not necessarily generate incremental sales. The causal-promotion analysis therefore separates **actual sales** from the estimated **incremental lift attributable to the promotion mechanism**.

The dashboard also distinguishes between tracked and untracked causal activity so that missing causal records are not automatically interpreted as confirmed absence of promotion.

---

# 4. Household Segments & Loyalty

### Purpose

This page evaluates how promotional response differs across household characteristics.
The dynamic **Household Segment Dimension** allows analysis by:

- Age Group
- Income Level
- Household Size
- Marital Status
- Homeownership Status
- Household Composition
- Kid Category

A **Significance Threshold %** control is also provided to focus the analysis on statistically/significantly differentiated segment performance.

### Key Metrics

- Distinct Households
- Total Segment Lift
- Total Discount Received
- Average Incremental Lift per Household

### Overall Results

The displayed overall view contains:

- `1,584` targeted households
- `$1.09M` total segment lift
- `$559.74K` total discount received
- `$690.28` average incremental lift per targeted household

### Key Findings

The household analysis shows that promotional response varies substantially across demographic and household characteristics.

For example, the **age-group analysis** displays an inverted-U pattern:

- Middle-age household segments outperform the average by approximately `59–78%`.
- Younger, older, and unknown-demographic groups underperform.

The same framework can then be applied to income, household size, marital status, homeownership, household composition, and kid category to identify segments with stronger or weaker incremental response.

### Business Interpretation

The dashboard shifts the question from:

> "Did the promotion work?"

to:

> "For whom did the promotion work?"

This allows promotional strategies to be evaluated at the household-segment level rather than applying the same promotional approach to every customer.

---

# 🔍 Interactive Features

The report is designed for interactive exploration rather than static reporting.

### Navigation

The top navigation allows movement between:

- **Executive**
- **Campaigns**
- **Promotions**
- **Customers**

### Date Filtering

The Executive page includes a date range selector that allows users to analyze a selected period.

### Campaign Type

The Campaign page includes a dynamic **Campaign Type** selector so campaign performance can be examined across different campaign groups.

### Promotion Perspective

The Promotion page can switch the analysis between:

- **All**
- **Store**
- **Category**

This changes the level at which promotion effectiveness is examined.

### Household Segment Dimension

The Customer page uses a dynamic dimension selector to switch between different household characteristics.

### Significance Threshold

The household page includes a configurable **Significance Threshold %** that controls which segment differences are highlighted as significant.

---

# 📐 Core Business Logic

The dashboard is built around several core analytical concepts.

`Behavioral Baseline:` The behavioral baseline represents what a household or the business would have been expected to spend without the campaign. It is based on observed non-campaign spending and is projected across the relevant comparison window.

`Incremental Sales / Lift:` This represents the sales attributed to the promotion beyond the expected behavioral baseline.

```text
Incremental Sales = Actual Sales − Behavioral Baseline
```

`Wasted Spend:` Wasted spend represents discount dollars associated with purchases that would have occurred at or below the behavioral baseline. The project floors this value at zero so that wasted spend cannot become negative.

`Total Discount Spend:`

```text
Total Discount Spend = Retail Discount + Coupon Discount + Coupon Match Discount
```

`Coupon Mix:`

```text
Coupon Mix % = Coupon Discount ÷ Total Discount Spend
```

`Redemption Rate:`

```text
Redemption Rate % = Distinct Coupons Redeemed ÷ Distinct Coupons Distributed
```

Both sides of the redemption calculation must be evaluated at a matching grain.

`Campaign Lift Rank:` Campaigns are ranked using their incremental lift to identify the strongest and weakest campaign performers.

`Top 5 Contribution:`

```text
Top 5 Contribution % = Lift from Top 5 Campaigns ÷ Lift from All Campaigns
```

---

# 🧠 Important Analytical Conventions

* **Campaign Overlap:** Campaigns may run concurrently, and the same household may be targeted by multiple campaigns.

    The project intentionally allows activity to contribute to every campaign the household genuinely belongs to. Consequently, totals across all campaigns should not automatically be interpreted as unique business-wide totals.

* **Grain:** Every analytical table represents a specific level of detail.
Examples include:

    - One row per calendar date
    - One row per campaign + commodity category
    - One row per household + campaign

    Measures should therefore be interpreted and aggregated only at an appropriate grain.

* **Reliability Threshold:** Household baseline rates are only trusted when sufficient observed non-campaign days are available. The project uses a minimum observation threshold to prevent noisy short-period behavior from being extrapolated across longer campaign windows.

* **Unknown Records:** Unknown household and product records are retained through explicit flags rather than silently dropped. This allows unknown or unmatched records to remain visible and filterable during analysis.

* **Catch-All Category:** `COUPON/MISC ITEMS` is treated as a catch-all category and excluded from category-level lift analysis so that it does not distort comparisons between meaningful product categories.

---

# 📊 Key Analytical Takeaways

The Power BI report brings the project together into four main conclusions:

### 1. Promotional spending is much larger than the incremental sales generated
The executive view shows approximately **$1.45M in discount spend versus `$230.66K` in incremental sales**, indicating that promotional efficiency is a major business concern.

### 2. Promotion effectiveness varies substantially by campaign
Campaign-level results show that many campaigns generate negative incremental lift relative to baseline, while the strongest campaigns account for only a small share of total campaign lift.

### 3. Promotion mechanics matter
Mailer promotions show positive incremental lift in the displayed overall view, while display promotions show negative lift. Store- and category-level analysis further demonstrates that performance varies by context.

### 4. Customer targeting matters
Household-level analysis reveals meaningful differences in promotional response. Middle-age segments are among the stronger performers, while several younger, older, and unknown-demographic groups underperform.

`Overall implication:` promotional strategy should move from broad, uniform discounting toward **campaign-, mechanism-, and customer-segment-level evaluation**.

---

# 📁 Files in This Folder

```text
powerbi/
│
├── README.md
└── Retail_Promotion_Intelligence_Dashboard.pdf
```
---

# ▶️ How to Use the Report

1. Download the `.pbix` Power BI report.
2. Open it using **Microsoft Power BI Desktop**.
3. Navigate between the four report pages using the top navigation. When viewing the report in **Power BI Desktop**, press and hold `Ctrl` while clicking a navigation button.
4. Use the date filters and page-specific slicers to explore different views.
5. Hover over visuals to inspect detailed values.
6. Use the campaign, promotion, and household-segment selectors to drill into specific business questions.
7. Use the dynamic dimensions and significance threshold on the Customer page to compare household segments.

---

# ⚠️ Interpretation Notes

* Incremental lift is measured relative to a **behavioral baseline**, not simply as a comparison of promoted versus non-promoted sales.
* Negative incremental lift indicates performance below the estimated behavioral baseline.
* Campaign totals should be interpreted carefully because campaigns may overlap.
* Promotion effectiveness is based on the available causal tracking data; an absent causal record does not necessarily mean that no promotion occurred.
* Category-level analysis excludes the `COUPON/MISC ITEMS` catch-all category.
* Unknown household/product records are retained explicitly rather than removed.
* Always consider the **grain** of a metric before aggregating it.

---

