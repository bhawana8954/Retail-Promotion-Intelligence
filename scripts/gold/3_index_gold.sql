/*
======================================================================================
Script: Create Gold Layer Performance Indexes
======================================================================================
Script Purpose:
    Creates nonclustered indexes across all Gold dimension and fact tables to improve:
        - Downstream reporting & BI dashboard query performance (Power BI / Tableau)
        - Star-schema JOIN efficiency between fact and dimension tables
        - Filtering & aggregation performance on dates, households, campaigns, and stores
    These indexes do NOT alter table structures or data values.
    They purely optimize query execution speed.
======================================================================================
*/

-- ===============================================================
-- 1. gold.dim_date
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_dim_date_day_no' AND object_id = OBJECT_ID('gold.dim_date'))
BEGIN
    CREATE INDEX IX_gold_dim_date_day_no
    ON gold.dim_date (day_no)
    INCLUDE (full_date, week_no, month_name, year);
END;
GO

-- ===============================================================
-- 2. gold.dim_household
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_dim_household_demographics' AND object_id = OBJECT_ID('gold.dim_household'))
BEGIN
    CREATE INDEX IX_gold_dim_household_demographics
    ON gold.dim_household (age_group, income_level, household_size, is_unknown_household);
END;
GO

-- ===============================================================
-- 3. gold.dim_product
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_dim_product_commodity' AND object_id = OBJECT_ID('gold.dim_product'))
BEGIN
    CREATE INDEX IX_gold_dim_product_commodity
    ON gold.dim_product (commodity_desc, is_catchall_category);
END;
GO

-- ===============================================================
-- 4. gold.dim_campaign
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_dim_campaign_days' AND object_id = OBJECT_ID('gold.dim_campaign'))
BEGIN
    CREATE INDEX IX_gold_dim_campaign_days
    ON gold.dim_campaign (start_day, end_day, campaign_type);
END;
GO

-- ===============================================================
-- 5. gold.dim_store
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_dim_store_id' AND object_id = OBJECT_ID('gold.dim_store'))
BEGIN
    CREATE INDEX IX_gold_dim_store_id
    ON gold.dim_store (store_id);
END;
GO

-- ===============================================================
-- 6. gold.dim_coupon
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_dim_coupon_lookup' AND object_id = OBJECT_ID('gold.dim_coupon'))
BEGIN
    CREATE INDEX IX_gold_dim_coupon_lookup
    ON gold.dim_coupon (campaign_id, coupon_upc, product_id);
END;
GO

-- ===============================================================
-- 7. gold.fact_transactions
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_fact_transactions_date_hh' AND object_id = OBJECT_ID('gold.fact_transactions'))
BEGIN
    CREATE INDEX IX_gold_fact_transactions_date_hh
    ON gold.fact_transactions (date_key, household_key)
    INCLUDE (sales_value, quantity, retail_disc, coupon_disc, coupon_match_disc);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_fact_transactions_product_store' AND object_id = OBJECT_ID('gold.fact_transactions'))
BEGIN
    CREATE INDEX IX_gold_fact_transactions_product_store
    ON gold.fact_transactions (product_id, store_id)
    INCLUDE (day_number, sales_value);
END;
GO

-- ===============================================================
-- 8. gold.fact_coupon_redemption
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_fact_coupon_redemption_campaign_hh' AND object_id = OBJECT_ID('gold.fact_coupon_redemption'))
BEGIN
    CREATE INDEX IX_gold_fact_coupon_redemption_campaign_hh
    ON gold.fact_coupon_redemption (campaign_id, household_key, date_key);
END;
GO

-- ===============================================================
-- 9. gold.fact_executive_daily_summary
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_fact_executive_daily_summary_date' AND object_id = OBJECT_ID('gold.fact_executive_daily_summary'))
BEGIN
    CREATE INDEX IX_gold_fact_executive_daily_summary_date
    ON gold.fact_executive_daily_summary (date_key)
    INCLUDE (actual_sales_amount, behavioral_baseline_amount, total_discount_amount, wasted_spend_floored_amount);
END;
GO

-- ===============================================================
-- 10. gold.fact_campaign_lift
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_fact_campaign_lift_category_hh' AND object_id = OBJECT_ID('gold.fact_campaign_lift'))
BEGIN
    CREATE INDEX IX_gold_fact_campaign_lift_category_hh
    ON gold.fact_campaign_lift (category, is_reliable_pair)
    INCLUDE (household_key, lift_per_day, baseline_spend_per_day, campaign_spend_per_day);
END;
GO

-- ===============================================================
-- 11. gold.fact_campaign_category_lift
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_fact_campaign_category_lift_lookup' AND object_id = OBJECT_ID('gold.fact_campaign_category_lift'))
BEGIN
    CREATE INDEX IX_gold_fact_campaign_category_lift_lookup
    ON gold.fact_campaign_category_lift (campaign_id, commodity_desc)
    INCLUDE (actual_sales, behavioral_baseline_sales, incremental_lift, discount_spend);
END;
GO

-- ===============================================================
-- 12. gold.fact_store_promo_lift
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_fact_store_promo_lift_combo' AND object_id = OBJECT_ID('gold.fact_store_promo_lift'))
BEGIN
    CREATE INDEX IX_gold_fact_store_promo_lift_combo
    ON gold.fact_store_promo_lift (store_id, commodity_desc, promo_combination_type)
    INCLUDE (actual_sales, units_sold);
END;
GO

-- ===============================================================
-- 13. gold.fact_household_segment_lift
-- ===============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_gold_fact_household_segment_lift_campaign' AND object_id = OBJECT_ID('gold.fact_household_segment_lift'))
BEGIN
    CREATE INDEX IX_gold_fact_household_segment_lift_campaign
    ON gold.fact_household_segment_lift (campaign_id, household_key)
    INCLUDE (total_spend, behavioral_baseline_spend, incremental_lift);
END;
GO

-- ===============================================================
-- Clean Up Redundant Indexes (Already Covered by Clustered PKs)
-- ===============================================================
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_gold_dim_store_id' AND object_id = OBJECT_ID('gold.dim_store'))
BEGIN
    DROP INDEX IX_gold_dim_store_id ON gold.dim_store;
END;
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_gold_fact_executive_daily_summary_date' AND object_id = OBJECT_ID('gold.fact_executive_daily_summary'))
BEGIN
    DROP INDEX IX_gold_fact_executive_daily_summary_date ON gold.fact_executive_daily_summary;
END;
GO

PRINT '===============================================================';
PRINT 'Gold Layer performance indexes created/verified successfully.';
PRINT '===============================================================';
