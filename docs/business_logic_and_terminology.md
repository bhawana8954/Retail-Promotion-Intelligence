# Retail Promotion & Customer Loyalty Intelligence Platform
## Business Logic & Terminology Reference

This document provides a consolidated reference for the **core business logic, analytical conventions, Power BI/DAX terminology, and key metric definitions** used in the Retail Promotion & Customer Loyalty Intelligence Platform.

For Gold-layer table definitions and schema, see the [Gold Layer](./scripts/gold/).

It is intended to serve as the single source of truth for the business logic and calculations behind the Gold layer and the finished four-page Power BI report.

---

## 1. Core Business Question

> **Are promotions driving real incremental sales, or are they mainly subsidizing purchases customers would have made anyway?**

Every Gold-layer table and Power BI metric supports some part of this question — from the overall business view on the **Executive Overview**, to individual campaigns and coupons, promotion mechanics, and household segments.

---

## 2. Core Business Concepts

### 2.1 Behavioral Baseline

The **behavioral baseline** estimates what a household or the business would have spent if the campaign or promotion had not occurred.

The  Gold logic uses the household's observed **non-campaign spending rate** and projects it across the relevant campaign period:

```text
baseline_daily_rate
    = household's total non-campaign spend ÷ total non-campaign calendar days

behavioral_baseline_spend
    = baseline_daily_rate × campaign duration
```

The denominator is based on the number of available **non-campaign calendar days across the dataset**, rather than the household's own shopping-day count. This ensures that infrequent and frequent shoppers are evaluated against the same time window.

### 2.2 Incremental Sales / Incremental Lift

**Incremental lift** represents sales attributed to the promotion above the behavioral baseline.

```text
Incremental Lift = Actual Sales − Behavioral Baseline
```

- **Positive lift:** actual sales exceeded expected behavior.
- **Negative lift:** actual sales were below the projected baseline.

This is the project's primary measure of genuine promotional impact.

### 2.3 Targeted Households

**Targeted households** are households that were actually reached by a campaign according to `silver.campaign_table`. They are different from households that merely happened to transact during the campaign period.

Campaign-level calculations use targeted household + campaign pairs where appropriate so that the analysis answers:

> Did the households we actually targeted respond to the promotion?

rather than:

> Did spending go up among anyone who happened to shop during the campaign window — targeted or not?

### 2.4 Active Campaign Days

An **active campaign day** is any calendar day that falls within at least one campaign's `start_day`–`end_day` range in `silver.campaign_desc`.

This is a **calendar-based**, not transaction-based, definition. A household does not need to transact for the day to be considered part of the campaign period.

### 2.5 Reliability / Minimum-Day Threshold

Baseline and lift estimates based on very few observations can be unstable. The project therefore uses minimum observation thresholds.

- `is_reliable_pair` in `fact_campaign_lift` requires **at least 5 baseline days and 5 campaign days**.
- Category-level baseline inclusion requires **at least 5 observed non-campaign days**.

These thresholds prevent short, noisy observation periods from being extrapolated into longer campaign windows.

### 2.6 Wasted Spend

**Wasted spend** represents promotional discount dollars associated with purchases that appear to have occurred at or below the customer's expected baseline.

It is evaluated at the **household-day level**:

```text
IF the day is within an active campaign
AND actual household spend <= baseline daily rate
THEN the day's full discount amount is classified as wasted
ELSE 0
```

The value is **floored at zero**. A day cannot generate negative wasted spend.

### 2.7 Campaign Overlap / Multi-Reporting

Campaigns may run concurrently, and the same household may be targeted by multiple campaigns.

The project intentionally allows a household's activity to contribute to **every campaign the household genuinely belongs to** rather than arbitrarily assigning overlapping activity to one campaign.

Therefore:

- Campaign-level results are valid when viewed **campaign by campaign**.
- Unsliced totals across all campaigns may count the same underlying activity more than once.
- A grand total across overlapping campaigns should **not automatically be interpreted as a unique business-wide total**.

