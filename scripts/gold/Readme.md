# Gold Layer Documentation
This directory contains the SQL scripts required to model and load galaxy-schema dimensions and analytical fact tables from the Silver Layer into the Gold Layer for the Retail Promotion Intelligence project (based on the dunnhumby - The Complete Journey dataset).

## Overview:
The Gold Layer represents the business and consumption layer within the Medallion Architecture (Bronze ➔ Silver ➔ Gold). It transforms cleaned operational data into dimensional models specifically designed to evaluate promotional effectiveness, incremental lift, and campaign ROI.

- **Star-Schema Dimensional Modeling:** Establishes enterprise dimension tables (`dim_date`, `dim_household`, `dim_product`, `dim_campaign`, `dim_store`, `dim_coupon`) around business fact tables to support fast reporting and BI analytics

- **Behavioral Baseline Analysis:** Evaluates true non-promotional customer behavior by isolating days without active campaigns to derive normalized daily spend rates per household.

- **Incremental Lift & Wasted Spend Calculations:** Quantifies incremental revenue generated beyond expected baselines and isolates floored wasted promotional spend (discounts given on purchases customers would have made regardless).

- **Causal & Promo Combo Tracking:** Aggregates promotional interactions across store-commodity levels, identifying performance variations between display ads, mailers, or combined strategies.

- **Dynamic Date & Campaign Ranges** Computes timeline upper bounds recursively to dynamically generate complete calendar and campaign date dimensions without hardcoded dates.

- **Execution Logging & Error Resilience:** Monitors step-by-step table load durations and logs execution status via SQL console output with `TRY...CATCH` exception handling.

For full definitions and formulas behind these concepts, see the [Business Logic & Terminology Reference](../../docs/business_logic_and_terminology.md).

## Directory Structure:

gold/
```
├── 1_DDL_gold.sql                # DDL script defining Gold dimension & fact schemas, primary keys, and types
├── 2_procedure_load_gold.sql     # Stored procedure (gold.load_gold) executing end-to-end Silver ➔ Gold ETL logic
├── 3_index_gold.sql              # Post-load indexing script to optimize analytical queries across facts and dimensions
└── Readme.md                     # Documentation for the gold folder
```

## Transformed Tables:
The schema defines 6 dimension tables and 7 analytical fact tables optimized for business reporting:

### Dimension tables:

| **Table Name** | **Description** | **Columns** |
|---|----------|---|
| `gold.dim_date` | Dynamically generated calendar table tracking day attributes, weeks, quarters, and weekend flags. | `date_key`, `full_date`, `day_no`, `week_no`, `month_no`, `month_name`, `quarter`, `year`, `day_name`, `is_weekend` |
| `gold.dim_household` | Household demographic profile attributes with surrogate flags for unknown demographics. | `household_key`, `age_group`, `marital_status`, `income_level`, `homeownership_status`, `household_composition`, `household_size`, `kid_category`, `is_unknown_household` |
| `gold.dim_product` | Merchandise catalog enriched with flags for operational/accounting catch-all categories. | `product_id`, `manufacturer`, `department`, `brand`, `commodity_desc`, `sub_commodity_desc`, `curr_size_of_product`, `is_catchall_category`, `is_unknown_product` |
| `gold.dim_campaign` | Promotional campaign master mapping duration days and start/end calendar dates. | `campaign_id`, `campaign_type`, `start_day`, `end_day`, `start_date`, `end_date`, `duration_days` |
| `gold.dim_store` | Distinct list of store identifiers derived across transactions and causal tracking logs. | `store_id` |
| `gold.dim_coupon` | Coupon barcode mapping to target products and campaign types. | `coupon_upc`, `product_id`, `campaign_id`, `campaign_type` |

