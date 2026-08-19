/*
======================================================================================
Stored Procedure: Load Gold Layer (Silver -> Gold)
======================================================================================
Script Purpose:
    Executes the full ETL pipeline to transform Silver layer data into Gold 
    business entities (dimensions) and key performance metrics (fact tables).

Key Business Questions Answered:
    - Incremental Lift: How much additional revenue did campaigns generate compared to normal, non-promotional customer spending?
    - Promotional ROI & Wasted Spend: Are discount investments driving extra volume or subsidizing purchases customers would 
	  have made anyway?
    - Causal & Channel Impact: How effectively do feature ads (mailers) and in-store displays drive category-level sales and 
	  unit lift across stores?

Key Processing Logic:
    1. Dynamic Date Generation: Calculates campaign & transaction max ranges to populate `gold.dim_date` recursively[cite: 1].
    2. Dimension Normalization: Categorizes store supplies, catch-all items, and unknown records for households, products, 
	   campaigns, and coupons[cite: 1].
    3. Executive Summary Aggregations: Computes household-level daily spend rates on non-campaign baseline days and measures 
	   total vs. floored wasted promotional spend[cite: 1].
    4. Promotional & Campaign Lift:
       - Normalizes baseline spend per day with `ISNULL()` protections against zero-day divisions to track incremental 
	     lift[cite: 1].
       - Maps campaign coupons to primary product categories to evaluate targeted vs. behavioral baseline performance[cite: 1].
    5. Causal & Segment Tracking: Measures display and mailer promotional combinations across store-commodity grains and 
	   tracks campaign lift per household segment[cite: 1].

Parameters:
    None.

Usage Example:
    EXEC gold.load_gold;
======================================================================================
*/