### 2.8 Catch-All Category

`is_catchall_category` identifies non-merchandise, operational, or system-generated product records that should not distort meaningful category analysis.

Examples include:

- Store supplies and other non-merchandise departments
- Corporate/store-use-only commodities
- Coupon, bottle-deposit, ledger, and similar system commodities
- `COUPON/MISC ITEMS`
- `NO COMMODITY DESCRIPTION`

These records are excluded from category-level business analysis where appropriate.

### 2.9 Anchor Date and `day_no`

The source dataset does not document a real-world start date for its relative `day_no` field.The Gold layer therefore anchors:

```text
day_no = 1 → 2020-01-01
```

This date is **arbitrary** and exists only to enable calendar operations such as:

- weekday identification
- month and quarter labels
- period-over-period comparisons
- date-based Power BI time intelligence

The displayed calendar year/date should **not** be interpreted as the actual business date. Relative spacing between days is what matters.

### 2.10 Week Number Convention

The source week numbering does not follow a simple seven-day split.

Gold uses:

```text
IF day_no <= 5
    THEN week 1
ELSE
    ((day_no - 6) / 7) + 2
```

In practical terms:

- Days 1–5 → Week 1
- Day 6 onward → regular seven-day cadence

### 2.11 Causal Tracking vs. Unknown Promotion Codes

Two separate flags are used in `fact_store_promo_lift`.

**`is_causal_tracked`**

Indicates whether causal promotion data exists for the store/product/week combination. An untracked week means:

> No causal record exists.

It does **not** mean:

> No promotion occurred.

The causal source covers only part of the dataset's time range, so untracked periods must remain distinguishable from confirmed non-promotion.

**`is_unknown_mailer_flag`**

Identifies an undocumented/unknown mailer code from the source. Unknown is kept separate from a confirmed "no mailer" value.

### 2.12 Promotion Combination Type

Display and mailer activity are combined into a single readable classification:

| Type | Meaning |
|---|---|
| `Both` | Display and mailer promotion were present |
| `Display Only` | Display promotion only |
| `Mailer Only` | Mailer promotion only |
| `No Promo` | Neither promotion mechanism was recorded |

---

## 3. Discount & Promotional Spend Terminology

| Term | Meaning |
|---|---|
| `retail_disc` | In-store/shelf markdown discount not tied to a coupon. |
| `coupon_disc` | Manufacturer coupon discount. |
| `coupon_match_disc` | Retailer-funded matching discount applied on top of a manufacturer coupon. |
| **Total Discount Spend** | `retail_disc + coupon_disc + coupon_match_disc`; total promotional investment. |
| **Coupon Discount Amount** | `coupon_disc + coupon_match_disc`; the coupon-related portion of discount spend. |
| **In-Store Discount Amount** | `retail_disc`; shelf markdown spend. |
| **Coupon Mix %** | Coupon-related discount spend as a share of total discount spend. |

---

## 4. Campaign & Coupon Terminology

### Campaign Type

A categorical classification of campaigns, such as Type A, B, or C. Campaign types represent different promotional strategies.

### Coupons Distributed

Distinct coupon codes made available for a campaign/category.

### Coupons Redeemed

Coupons that were actually used. Depending on the table or measure, this can refer to distinct redeemed coupon codes or distinct households associated with redemption.

**Distributed and redeemed values must always be compared at a matching grain.**

### Redemption Event

One household redeeming one coupon on one day for one campaign. The composite event identifier:

```text
household + day + coupon + campaign
```

is **not unique at the physical row level**, because one coupon can apply to multiple products. Therefore, redemption-event counts require distinct handling.

### Redemption Event Key

A composite string representing the household + day + coupon + campaign combination.

Distinct-counting this key gives the number of actual redemption events; counting fact rows can overstate the number because multi-product coupons generate multiple rows for the same event.

### Redemption Rate %

```text
Redemption Rate % = Distinct Coupons Redeemed ÷ Distinct Coupons Distributed
```