### Facts tables:
| **Table Name** | **Description** | **Columns** |
|---|----------|---|
| `gold.fact_transactions` | Granular Point-of-Sale transaction fact table linked to dimensions. | `transaction_id`, `date_key`, `household_key`, `basket_id`, `day_number`, `product_id`, `store_id`, `trans_time`, `week_no`, `quantity`, `sales_value`, `retail_disc`, `coupon_disc`, `coupon_match_disc` |
| `gold.fact_coupon_redemption` | Event log of coupon redemptions mapped to households, campaigns, and products. | `redemption_key`, `redemption_event_key`, `date_key`, `household_key`, `day_number`, `coupon_upc`, `campaign_id`, `product_id`, `campaign_type` |
| `gold.fact_executive_daily_summary` | Daily executive KPI summary tracking actual sales, baselines, discounts, and floored wasted spend. | `date_key`, `actual_sales_amount`, `behavioral_baseline_amount`, `coupon_discount_amount`, `instore_discount_amount`, `total_discount_amount`, `wasted_spend_floored_amount` |
| `gold.fact_campaign_lift` | Household-category level analysis measuring daily baseline vs. campaign spend lift. | `lift_id`, `household_key`, `category`, `baseline_spend`, `baseline_days`, `campaign_spend`, `campaign_days`, `baseline_spend_per_day`, `campaign_spend_per_day`, `lift_per_day`, `is_catchall_category`, `is_reliable_pair` |
| `gold.fact_campaign_category_lift` | Campaign performance by product commodity tracking coupon distribution, redemptions, and net lift. | `campaign_id`, `commodity_desc`, `coupons_distributed`, `coupons_redeemed`, `actual_sales`, `behavioral_baseline_sales`, `discount_spend`, `incremental_lift` |
| `gold.fact_store_promo_lift` | Weekly store and commodity promotion impact analysis split by display and mailer combinations. | `store_promo_lift_id`, `date_key`, `store_id`, `commodity_desc`, `display_flag`, `mailer_flag`, `is_unknown_mailer_flag`, `is_causal_tracked`, `promo_combination_type`, `actual_sales`, `units_sold` |
| `gold.fact_household_segment_lift` | Targeted household-campaign lift evaluating total spend, discounts, and incremental gain per segment. | `household_segment_lift_id`, `household_key`, `campaign_id`, `total_spend`, `behavioral_baseline_spend`, `total_discount_received`, `incremental_lift` |

## Major Transformations Made:
Key business and data processing highlights applied during the Silver ➔ Gold transition:

- **Dynamic Date Sequence Generation:** Generated calendar dates dynamically from day_no 1 to the maximum detected day across transactions and campaigns using a recursive CTE starting at `@AnchorDate = '2020-01-01'`.

- **Catch-All Product Classification** Identified non-merchandise, store supplies (e.g., CNTRL/STORE SUP, DELI SUPPLIES), and system coupons/bottle deposits via the `is_catchall_category` flag to isolate core retail inventory.

- **Non-Campaign Behavioral Baseline:** Derived expected household daily purchase rates strictly from non-campaign active days, ensuring promotional spikes do not skew baseline metrics.

- **Floored Wasted Spend Evaluation:** Calculated wasted promotional spend on active campaign days where household sales fell below baseline expected daily rates.

- **Coupon Primary Commodity Deduplication:** Resolved multi-product coupon mappings by assigning each coupon to its primary commodity category based on highest product count to eliminate double-counting.

- **Zero-Division & NULL Safety:** Safeguarded all daily spend and lift calculations with `NULLIF()` and `ISNULL()` wrappers.

## Execution Guide:

**Step 1: Create Tables (DDL)**
Ensure Gold schema tables are loaded and accessible before executing Gold DDL:<br>
**SQL**<br>
EXEC 1_DDL_gold.sql;

**Step 2: Create/Deploy the Gold Load Procedure**
Execute the SQL script containing the gold.load_gold stored procedure. This creates or updates the procedure in the database.<br>
**SQL**<br>
EXEC 2_procedure_load_gold;

**Step 3: Execute Data Load**
Run the ETL pipeline stored procedure to process and load Gold dimension and fact tables:<br>
**SQL**<br>
EXEC gold.load_gold;

**Step 4: Create Indexes**
Run the indexing script post-load to accelerate BI query performance across primary and foreign keys:<br>
**SQL**<br>
EXEC 3_index_gold.sql;