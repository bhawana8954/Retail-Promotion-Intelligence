/*
==================================================================================
Script: Create Silver Layer Performance Indexes
==================================================================================
Script Purpose:
    Creates nonclustered indexes to improve query performance for:
        - Data quality and referential integrity checks
        - Duplicate, primary key, and grain validation
        - Join and aggregation performance during Gold layer transformations

    These indexes do NOT alter the underlying data or validation results.
    They purely optimize query execution speeds across Silver and Gold workflows.
==================================================================================
*/

-- ===============================================================
-- 1. silver.transaction_data
-- ===============================================================

-- Supports transaction grain / duplicate check
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_silver_transaction_grain'
      AND object_id = OBJECT_ID('silver.transaction_data')
)
BEGIN
    CREATE INDEX IX_silver_transaction_grain
    ON silver.transaction_data (
        household_key,
        basket_id,
        product_id,
        day
    );
END;
GO

-- Supports product referential integrity check
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_silver_transaction_product'
      AND object_id = OBJECT_ID('silver.transaction_data')
)
BEGIN
    CREATE INDEX IX_silver_transaction_product
    ON silver.transaction_data (
        product_id
    );
END;
GO

-- ===============================================================
-- 2. silver.causal_data
-- ===============================================================

-- Supports duplicate/grain checks
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_silver_causal_grain'
      AND object_id = OBJECT_ID('silver.causal_data')
)
BEGIN
    CREATE INDEX IX_silver_causal_grain
    ON silver.causal_data (
        product_id,
        store_id,
        week_no,
        display,
        mailer
    );
END;
GO

-- ===============================================================
-- 3. silver.product
-- ===============================================================

-- Supports product uniqueness and referential integrity checks
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_silver_product_id'
      AND object_id = OBJECT_ID('silver.product')
)
BEGIN
    CREATE INDEX IX_silver_product_id
    ON silver.product (
        product_id
    );
END;
GO

-- ===============================================================
-- 4. silver.campaign_desc
-- ===============================================================

-- Supports campaign referential integrity checks
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_silver_campaign_desc_campaign'
      AND object_id = OBJECT_ID('silver.campaign_desc')
)
BEGIN
    CREATE INDEX IX_silver_campaign_desc_campaign
    ON silver.campaign_desc(
        campaign
    );
END;
GO

-- ===============================================================
-- 5. silver.campaign_table
-- ===============================================================

-- Supports household + campaign duplicate/grain check
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_silver_campaign_table_grain'
      AND object_id = OBJECT_ID('silver.campaign_table')
)
BEGIN
    CREATE INDEX IX_silver_campaign_table_grain
    ON silver.campaign_table (
        household_key,
        campaign
    );
END;
GO

-- ===============================================================
-- 6. silver.coupon
-- ===============================================================

-- Supports coupon uniqueness and coupon referential integrity checks
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_silver_coupon_grain'
      AND object_id = OBJECT_ID('silver.coupon')
)
BEGIN
    CREATE INDEX IX_silver_coupon_grain
    ON silver.coupon(
        coupon_upc,
        campaign,
        product_id
    );
END;
GO

-- ===============================================================
-- 7. silver.coupon_redempt
-- ===============================================================

-- Supports redemption grain / duplicate check
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_silver_coupon_redempt_grain'
      AND object_id = OBJECT_ID('silver.coupon_redempt')
)
BEGIN
    CREATE INDEX IX_silver_coupon_redempt_grain
    ON silver.coupon_redempt (
        household_key,
        coupon_upc,
        campaign,
        day
    );
END;
GO

PRINT '===============================================================';
PRINT 'Silver Layer performance indexes created/verified successfully.';
PRINT '===============================================================';
GO