Both sides must be evaluated at the same coupon-level grain. Comparing coupon-level distribution against household-level redemption can produce misleading rates, including values above 100%.

---

## 5. Promotion / Causal Data Terminology

### Display Flag

Indicates whether a product was promoted through an in-store physical display during a given store/product/week combination.

### Mailer Flag

Indicates whether a product was featured in a mailer during the relevant store/product/week.

### `is_unknown_mailer_flag`

Flags an unknown or undocumented mailer code so that it is not silently interpreted as "no mailer."

### `is_causal_tracked`

Indicates whether causal promotion tracking data exists for the relevant store/product/week.

### Promo Combination Type

Combines display and mailer status into:

- `Both`
- `Display Only`
- `Mailer Only`
- `No Promo`

---

## 6. Data Quality & Modeling Conventions

### Grain

**Grain** is the level of detail represented by one row in a table.

Examples:

- `fact_executive_daily_summary` → one row per calendar date
- `fact_campaign_category_lift` → one row per campaign + commodity category
- `fact_household_segment_lift` → one row per household + campaign
- `fact_store_promo_lift` → one row per date + store + category + promo combination

Always verify grain before summing or comparing metrics.

### Unknown Household / Product

`is_unknown_household` and `is_unknown_product` identify placeholder/backfilled records created when a household demographic or product/category match was unavailable.

Unknown records are intentionally retained so that unmatched activity remains:

- visible
- filterable
- traceable

rather than silently dropped.

### Floored Value

A **floored** value is constrained so that it cannot fall below zero. For example:

```text
wasted_spend_floored >= 0
```

This prevents a business metric such as wasted promotional spend from becoming negative.

---

## 7. Power BI & DAX Terminology

### Period-over-Period (PoP)

Compares a metric with the immediately preceding comparable period.

The project uses **PoP rather than YoY** because the dataset spans only roughly 23 months and does not provide a sufficiently clean multi-year history for a consistent year-over-year comparison.

### Date Table

A Power BI table marked as the official date table for time-intelligence operations.
This is required for functions such as `DATEADD` to work correctly.

### Cross-Filter Direction

Defines how filters propagate through relationships.

The model uses appropriate **Single** direction for time-intelligence relationships. An incorrectly configured **Both** relationship can cause issues with `DATEADD` and contiguous date selections.

### Drill-Down Hierarchy

A hierarchy such as:

```text
Year → Quarter → Month → Day
```

that allows a visual to move from higher-level time summaries to more granular detail.

### Calculation Group

A reusable DAX object that allows a visual to switch between calculation perspectives such as:

- Actual
- Baseline
- Lift %

This avoids creating separate copies of every measure for each perspective.

### Field Parameter

A Power BI object that lets the report user switch the field used by a visual.

Examples include:

- Store ↔ Category
- Different household demographic dimensions

This allows one visual to serve multiple analytical perspectives.

### RANKX

A DAX function used to rank campaigns according to incremental lift.

### TREATAS

A DAX function used to transfer filter context between tables that are not directly related in the model. In this project it is used in the campaign ranking logic to bridge relevant household-level context.

### Significance Threshold

A user-adjustable what-if parameter that defines how large a segment's difference from the overall average must be before it is classified as meaningfully different.

The Power BI parameter passes percentage points (e.g. `10` = 10%), while the comparison metric is stored as a fraction (e.g. `0.10`), so the threshold is converted to matching units before comparison.

---

## 8. Power BI Report — Page-Level Terminology

### Page 1 — Executive Overview

**Primary tables:** `gold.fact_executive_daily_summary`, `gold.dim_date`

| Metric | Meaning |
|---|---|
| **Total Discount Spend** | Total promotional discount dollars given through in-store and coupon mechanisms. |
| **Total Incremental Sales** | Sales generated above the behavioral baseline. |
| **Wasted Spend %** | Floored wasted spend ÷ total discount spend. |
| **Coupon Mix %** | Coupon-related discount ÷ total discount spend. |
| **Period-over-Period %** | Change versus the previous comparable period. |

