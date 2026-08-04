/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
	This script creates the views for the Gold layer in the data warehouse.
	The Gold layer represents the final dimension and fact tables (Star Schema)

	Each view performs transformations and combines data from the Silver layer
	to produce a clean, enriched and business-ready dataset.

Usage:
	-These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- ======================================================================
-- Create Table: gold.calendar_seed;
-- ======================================================================;
IF OBJECT_ID ('gold.calendar_seed' , 'U') IS NOT NULL
	DROP TABLE gold.calendar_seed;
GO

CREATE TABLE gold.calendar_seed (
    day_number    SMALLINT   NOT NULL   PRIMARY KEY,
    calendar_date DATE       NOT NULL
);
GO

WITH seq_CTE AS (
    SELECT 1 AS day_number
    UNION ALL
    SELECT day_number + 1 FROM seq_CTE WHERE day_number < 719
    )
INSERT INTO gold.calendar_seed (
    day_number,
    calendar_date
    )
    SELECT 
        day_number,
        DATEADD(DAY, day_number -1, '2020-01-01') AS calendar_date
    FROM seq_CTE
    OPTION (MAXRECURSION 719);

-- ======================================================================
-- Create Dimension: gold.dim_date;
-- ======================================================================;
IF OBJECT_ID('gold.dim_date', 'V') IS NOT NULL
	DROP VIEW gold.dim_date;
GO

CREATE VIEW gold.dim_date AS 
SELECT
	day_number,
    calendar_date,
    YEAR(calendar_date) AS year,
    DATEPART(QUARTER, calendar_date) AS quarter,
    MONTH(calendar_date) AS month_number,
    DATENAME(MONTH, calendar_date) AS month_name,
    DATEPART(WEEKDAY, calendar_date) AS day_of_week_number,
    DATENAME(WEEKDAY, calendar_date) AS day_name,
    CASE 
        WHEN DATEPART(WEEKDAY, calendar_date) IN (1,7) THEN 1 
        ELSE 0 
    END AS is_weekend,
    CEILING(day_number / 7.0) AS dunnhumby_week_no
FROM gold.calendar_seed;
GO

-- ======================================================================
-- Create Dimension: gold.dim_household;
-- ======================================================================;
IF OBJECT_ID('gold.dim_household', 'V') IS NOT NULL
	DROP VIEW gold.dim_household;
GO

CREATE VIEW gold.dim_household AS
SELECT
    household_key,
    age_group,
    marital_status_group AS marital_status,
    income_level,
    homeownership_status,
    household_composition,
    household_size,
    kid_category,
    CASE 
        WHEN age_group = 'Unknown' THEN 1 
        ELSE 0 
    END AS is_unknown_household
FROM silver.hh_demographic;
GO

-- ======================================================================
-- Create Dimension: gold.dim_product;
-- ======================================================================;
IF OBJECT_ID('gold.dim_product', 'V') IS NOT NULL
	DROP VIEW gold.dim_product;
GO

CREATE VIEW gold.dim_product AS
SELECT
    product_id,
    department,
    commodity_desc,
    sub_commodity_desc,
    manufacturer,
    brand,
    curr_size_of_product,
    is_unknown_product
FROM silver.product;
GO

-- ======================================================================
-- Create Dimension: gold.dim_campaign;
-- ======================================================================;
IF OBJECT_ID('gold.dim_campaign', 'V') IS NOT NULL
	DROP VIEW gold.dim_campaign;
GO

CREATE VIEW gold.dim_campaign AS
SELECT
    cd.campaign          AS campaign_id,
    cd.description        AS campaign_type,
    cd.start_day,
    cd.end_day,
    sd.calendar_date       AS start_date,
    ed.calendar_date       AS end_date,
    DATEDIFF(DAY, sd.calendar_date, ed.calendar_date) + 1 AS duration_days
FROM silver.campaign_desc cd
JOIN gold.dim_date sd ON sd.day_number = cd.start_day
JOIN gold.dim_date ed ON ed.day_number = cd.end_day;
GO

-- ======================================================================
-- Create Dimension: gold.dim_store;
-- ======================================================================;
IF OBJECT_ID('gold.dim_store', 'V') IS NOT NULL
	DROP VIEW gold.dim_store;
GO

CREATE VIEW gold.dim_store AS
SELECT DISTINCT store_id
FROM (
    SELECT store_id FROM silver.transaction_data
    UNION
    SELECT store_id FROM silver.causal_data
) AS combined_stores;
GO

-- ======================================================================
-- Create Dimension: gold.dim_coupon;
-- ======================================================================;
IF OBJECT_ID('gold.dim_coupon', 'V') IS NOT NULL
	DROP VIEW gold.dim_coupon;
GO

CREATE VIEW gold.dim_coupon AS
SELECT
    c.coupon_upc,
    c.product_id,
    c.campaign AS campaign_id,
    dc.campaign_type
FROM silver.coupon c
LEFT JOIN gold.dim_campaign dc 
    ON dc.campaign_id = c.campaign;
GO

-- ======================================================================
-- Create Dimension: gold.fact_transactions;
-- ======================================================================;
IF OBJECT_ID('gold.fact_transactions', 'V') IS NOT NULL
	DROP VIEW gold.fact_transactions;