CREATE OR ALTER PROCEDURE gold.load_gold 
AS BEGIN
	SET NOCOUNT ON;
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	DECLARE @AnchorDate DATE = '2020-01-01'; DECLARE @MaxDay INT;

	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '===========================================================';
		PRINT 'Loading Gold Layer';
		PRINT '===========================================================';

		-- Dynamically calculate max day across transaction and campaign data
		SELECT @MaxDay = MAX(max_d)
		FROM (
			SELECT MAX(day) AS max_d FROM silver.transaction_data
			UNION ALL
			SELECT MAX(end_day) AS max_d FROM silver.campaign_desc
		) AS t;

		-- Default to Day 719 if max day is lower or NULL
		SET @MaxDay = ISNULL(NULLIF(@MaxDay, 0), 719);

		-- =============================================================;
		-- 1. Dimension table: gold.dim_date
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.dim_date';
		TRUNCATE TABLE gold.dim_date;
		PRINT '>> Inserting Data into: gold.dim_date';
		
			;WITH DaySequence AS (
			SELECT 1 AS day_no UNION ALL
			SELECT day_no + 1
			FROM DaySequence
			WHERE day_no < @MaxDay
			)
			INSERT INTO gold.dim_date (date_key, full_date, day_no, week_no, month_no, month_name, quarter, year, day_name, 
						is_weekend)
			SELECT
				CAST(CONVERT(VARCHAR(8), DATEADD(DAY, day_no - 1, @AnchorDate), 112) AS INT) AS date_key,
				DATEADD(DAY, day_no - 1, @AnchorDate) AS full_date,
				day_no,
				CAST(CASE WHEN day_no <= 5 THEN 1 ELSE ((day_no - 6) / 7) + 2 END AS SMALLINT) AS week_no,
				CAST(DATEPART(MONTH, DATEADD(DAY, day_no - 1, @AnchorDate)) AS TINYINT) AS month_no,
				DATENAME(MONTH, DATEADD(DAY, day_no - 1, @AnchorDate)) AS month_name,
				'Q' + CAST(DATEPART(QUARTER, DATEADD(DAY, day_no - 1, @AnchorDate)) AS VARCHAR(1)) AS quarter,
				DATEPART(YEAR, DATEADD(DAY, day_no - 1, @AnchorDate)) AS year,
				DATENAME(WEEKDAY, DATEADD(DAY, day_no - 1, @AnchorDate)) AS day_name,
				CASE WHEN DATEPART(WEEKDAY, DATEADD(DAY, day_no - 1, @AnchorDate)) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
			FROM DaySequence
			OPTION (MAXRECURSION 1000);

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 2. Dimension table: gold.dim_household
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.dim_household';
		TRUNCATE TABLE gold.dim_household;
		PRINT '>> Inserting Data into: gold.dim_household';
			
			INSERT INTO gold.dim_household (household_key, age_group, marital_status, income_level, homeownership_status,
						household_composition, household_size, kid_category, is_unknown_household)
			SELECT 
				household_key,
				age_group,
				marital_status_group,
				income_level,
				homeownership_status,
				household_composition,
				household_size,
				kid_category,
				CASE WHEN age_group = 'Unknown'
				 	 AND marital_status_group = 'U'
					 AND income_level = 'Unknown'
					 AND homeownership_status = 'Unknown'
					 AND household_composition = 'Unknown'
					 AND household_size = 'Unknown'
					 AND kid_category = 'Unknown'
					 THEN 1
					 ELSE 0
				END AS is_unknown_household
			FROM silver.hh_demographic;
			
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 3. Dimension table: gold.dim_product
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.dim_product';
		TRUNCATE TABLE gold.dim_product;
		PRINT '>> Inserting Data into: gold.dim_product';
			
			;WITH CleanProducts AS (
				SELECT 
					p.product_id,
					p.manufacturer,
					p.department,
					p.brand,
					p.commodity_desc,
					p.sub_commodity_desc,
					p.curr_size_of_product,
					p.is_unknown_product
				FROM silver.product AS p
			)
			INSERT INTO gold.dim_product (product_id, manufacturer, department, brand, commodity_desc, sub_commodity_desc,
						curr_size_of_product, is_catchall_category, is_unknown_product)
			SELECT 
				product_id,
				manufacturer,
				department,
				brand,
				commodity_desc,
				sub_commodity_desc,
				curr_size_of_product,
				-- Flag accounting/ledger catch-all categories
				CASE 
					-- 1. Non-merchandise & operational departments
					WHEN department IN ('CNTRL/STORE SUP', 'COUP/STR & MFG', 'GM MERCH EXP', 'MISC SALES TRAN', 'MISC. TRANS.', 
										'PHARMACY SUPPLY','CHARITABLE CONT','PROD-WHS SALES','MEAT-WHSE') THEN 1
                    -- 2. Store supplies & internal corporate use commodities
					WHEN commodity_desc IN ('DELI SUPPLIES', 'MEAT SUPPLIES', 'PROD SUPPLIES', '(CORP USE ONLY)',
											'MISCELLANEOUS(CORP USE ONLY)') THEN 1
					-- 3. System coupons, deposits, & ledger adjustment commodities
					WHEN commodity_desc IN ('COUPON', 'COUPON/MISC ITEMS', 'COUPONS/STORE & MFG', 'NO COMMODITY DESCRIPTION', 
											'BOTTLE DEPOSITS') THEN 1
					ELSE 0 
				END AS is_catchall_category,
				is_unknown_product
			FROM CleanProducts;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 4. Dimension table: gold.dim_campaign
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.dim_campaign';
		TRUNCATE TABLE gold.dim_campaign;
		PRINT '>> Inserting Data into: gold.dim_campaign';

			 ;WITH CampaignData AS (
				SELECT 
					c.campaign AS campaign_id,
					c.description AS campaign_type,
					c.start_day,
					c.end_day,
					ISNULL(d_start.full_date, DATEADD(DAY, c.start_day - 1, @AnchorDate)) AS start_date,
					ISNULL(d_end.full_date, DATEADD(DAY, c.end_day - 1, @AnchorDate)) AS end_date,
					(c.end_day - c.start_day + 1) AS duration_days
				FROM silver.campaign_desc AS c
				LEFT JOIN gold.dim_date AS d_start ON c.start_day = d_start.day_no
				LEFT JOIN gold.dim_date AS d_end ON c.end_day = d_end.day_no
				)
			INSERT INTO gold.dim_campaign (campaign_id, campaign_type, start_day, end_day, start_date, end_date, duration_days)
			SELECT
				campaign_id,
				campaign_type,
				start_day,
				end_day,
				start_date,
				end_date,
				duration_days
			FROM CampaignData;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 5. Dimension table: gold.dim_store
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.dim_store';
		TRUNCATE TABLE gold.dim_store;
		PRINT '>> Inserting Data into: gold.dim_store';
			
			;WITH AllStores AS (
				SELECT store_id FROM silver.transaction_data WHERE store_id IS NOT NULL
				UNION
				SELECT store_id FROM silver.causal_data WHERE store_id IS NOT NULL
			)
			INSERT INTO gold.dim_store (store_id)
			SELECT store_id 
			FROM AllStores;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 6. Dimension table: gold.dim_coupon
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.dim_coupon';
		TRUNCATE TABLE gold.dim_coupon;
		PRINT '>> Inserting Data into: gold.dim_coupon';

			INSERT INTO gold.dim_coupon (coupon_upc, product_id, campaign_id, campaign_type)
			SELECT 
				c.coupon_upc,
				c.product_id,
				c.campaign,
				cd.description AS campaign_type
			FROM silver.coupon AS c
			LEFT JOIN silver.campaign_desc AS cd ON c.campaign = cd.campaign;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 7. Fact table: gold.fact_transactions
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.fact_transactions';
		TRUNCATE TABLE gold.fact_transactions;
		PRINT '>> Inserting Data into: gold.fact_transactions';

			INSERT INTO gold.fact_transactions (date_key, household_key, basket_id, day_number, product_id, store_id, trans_time,
						week_no, quantity, sales_value, retail_disc, coupon_disc, coupon_match_disc)
			SELECT
				d.date_key,
				t.household_key,
				t.basket_id,
				t.day AS day_number,
				t.product_id,
				t.store_id,
				ISNULL(t.trans_time, 0) AS trans_time,
				t.week_no,
				ISNULL(t.quantity, 0) AS quantity,
				ISNULL(t.sales_value, 0.00) AS sales_value,
				ISNULL(t.retail_disc, 0.00) AS retail_disc,
				ISNULL(t.coupon_disc, 0.00) AS coupon_disc,
				ISNULL(t.coupon_match_disc, 0.00) AS coupon_match_disc
			FROM silver.transaction_data AS t
			INNER JOIN gold.dim_date AS d ON t.day = d.day_no;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 8. Fact table: gold.fact_coupon_redemption
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.fact_coupon_redemption';
		TRUNCATE TABLE gold.fact_coupon_redemption;
		PRINT '>> Inserting Data into: gold.fact_coupon_redemption';
			
			INSERT INTO gold.fact_coupon_redemption (redemption_event_key, date_key, household_key, day_number, coupon_upc, 
						campaign_id, product_id, campaign_type)
			SELECT DISTINCT
				CAST(cr.household_key AS VARCHAR(10)) + '-' + CAST(cr.day AS VARCHAR(10)) + '-' + cr.coupon_upc + '-' + 
					CAST(cr.campaign AS VARCHAR(10)) AS redemption_event_key,
				d.date_key,
				cr.household_key,
				cr.day AS day_number,
				cr.coupon_upc,
				cr.campaign,
				c.product_id,
				ISNULL(cd.description, 'Unknown') AS campaign_type
			FROM silver.coupon_redempt AS cr
			INNER JOIN gold.dim_date AS d ON cr.day = d.day_no
			LEFT JOIN silver.coupon AS c ON cr.coupon_upc = c.coupon_upc AND cr.campaign = c.campaign
			LEFT JOIN silver.campaign_desc AS cd ON cr.campaign = cd.campaign;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 9. Fact table: gold.fact_executive_daily_summary
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.fact_executive_daily_summary';
		TRUNCATE TABLE gold.fact_executive_daily_summary;
		PRINT '>> Inserting Data into: gold.fact_executive_daily_summary';

			-- 1. Identify active campaign exposure days across all campaigns in silver.campaign_desc
			;WITH ActiveCampaignDays AS (
				SELECT DISTINCT
					d.day_no AS day_number
				FROM gold.dim_date AS d
				INNER JOIN silver.campaign_desc AS cd ON d.day_no BETWEEN cd.start_day AND cd.end_day
				),
			-- 2. Calculate baseline daily spend rate per household (from non-campaign days)
			HouseholdBaselines AS (
				SELECT 
					t.household_key,
					SUM(t.sales_value) / NULLIF(COUNT(DISTINCT t.day), 0) AS baseline_daily_rate
				FROM silver.transaction_data AS t
				LEFT JOIN ActiveCampaignDays AS acd ON t.day = acd.day_number
				WHERE acd.day_number IS NULL
				GROUP BY t.household_key
				),
			-- 3. Pre-aggregate transactions per household per day
			DailyHouseholdSales AS (
				SELECT 
					d.date_key,
					t.day as day_number,
					t.household_key,
					SUM(t.sales_value) AS daily_actual_sales,
					SUM(ISNULL(ABS(t.coupon_disc),0) + ISNULL(ABS(t.coupon_match_disc),0)) AS daily_coupon_disc,
					SUM(ISNULL(ABS(t.retail_disc),0)) AS daily_instore_disc,
					SUM(ISNULL(ABS(t.retail_disc),0) + ISNULL(ABS(t.coupon_disc),0) + ISNULL(ABS(t.coupon_match_disc),0)) AS daily_total_disc
					FROM silver.transaction_data AS t
					INNER JOIN gold.dim_date AS d ON t.day = d.day_no
					GROUP BY d.date_key, t.day, t.household_key
				),
			-- 4. Evaluate campaign exposure and floored wasted spend per household-day
			DailyHouseholdMetrics AS (
				SELECT 
					dhs.date_key,
					dhs.household_key,
					dhs.daily_actual_sales,
					dhs.daily_coupon_disc,
					dhs.daily_instore_disc,
					dhs.daily_total_disc,
					ISNULL(hb.baseline_daily_rate, 0.00) AS expected_daily_baseline,
					-- Floored Wasted Spend: Evaluated strictly per household on an active campaign day
					CASE WHEN acd.day_number IS NOT NULL AND 
							  dhs.daily_actual_sales <= ISNULL(hb.baseline_daily_rate, 0.00) THEN dhs.daily_total_disc
						 ELSE 0.00 
					END AS floored_wasted_spend
				FROM DailyHouseholdSales AS dhs
				LEFT JOIN ActiveCampaignDays AS acd ON dhs.day_number = acd.day_number
				LEFT JOIN HouseholdBaselines AS hb ON dhs.household_key = hb.household_key
				)

			-- 5. Roll up cleanly to executive date_key grain
			INSERT INTO gold.fact_executive_daily_summary (date_key, actual_sales_amount, behavioral_baseline_amount,
						coupon_discount_amount, instore_discount_amount, total_discount_amount, wasted_spend_floored_amount)
			SELECT
				date_key,
				SUM(daily_actual_sales) AS actual_sales_amount,
				SUM(expected_daily_baseline) AS behavioral_baseline_amount,
				SUM(daily_coupon_disc) AS coupon_discount_amount,
				SUM(daily_instore_disc) AS instore_discount_amount,
				SUM(daily_total_disc) AS total_discount_amount,
				SUM(floored_wasted_spend) AS wasted_spend_floored_amount
			FROM DailyHouseholdMetrics 
			GROUP BY date_key;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 10. Fact table: gold.fact_campaign_lift
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.fact_campaign_lift';
		TRUNCATE TABLE gold.fact_campaign_lift;
		PRINT '>> Inserting Data into: gold.fact_campaign_lift';

			-- 1. Identify active campaign days across all campaigns
			;WITH ActiveCampaignDays AS (
				SELECT DISTINCT
					d.day_no AS day_number
				FROM gold.dim_date AS d
				INNER JOIN silver.campaign_desc AS cd ON d.day_no BETWEEN cd.start_day AND cd.end_day
				),
			-- 2. Aggregate spend & active purchase days split by non-campaign vs campaign periods
			HouseholdCategoryAggs AS (
				SELECT
					t.household_key,
					COALESCE(NULLIF(TRIM(p.commodity_desc), ''), 'UNKNOWN') AS category,
					MAX(CAST(p.is_catchall_category AS INT)) AS is_catchall_category, 
					-- Baseline metrics (Non-campaign days)
					SUM(CASE WHEN acd.day_number IS NULL THEN t.sales_value ELSE 0 END) AS baseline_spend,
					COUNT(DISTINCT CASE WHEN acd.day_number IS NULL THEN t.day END) AS baseline_days,
					-- Campaign metrics (Active campaign days)
					SUM(CASE WHEN acd.day_number IS NOT NULL THEN t.sales_value ELSE 0 END) AS campaign_spend,
					COUNT(DISTINCT CASE WHEN acd.day_number IS NOT NULL THEN t.day END) AS campaign_days
				FROM silver.transaction_data AS t
				LEFT JOIN gold.dim_product AS p ON t.product_id = p.product_id
				LEFT JOIN ActiveCampaignDays AS acd ON t.day = acd.day_number
				GROUP BY t.household_key, COALESCE(NULLIF(TRIM(p.commodity_desc), ''), 'UNKNOWN')
			)

			-- 3. Load calculated metrics into Gold fact table
			INSERT INTO gold.fact_campaign_lift (household_key, category, baseline_spend, baseline_days, campaign_spend,
						campaign_days, baseline_spend_per_day, campaign_spend_per_day, lift_per_day, is_catchall_category,
						is_reliable_pair)
			SELECT
				household_key,
				category,
				baseline_spend,
				baseline_days,
				campaign_spend,
				campaign_days,
				-- Normalized spend-per-active-day
				CAST(ISNULL(baseline_spend / NULLIF(baseline_days, 0),0.00) AS DECIMAL(10,2)) AS baseline_spend_per_day,
				CAST(ISNULL(campaign_spend / NULLIF(campaign_days, 0),0.00) AS DECIMAL(10,2)) AS campaign_spend_per_day,
				-- Daily Incremental Lift
				CAST(ISNULL(campaign_spend / NULLIF(campaign_days, 0),0.00) - ISNULL(baseline_spend / NULLIF(baseline_days, 0),0.00) AS DECIMAL(10,2)) AS lift_per_day,
				is_catchall_category,
				-- Noise filter flag (>= 5 active baseline days)
				CASE WHEN baseline_days >= 5 AND campaign_days >= 5 THEN 1 
					 ELSE 0 
				END AS is_reliable_pair
			FROM HouseholdCategoryAggs;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 11. Fact table: gold.fact_campaign_category_lift
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.fact_campaign_category_lift';
		TRUNCATE TABLE gold.fact_campaign_category_lift;
		PRINT '>> Inserting Data into: gold.fact_campaign_category_lift';

		-- 1. Identify all days where ANY campaign was active - These days are excluded from the behavioral baseline so that
		-- another campaign's promotional effect is not treated as normal customer behavior.
		;WITH ActiveCampaignDays AS (
			SELECT DISTINCT
				day_number
			FROM (SELECT d.day_no AS day_number
				  FROM gold.dim_date AS d
				  INNER JOIN silver.campaign_desc AS cd ON d.day_no BETWEEN cd.start_day AND cd.end_day) AS x
		),
		-- 2. Campaign information
		Campaigns AS (
			SELECT
				campaign AS campaign_id,
				start_day,
				end_day,
				end_day - start_day + 1 AS duration_days
			FROM silver.campaign_desc
		),
		-- 3. Campaign targeted households - One row per campaign + household.
		TargetedHouseholds AS (
			SELECT DISTINCT
				campaign AS campaign_id,
				household_key
			FROM silver.campaign_table
			WHERE household_key IS NOT NULL AND campaign IS NOT NULL
		),
		-- 4. Map campaign + coupon to ONE primary commodity category - To prevent double-counting, each campaign and coupon pair 
		-- is assigned to the commodity category with the most mapped products, using the category name as a tie-breaker.
		CouponCategoryCounts AS (
			SELECT
				c.campaign,
				c.coupon_upc,
				p.commodity_desc,
				COUNT(DISTINCT c.product_id) AS product_count
			FROM silver.coupon AS c
			INNER JOIN gold.dim_product AS p ON c.product_id = p.product_id
			GROUP BY c.campaign, c.coupon_upc, p.commodity_desc
		),
		PrimaryCouponCategory AS (
			SELECT
				campaign,
				coupon_upc,
				COALESCE(NULLIF(TRIM(commodity_desc), ''),'UNKNOWN') AS commodity_desc
			FROM (SELECT
					campaign,
					coupon_upc,
					commodity_desc,
					product_count,
					ROW_NUMBER() OVER (PARTITION BY campaign, coupon_upc ORDER BY product_count DESC, commodity_desc) AS rn
				FROM CouponCategoryCounts) AS x
			WHERE rn = 1
		),
		-- 5. Coupons distributed- Each campaign + coupon has already been assigned to exactly one category, so DISTINCT coupon counting is safe.
		CouponsDistributed AS (
			SELECT
				campaign AS campaign_id,
				commodity_desc,
				COUNT(DISTINCT coupon_upc) AS coupons_distributed
			FROM PrimaryCouponCategory
			GROUP BY campaign, commodity_desc
		),
		-- 6. Coupons redeemed- Business requirement: "Distinct households that redeemed coupons in this campaign/category."
		CouponsRedeemed AS (
			SELECT
				cr.campaign AS campaign_id,
				pcc.commodity_desc,
				COUNT(DISTINCT cr.household_key) AS coupons_redeemed
			FROM silver.coupon_redempt AS cr
			INNER JOIN PrimaryCouponCategory AS pcc ON cr.campaign = pcc.campaign AND cr.coupon_upc = pcc.coupon_upc
			INNER JOIN TargetedHouseholds AS th ON cr.campaign = th.campaign_id AND cr.household_key = th.household_key
			GROUP BY cr.campaign, pcc.commodity_desc
		),
		-- To measure actual campaign sales, track targeted households during the active period only, excluding catch-all 
		-- operational categories while keeping UNKNOWN commodities.
		CampaignActualSales AS (
			SELECT
				c.campaign_id,
				COALESCE(NULLIF(TRIM(p.commodity_desc), ''), 'UNKNOWN') AS commodity_desc,
				SUM(t.sales_value) AS actual_sales
			FROM Campaigns AS c
			INNER JOIN TargetedHouseholds AS th ON c.campaign_id = th.campaign_id
			INNER JOIN silver.transaction_data AS t ON t.household_key = th.household_key AND t.day BETWEEN c.start_day AND c.end_day
			INNER JOIN gold.dim_product AS p ON t.product_id = p.product_id
			WHERE p.is_catchall_category = 0
			GROUP BY c.campaign_id, COALESCE(NULLIF(TRIM(p.commodity_desc), ''), 'UNKNOWN')
		),
		-- Baseline sales measure targeted households exclusively on non-campaign days to capture true, non-promotional customer behavior.
		TargetedBaselineSales AS (
			SELECT
				c.campaign_id,
				th.household_key,
				COALESCE(NULLIF(TRIM(p.commodity_desc), ''), 'UNKNOWN') AS commodity_desc,
				SUM(t.sales_value) AS baseline_sales,
				COUNT(DISTINCT t.day) AS baseline_days
			FROM Campaigns AS c
			INNER JOIN TargetedHouseholds AS th ON c.campaign_id = th.campaign_id
			INNER JOIN silver.transaction_data AS t ON t.household_key = th.household_key
			INNER JOIN gold.dim_product AS p ON t.product_id = p.product_id
			LEFT JOIN ActiveCampaignDays AS acd ON t.day = acd.day_number
			WHERE acd.day_number IS NULL AND p.is_catchall_category = 0
			GROUP BY c.campaign_id, th.household_key, COALESCE(NULLIF(TRIM(p.commodity_desc), ''), 'UNKNOWN')
		),
		-- Expected campaign sales are calculated by multiplying each targeted household's baseline daily sales rate by the 
		-- campaign's duration.
		BehavioralBaseline AS (
			SELECT
				tbs.campaign_id,
				tbs.commodity_desc,
				SUM(tbs.baseline_sales / NULLIF(tbs.baseline_days, 0) * c.duration_days) AS behavioral_baseline_sales
			FROM TargetedBaselineSales AS tbs
			INNER JOIN Campaigns AS c ON tbs.campaign_id = c.campaign_id
			WHERE tbs.baseline_days >= 5
			GROUP BY tbs.campaign_id, tbs.commodity_desc
		),
		-- Campaign discount investment sums the absolute values of retail, coupon, and coupon-match discounts to convert 
		-- negative source figures into positive costs.
		CampaignDiscountSpend AS (
			SELECT
				c.campaign_id,
				COALESCE(NULLIF(TRIM(p.commodity_desc), ''), 'UNKNOWN') AS commodity_desc,
				SUM(ABS(ISNULL(t.retail_disc, 0)) + ABS(ISNULL(t.coupon_disc, 0)) + ABS(ISNULL(t.coupon_match_disc, 0))) AS discount_spend
			FROM Campaigns AS c
			INNER JOIN TargetedHouseholds AS th ON c.campaign_id = th.campaign_id
			INNER JOIN silver.transaction_data AS t ON t.household_key = th.household_key AND t.day BETWEEN c.start_day AND c.end_day
			INNER JOIN gold.dim_product AS p ON t.product_id = p.product_id
			WHERE p.is_catchall_category = 0
			GROUP BY c.campaign_id, COALESCE(NULLIF(TRIM(p.commodity_desc), ''), 'UNKNOWN')
		),
		-- A UNION merges all category activity—distributions, redemptions, actual sales, and baseline behavior—so no valid 
		-- campaign-category pair is dropped due to zero metrics.
		CampaignCategory AS (
			SELECT campaign_id, commodity_desc FROM CouponsDistributed
			UNION
			SELECT campaign_id, commodity_desc FROM CouponsRedeemed
			UNION 
			SELECT campaign_id, commodity_desc FROM CampaignActualSales
			UNION
			SELECT campaign_id, commodity_desc FROM BehavioralBaseline
		)
		INSERT INTO gold.fact_campaign_category_lift (campaign_id, commodity_desc, coupons_distributed, coupons_redeemed,
					actual_sales, behavioral_baseline_sales, discount_spend, incremental_lift)
		SELECT
			cc.campaign_id,
			cc.commodity_desc,
			ISNULL(cd.coupons_distributed, 0) AS coupons_distributed,
			ISNULL(cr.coupons_redeemed, 0) AS coupons_redeemed,
			CAST(ISNULL(cas.actual_sales, 0.00) AS DECIMAL(12,2)) AS actual_sales,
			CAST(ISNULL(bb.behavioral_baseline_sales, 0.00) AS DECIMAL(12,2)) AS behavioral_baseline_sales,
			CAST(ISNULL(ds.discount_spend, 0.00) AS DECIMAL(12,2)) AS discount_spend,
			CAST(ISNULL(cas.actual_sales, 0.00) - ISNULL(bb.behavioral_baseline_sales, 0.00)AS DECIMAL(12,2)) AS incremental_lift
		FROM CampaignCategory AS cc
		LEFT JOIN CouponsDistributed AS cd ON cc.campaign_id = cd.campaign_id AND cc.commodity_desc = cd.commodity_desc
		LEFT JOIN CouponsRedeemed AS cr ON cc.campaign_id = cr.campaign_id AND cc.commodity_desc = cr.commodity_desc
		LEFT JOIN CampaignActualSales AS cas ON cc.campaign_id = cas.campaign_id AND cc.commodity_desc = cas.commodity_desc
		LEFT JOIN BehavioralBaseline AS bb ON cc.campaign_id = bb.campaign_id AND cc.commodity_desc = bb.commodity_desc
		LEFT JOIN CampaignDiscountSpend AS ds ON cc.campaign_id = ds.campaign_id AND cc.commodity_desc = ds.commodity_desc;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 12. Fact table: gold.fact_store_promo_lift
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.fact_store_promo_lift';
		TRUNCATE TABLE gold.fact_store_promo_lift;
		PRINT '>> Inserting Data into: gold.fact_store_promo_lift';

			;WITH CleanCausal AS (
				SELECT 
					c.product_id,
					c.store_id,
					c.week_no,
					-- Map all active display codes
					CASE WHEN MAX(CASE WHEN c.is_unknown_display_code = 0 AND c.display <> 'Not on Display' THEN '1'
									   ELSE '0' END) = 1 THEN '1'
						 ELSE '0'
					END AS display_flag,
					-- Flag unknown/unmapped mailer codes
					CASE WHEN MAX(CASE WHEN c.is_unknown_mailer_code = 0 AND c.mailer <> 'Not on ad' THEN '1'
									   ELSE '0' END) = 1 THEN '1'
						 ELSE '0'
					END AS mailer_flag,
					MAX(CAST(c.is_unknown_mailer_code AS INT)) AS is_unknown_mailer_flag
				FROM silver.causal_data AS c
				GROUP BY c.product_id, c.store_id, c.week_no
				),
			WeeklyStoreAggs AS (
				SELECT 
					d.date_key,
					t.store_id,
					ISNULL(NULLIF(TRIM(p.commodity_desc), ''), 'UNKNOWN') AS commodity_desc,
					ISNULL(cc.display_flag, '0') AS display_flag,
					ISNULL(cc.mailer_flag, '0') AS mailer_flag,
					ISNULL(cc.is_unknown_mailer_flag, 0) AS is_unknown_mailer_flag,
					CASE WHEN cc.product_id IS NULL THEN 0 ELSE 1 END AS is_causal_tracked,
					CASE 
						WHEN ISNULL(cc.display_flag, '0') = '1' AND ISNULL(cc.mailer_flag, '0') = '1' THEN 'Both'
						WHEN ISNULL(cc.display_flag, '0') = '1' AND ISNULL(cc.mailer_flag, '0') = '0' THEN 'Display Only'
						WHEN ISNULL(cc.display_flag, '0') = '0' AND ISNULL(cc.mailer_flag, '0') = '1' THEN 'Mailer Only'
						ELSE 'No Promo'
					END AS promo_combination_type,
					SUM(t.sales_value) AS actual_sales,
					SUM(t.quantity) AS units_sold
				FROM silver.transaction_data AS t
				INNER JOIN gold.dim_date AS d ON t.day = d.day_no
				LEFT JOIN silver.product AS p ON t.product_id = p.product_id
				LEFT JOIN CleanCausal AS cc ON t.product_id = cc.product_id AND 
											   t.store_id = cc.store_id AND 
											   t.week_no = cc.week_no
				GROUP BY d.date_key,
						 t.store_id,
						 ISNULL(NULLIF(TRIM(p.commodity_desc), ''), 'UNKNOWN'),
						 ISNULL(cc.display_flag, '0'),
						 ISNULL(cc.mailer_flag, '0'),
						 ISNULL(cc.is_unknown_mailer_flag, 0),
						 CASE WHEN cc.product_id IS NULL THEN 0 ELSE 1 END
				)

			INSERT INTO gold.fact_store_promo_lift (date_key, store_id, commodity_desc, display_flag, mailer_flag, 
						is_unknown_mailer_flag, is_causal_tracked, promo_combination_type, actual_sales, units_sold)
			SELECT 
				date_key,
				store_id,
				commodity_desc,
				display_flag,
				mailer_flag,
				is_unknown_mailer_flag,
				is_causal_tracked,
				promo_combination_type,
				actual_sales,
				units_sold
			FROM WeeklyStoreAggs;
		
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- =============================================================;
		-- 13. Fact table: gold.fact_household_segment_lift
		-- =============================================================;
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: gold.fact_household_segment_lift';
		TRUNCATE TABLE gold.fact_household_segment_lift;
		PRINT '>> Inserting Data into: gold.fact_household_segment_lift';

			-- 1. Identify active campaign days across all campaigns
			;WITH ActiveCampaignDays AS (
				SELECT DISTINCT d.day_no AS day_number
				FROM gold.dim_date AS d
				INNER JOIN silver.campaign_desc AS cd ON d.day_no BETWEEN cd.start_day AND cd.end_day
			),
			NonCampaignDayCount AS ( 
				SELECT COUNT(DISTINCT d.day_no) AS total_non_campaign_days 
				FROM gold.dim_date AS d 
				LEFT JOIN ActiveCampaignDays AS acd ON d.day_no = acd.day_number 
				WHERE acd.day_number IS NULL 
			),
			-- 2. Calculate baseline daily spend rate per household from non-campaign days
			HouseholdDailyBaselines AS (
				SELECT 
					t.household_key,
					SUM(t.sales_value) / NULLIF((SELECT total_non_campaign_days FROM NonCampaignDayCount), 0) AS baseline_daily_rate
				FROM silver.transaction_data AS t
				LEFT JOIN ActiveCampaignDays AS acd ON t.day = acd.day_number
				WHERE acd.day_number IS NULL
				GROUP BY t.household_key
			),
			TargetedHouseholds AS (
				SELECT DISTINCT 
					campaign AS campaign_id,
					household_key
				FROM silver.campaign_table
				WHERE household_key IS NOT NULL AND campaign IS NOT NULL
			),
			-- 3. Calculate spend, discounts, and baseline expected spend for each household during active campaigns
			HouseholdCampaignPerformance AS (
				SELECT 
					th.household_key,
					th.campaign_id,
					ISNULL(SUM(t.sales_value),0.00) AS total_spend,
					ISNULL(SUM(ABS(ISNULL(t.retail_disc,0)) + ABS(ISNULL(t.coupon_disc,0)) + ABS(ISNULL(t.coupon_match_disc,0))),0.00) AS total_discount_received,
					-- Expected baseline spend = household baseline daily rate multiplied by the full campaign duration.
					(cd.end_day - cd.start_day + 1) * MAX(ISNULL(hdb.baseline_daily_rate, 0.00)) AS behavioral_baseline_spend
				FROM TargetedHouseholds AS th
				INNER JOIN silver.campaign_desc AS cd ON th.campaign_id = cd.campaign
				LEFT JOIN silver.transaction_data AS t ON t.household_key = th.household_key AND t.day BETWEEN cd.start_day AND cd.end_day
				LEFT JOIN HouseholdDailyBaselines AS hdb ON t.household_key = hdb.household_key
				GROUP BY th.household_key, th.campaign_id, cd.start_day, cd.end_day
			)

			-- 4. Load into Gold
			INSERT INTO gold.fact_household_segment_lift (household_key, campaign_id, total_spend, behavioral_baseline_spend,
				total_discount_received, incremental_lift)
			SELECT 
				household_key,
				campaign_id,
				total_spend,
				behavioral_baseline_spend,
				total_discount_received,
				(total_spend - behavioral_baseline_spend) AS incremental_lift
			FROM HouseholdCampaignPerformance;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @batch_end_time = GETDATE();
		PRINT '===========================================================';
		PRINT 'Loading Gold Layer is completed';
		PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '===========================================================';
	END TRY
	BEGIN CATCH
		PRINT '===========================================================';
		PRINT 'ERROR OCCURED DURING LOADING GOLD LAYER';
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '===========================================================';
	END CATCH
END