**Key analytical message:** the report indicates roughly **$0.16 of incremental sales per $1 of discount spend**, suggesting that a large share of discounting subsidizes purchases that would have occurred anyway.

### Page 2 — Campaign & Coupon Performance

**Primary tables:** `gold.fact_campaign_category_lift`, `gold.fact_coupon_redemption`, `gold.dim_campaign`

| Metric / Feature | Meaning |
|---|---|
| **Total Incremental Lift** | Sum of incremental lift across the selected campaign/category context. |
| **Campaign Lift Rank** | Campaign ranking based on incremental lift using `RANKX`. |
| **Top 5 Contribution %** | Share of total lift attributable to the top five ranked campaigns. |
| **Redemption Rate %** | Distinct coupons redeemed ÷ distinct coupons distributed. |
| **Calculation Group** | Lets visuals switch between Actual, Baseline, and Lift % views. |

Redemption rate is intentionally analyzed at **campaign level rather than category level**, because the redemption fact does not contain an independent category field.

**Key analytical message:** most campaigns perform substantially below their behavioral baseline, while the top five campaigns account for only a relatively small share of total lift.

### Page 3 — In-Store Promotion Effectiveness

**Primary table:** `gold.fact_store_promo_lift`

| Metric / Feature | Meaning |
|---|---|
| **Display / Mailer Sales** | Sales associated with tracked display or mailer activity. |
| **% of Category Sales Under Promo** | Promotional sales as a share of the relevant category total. |
| **Display Lift Per Day** | Display-related lift normalized by the number of display-promotion days. |
| **Mailer Lift Per Day** | Mailer-related lift normalized by the number of mailer-promotion days. |
| **Field Parameter** | Switches the visual between Store and Category analysis. |
| **Sales Index (Base 100)** | Indexed measure retained in the model for comparison but not used on the final report. |

Promotion measures use `is_causal_tracked = TRUE()` because the SQL `BIT` field maps to a DAX Boolean.

Per-day normalization is used because raw lift can be misleading when promotional and non-promotional day counts are not meaningfully differentiated at the whole-dataset level.

### Page 4 — Household Segments & Loyalty

**Primary tables:** `gold.fact_household_segment_lift`, `gold.dim_household`

| Metric / Feature | Meaning |
|---|---|
| **Average Lift per Household** | Segment lift averaged across distinct households rather than fact rows. |
| **Overall Average Lift per Household** | Company-wide per-household average used as the comparison baseline. |
| **Lift vs Overall Average** | Difference between a segment's average and the overall average. |
| **Significance Threshold** | User-controlled threshold for identifying meaningful positive/negative segment differences. |
| **Household Segment Field Parameter** | Lets multiple visuals switch across household demographic dimensions. |

Per-household averaging prevents households targeted by many campaigns from disproportionately influencing a segment's result.

---

## 9. Metric Formula Reference

| Metric | Conceptual Formula | Business Question |
|---|---|---|
| **Total Discount Spend** | `SUM(total_discount_amount)` | How much did we invest in promotions? |
| **Total Incremental Sales / Lift** | `SUM(actual_sales) − SUM(behavioral_baseline)` | How much genuinely new sales did promotions generate? |
| **Wasted Spend %** | `SUM(wasted_spend_floored) ÷ SUM(total_discount_spend)` | What share of discount dollars likely did not change behavior? |
| **Coupon Mix %** | `SUM(coupon_discount) ÷ SUM(total_discount_spend)` | How much promotional spend came through coupons? |
| **Redemption Rate %** | `Distinct Coupons Redeemed ÷ Distinct Coupons Distributed` | What share of distributed coupons were used? |
| **Campaign Lift Rank** | `RANKX` over campaign incremental lift | Which campaigns performed best or worst? |
| **Top 5 Contribution %** | `Lift from Top 5 Campaigns ÷ Lift from All Campaigns` | How concentrated is promotional success? |