GO

CREATE VIEW gold.fact_transactions AS
SELECT
    t.household_key,
    t.basket_id,
    t.day AS day_number,
    t.product_id,
    t.store_id,
    t.trans_time,
    t.week_no,
    t.quantity,
    t.sales_value,
    t.retail_disc,
    t.coupon_disc,
    t.coupon_match_disc
FROM silver.transaction_data t
LEFT JOIN gold.dim_date d      ON d.day_number = t.day
LEFT JOIN gold.dim_household h ON h.household_key = t.household_key
LEFT JOIN gold.dim_product p   ON p.product_id = t.product_id
LEFT JOIN gold.dim_store s     ON s.store_id = t.store_id;
GO

-- ======================================================================
-- Create Table: gold.fact_campaign_lift;
-- ======================================================================;

IF OBJECT_ID('gold.fact_campaign_lift', 'V') IS NOT NULL
	DROP VIEW gold.fact_campaign_lift;
GO

CREATE VIEW gold.fact_campaign_lift AS
WITH household_windows AS (
        SELECT ct.household_key, 
               ct.campaign, 
               cd.start_day, 
               cd.end_day
        FROM silver.campaign_table AS ct
        JOIN silver.campaign_desc AS cd 
            ON cd.campaign = ct.campaign),

     transactions_flagged AS (
        SELECT t.household_key,
               p.commodity_desc AS category,
               t.day,
               t.sales_value,
        CASE WHEN EXISTS (
                SELECT 1 
                FROM household_windows AS hw
                WHERE hw.household_key = t.household_key AND t.day BETWEEN hw.start_day AND hw.end_day) THEN 1 
             ELSE 0 
        END AS in_campaign
        FROM silver.transaction_data AS t
        JOIN silver.product p 
            ON p.product_id = t.product_id),

     period_agg AS (
        SELECT household_key, 
               category, 
               in_campaign,
               SUM(sales_value) AS total_spend,
               COUNT(DISTINCT day) AS distinct_days
        FROM transactions_flagged
        GROUP BY household_key, category, in_campaign),

     pivoted AS (
     SELECT household_key, 
            category,
            MAX(CASE WHEN in_campaign = 0 THEN total_spend END) AS baseline_spend,
            MAX(CASE WHEN in_campaign = 0 THEN distinct_days END) AS baseline_days,
            MAX(CASE WHEN in_campaign = 1 THEN total_spend END) AS campaign_spend,
            MAX(CASE WHEN in_campaign = 1 THEN distinct_days END) AS campaign_days
     FROM period_agg
     GROUP BY household_key, category),

     lift_calc AS (
     SELECT *,
        baseline_spend / NULLIF(baseline_days, 0) AS baseline_spend_per_day,
        campaign_spend / NULLIF(campaign_days, 0) AS campaign_spend_per_day,
        (campaign_spend / NULLIF(campaign_days, 0)) - (baseline_spend / NULLIF(baseline_days, 0)) AS lift_per_day
     FROM pivoted)
SELECT
    household_key,
    category,
    baseline_spend, 
    baseline_days,
    campaign_spend, 
    campaign_days,
    baseline_spend_per_day, 
    campaign_spend_per_day, 
    lift_per_day,
    CASE WHEN category = 'COUPON/MISC ITEMS' THEN 1 
         ELSE 0 
    END AS is_catchall_category
FROM lift_calc
WHERE baseline_days >= 5 AND campaign_days >= 5;
GO

-- ======================================================================
-- Create Table: gold.fact_coupon_redemption;
-- ======================================================================;
IF OBJECT_ID('gold.fact_coupon_redemption', 'V') IS NOT NULL
	DROP VIEW gold.fact_coupon_redemption;
GO

CREATE VIEW gold.fact_coupon_redemption AS
SELECT
    cr.household_key,
    cr.day AS day_number,
    cr.coupon_upc,
    cr.campaign AS campaign_id,
    dc.product_id,
    dc.campaign_type,
    CONCAT(cr.household_key, '-', cr.day, '-', cr.coupon_upc, '-', cr.campaign) AS redemption_event_key
FROM silver.coupon_redempt cr
LEFT JOIN gold.dim_coupon dc
    ON dc.coupon_upc = cr.coupon_upc
       AND dc.campaign_id = cr.campaign;
GO

-- ======================================================================
-- Create Table: gold.fact_store_promotion;
-- ======================================================================;
IF OBJECT_ID('gold.fact_store_promotion', 'V') IS NOT NULL
	DROP VIEW gold.fact_store_promotion;
GO
CREATE OR ALTER VIEW gold.fact_store_promotion AS
WITH week_lookup AS (
    SELECT dunnhumby_week_no AS week_no,
           MIN(calendar_date) AS week_start_date,
           MAX(calendar_date) AS week_end_date
    FROM gold.dim_date
    GROUP BY dunnhumby_week_no
)
SELECT
    cd.product_id,
    cd.store_id,
    cd.week_no,
    wl.week_start_date,
    wl.week_end_date,
    cd.display AS display_code,
    cd.mailer  AS mailer_code,
    cd.is_unknown_mailer_code
FROM silver.causal_data cd
LEFT JOIN week_lookup wl 
    ON wl.week_no = cd.week_no;
GO