---

## 10. Quick A–Z Glossary

| Term | Definition |
|---|---|
| **Active Campaign Days** | Calendar days falling within at least one campaign's start/end window. |
| **Anchor Date** | Arbitrary reference date used to convert relative `day_no` values into calendar dates. |
| **Baseline Daily Rate** | Average household spend per non-campaign calendar day used to project expected spend. |
| **Behavioral Baseline** | Estimated spend that would have occurred without the campaign/promotion. |
| **Campaign Overlap** | Intentional multi-reporting of activity when households belong to overlapping campaigns. |
| **Campaign Type** | Categorical grouping of campaigns by promotional strategy. |
| **Catch-All Category** | Non-merchandise/operational records excluded from meaningful category analysis. |
| **Calculation Group** | Reusable DAX logic that changes how a measure is evaluated. |
| **Causal Data** | Source data describing display and mailer promotion activity by store/product/week. |
| **Coupon Discount Amount** | Manufacturer coupon plus retailer coupon-match discount. |
| **Coupon Mix %** | Coupon discount as a share of total discount spend. |
| **Cross-Filter Direction** | Relationship setting controlling how filters propagate between tables. |
| **Display Flag** | Indicator of in-store display promotion activity. |
| **Drill-Down Hierarchy** | Ordered fields allowing users to move from high-level to detailed analysis. |
| **Field Parameter** | Power BI feature for switching the field used by a visual. |
| **Floored Wasted Spend** | Wasted discount spend constrained so it cannot be negative. |
| **Grain** | Level of detail represented by one row in a table. |
| **Incremental Lift** | Actual sales/spend minus behavioral baseline. |
| **`is_causal_tracked`** | Indicates whether causal promotion tracking data exists for the row. |
| **`is_catchall_category`** | Flags non-merchandise/operational product records. |
| **`is_reliable_pair`** | Identifies household/category pairs meeting the minimum observation thresholds. |
| **`is_unknown_household` / `is_unknown_product`** | Flags placeholder/backfilled dimension records. |
| **`is_unknown_mailer_flag`** | Flags undocumented/unknown mailer codes. |
| **PoP** | Period-over-Period comparison with the immediately preceding comparable period. |
| **Promo Combination Type** | Combined classification of display and mailer activity. |
| **Redemption Event** | One household + day + coupon + campaign redemption event. |
| **Redemption Event Key** | Composite identifier for a redemption event. |
| **Redemption Rate %** | Distinct redeemed coupons divided by distinct distributed coupons. |
| **Reliable Pair** | Household/category combination meeting the minimum observation requirements. |
| **RANKX** | DAX function used to rank campaigns by lift. |
| **Significance Threshold** | User-defined threshold for identifying meaningful segment differences. |
| **Targeted Households** | Households actually reached by a campaign. |
| **Total Discount Spend** | Combined retail, coupon, and coupon-match discount spend. |
| **TREATAS** | DAX function used to apply filters across otherwise unrelated tables. |
| **Wasted Spend** | Discount spend associated with purchases at or below expected baseline behavior. |
| **Week Number Convention** | Gold-layer mapping where days 1–5 form week 1 and a seven-day cadence begins from day 6. |

---

## 11. Interpretation Checklist

Before drawing a conclusion from a metric or visual, check:

1. **What is the table grain?**
2. **Is the metric being evaluated at the correct grain?**
3. **Are the households actually targeted by the campaign?**
4. **Could overlapping campaigns be causing multi-reporting?**
5. **Is the baseline based on enough observations?**
6. **Are unknown records being distinguished from confirmed "none" values?**
7. **Is causal data actually available for the period?**
8. **Are coupon distribution and redemption counted at matching grains?**
9. **Are catch-all categories excluded where appropriate?**
10. **Are synthetic Gold dates being interpreted only as relative calendar positions?**

---

*This consolidated reference reflects the business logic embedded in the Gold layer and the completed four-page Power BI/DAX report.*
