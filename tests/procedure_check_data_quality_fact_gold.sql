/*
======================================================================================
Stored Procedure: Check Data Quality (Gold Layer - Fact Tables)
======================================================================================
Script Purpose:
	Runs data quality checks against the 'gold' schema fact tables:
		- Row count checks (Gold table vs. Silver source)
		- Duplicate key checks
		- Referential integrity checks (orphaned FKs)
		- Range/sequence checks
		- Behavioral & aggregate sanity checks across all 7 gold fact entities
	Prints a PASS/FAIL for each check, plus a final summary.

Usage Example:
	EXEC gold.fact_check_data_quality;
======================================================================================
*/

CREATE OR ALTER PROCEDURE gold.fact_check_data_quality AS 
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	DECLARE @fail_count INT = 0;
	DECLARE @check_count INT = 0;
	DECLARE @max_source_day INT;
	
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '===============================================================';
		PRINT 'Running Gold Layer Data Quality Checks for Fact tables.';
		PRINT '===============================================================';

		-- ---------------------------------------------------------------
		-- Checking Table 1: gold.fact_transactions
		-- ---------------------------------------------------------------
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.fact_transactions';
		-- Single-pass aggregation on Silver source data
		SELECT 
			COUNT(*) AS total_rows,
			ISNULL(SUM(ISNULL(t.sales_value, 0.00)), 0) AS total_sales,
			ISNULL(SUM(ISNULL(t.quantity, 0)), 0) AS total_qty,
			ISNULL(SUM(ISNULL(t.retail_disc, 0.00)), 0) AS total_retail_disc,
			ISNULL(SUM(ISNULL(t.coupon_disc, 0.00)), 0) AS total_coupon_disc,
			ISNULL(SUM(ISNULL(t.coupon_match_disc, 0.00)), 0) AS total_coupon_match_disc
		INTO #silver_trans
		FROM silver.transaction_data AS t

		-- Single-pass aggregation on Gold fact table
		SELECT 
			COUNT(*) AS total_rows,
			ISNULL(SUM(sales_value), 0) AS total_sales,
			ISNULL(SUM(quantity), 0) AS total_qty,
			ISNULL(SUM(retail_disc), 0) AS total_retail_disc,
			ISNULL(SUM(coupon_disc), 0) AS total_coupon_disc,
			ISNULL(SUM(coupon_match_disc), 0) AS total_coupon_match_disc
		INTO #gold_trans
		FROM gold.fact_transactions;

		-- Check 1: Row Count
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1 
				   FROM #gold_trans g 
				   CROSS JOIN #silver_trans s 
				   WHERE g.total_rows <> s.total_rows)
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: row count mismatch vs expected Silver transaction population';
		END
		ELSE
			PRINT 'PASS: row count matches expected Silver transaction population';

		-- Check 2: Total Sales Value
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1 
				   FROM #gold_trans g 
				   CROSS JOIN #silver_trans s 
				   WHERE g.total_sales <> s.total_sales)
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: total sales_value mismatch vs Silver transaction data';
		END
		ELSE
			PRINT 'PASS: total sales_value matches Silver transaction data';

		-- Check 3: Total Quantity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1 
				   FROM #gold_trans g 
				   CROSS JOIN #silver_trans s 
				   WHERE g.total_qty <> s.total_qty)
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: total quantity mismatch vs Silver transaction data';
		END
		ELSE
			PRINT 'PASS: total quantity matches Silver transaction data';

		-- Check 4: Discount Reconciliation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1 
				   FROM #gold_trans g CROSS JOIN #silver_trans s 
				   WHERE g.total_retail_disc <> s.total_retail_disc
						 OR g.total_coupon_disc <> s.total_coupon_disc
						 OR g.total_coupon_match_disc <> s.total_coupon_match_disc
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: discount totals mismatch vs Silver transaction data';
		END
		ELSE
			PRINT 'PASS: retail_disc, coupon_disc and coupon_match_disc totals match Silver';

		-- Clean up temp tables immediately
		DROP TABLE #silver_trans;
		DROP TABLE #gold_trans;

		-- Check 5: Household Referential Integrity
		SET @check_count = @check_count + 1;

		IF EXISTS (SELECT 1
				   FROM gold.fact_transactions AS f
				   WHERE NOT EXISTS (SELECT 1 FROM gold.dim_household AS d WHERE f.household_key = d.household_key)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: household_key values missing from gold.dim_household';
		END
		ELSE
			PRINT 'PASS: household_key - referential integrity OK';

		-- Check 6: Product Referential Integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_transactions AS f
				   WHERE NOT EXISTS (SELECT 1 FROM gold.dim_product AS d WHERE f.product_id = d.product_id)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: product_id values missing from gold.dim_product';
		END
		ELSE
			PRINT 'PASS: product_id - referential integrity OK';

		-- Check 7: Store Referential Integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_transactions AS f
				   WHERE NOT EXISTS (SELECT 1 FROM gold.dim_store AS d WHERE f.store_id = d.store_id)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: store_id values missing from gold.dim_store';
		END
		ELSE
			PRINT 'PASS: store_id - referential integrity OK';

		-- Check 8: Day Number / Date Key Referential Integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_transactions AS f
				   WHERE NOT EXISTS (SELECT 1 FROM gold.dim_date AS d WHERE f.day_number = d.day_no AND f.date_key = d.date_key)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: day_number/date_key mapping is invalid in gold.dim_date';
		END
		ELSE
			PRINT 'PASS: day_number and date_key mapping - referential integrity OK';

		-- Check 9: Mandatory NULL Check
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_transactions
				   WHERE date_key IS NULL OR household_key IS NULL OR basket_id IS NULL OR day_number IS NULL OR product_id IS NULL
						 OR store_id IS NULL OR trans_time IS NULL OR week_no IS NULL OR quantity IS NULL OR sales_value IS NULL
						 OR retail_disc IS NULL OR coupon_disc IS NULL OR coupon_match_disc IS NULL)
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULL values found in mandatory fact_transactions columns';
		END
		ELSE
			PRINT 'PASS: no NULL values found in mandatory fact_transactions columns';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ---------------------------------------------------------------
		-- Checking Table 2: gold.fact_coupon_redemption
		-- ---------------------------------------------------------------

		-- Check 1: Row count reconciliation (Streamlined distinct count over source natural keys)
		SET @check_count = @check_count + 1;
		IF (SELECT COUNT(*) FROM gold.fact_coupon_redemption) <>
		   (SELECT COUNT(*) FROM (SELECT DISTINCT cr.household_key, cr.day, cr.coupon_upc, cr.campaign, c.product_id, cd.description
								  FROM silver.coupon_redempt AS cr
								  INNER JOIN gold.dim_date AS d ON cr.day = d.day_no
								  LEFT JOIN silver.coupon AS c ON cr.coupon_upc = c.coupon_upc AND cr.campaign = c.campaign
								  LEFT JOIN silver.campaign_desc AS cd ON cr.campaign = cd.campaign) AS expected
		   )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: row count mismatch vs expected coupon redemption population';
		END
		ELSE
			PRINT 'PASS: row count matches expected coupon redemption population';

		-- Check 2: redemption_event_key is a required column in Gold
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_coupon_redemption
				   WHERE redemption_event_key IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULL redemption_event_key values found';
		END
		ELSE
			PRINT 'PASS: redemption_event_key completeness OK';

		-- Check 3: Household referential integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_coupon_redemption AS f
				   WHERE NOT EXISTS (SELECT 1 
									 FROM gold.dim_household AS d 
									 WHERE f.household_key = d.household_key)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: household_key values missing from gold.dim_household';
		END
		ELSE
			PRINT 'PASS: household_key - referential integrity OK';

		-- Check 4: Product referential integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_coupon_redemption AS f
				   WHERE f.product_id IS NOT NULL AND NOT EXISTS (SELECT 1 
																  FROM gold.dim_product AS d 
																  WHERE f.product_id = d.product_id)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: populated product_id values missing from gold.dim_product';
		END
		ELSE
			PRINT 'PASS: populated product_id - referential integrity OK';

		-- Check 5: Campaign referential integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_coupon_redemption AS f
				   WHERE NOT EXISTS (SELECT 1 
									 FROM gold.dim_campaign AS d 
									 WHERE f.campaign_id = d.campaign_id)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: campaign_id values missing from gold.dim_campaign';
		END
		ELSE
			PRINT 'PASS: campaign_id - referential integrity OK';

		-- Check 6: Date / day_number referential integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_coupon_redemption AS f
				   WHERE NOT EXISTS (SELECT 1 
									 FROM gold.dim_date AS d 
									 WHERE f.day_number = d.day_no AND f.date_key = d.date_key)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: day_number/date_key mapping is invalid in gold.dim_date';
		END
		ELSE
			PRINT 'PASS: day_number and date_key mapping - referential integrity OK';

		-- Check 7: Mandatory NULL check
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_coupon_redemption
				   WHERE redemption_event_key IS NULL OR date_key IS NULL OR household_key IS NULL OR day_number IS NULL OR 
						 coupon_upc IS NULL OR campaign_id IS NULL OR campaign_type IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULL values found in mandatory fact_coupon_redemption columns';
		END
		ELSE
			PRINT 'PASS: no NULL values found in mandatory fact_coupon_redemption columns';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ---------------------------------------------------------------
		-- Checking Table 3: gold.fact_executive_daily_summary
		-- ---------------------------------------------------------------
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.fact_executive_daily_summary';

		-- Check 1: Date referential integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_executive_daily_summary AS f
				   WHERE NOT EXISTS (SELECT 1 
									 FROM gold.dim_date AS d 
									 WHERE f.date_key = d.date_key)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: orphaned date_key found in gold.fact_executive_daily_summary';
		END
		ELSE
			PRINT 'PASS: date_key - referential integrity OK';

		-- Check 2: One row per date
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT date_key
				   FROM gold.fact_executive_daily_summary
				   GROUP BY date_key HAVING COUNT(*) > 1
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: multiple rows found for the same date_key';
		END
		ELSE
			PRINT 'PASS: one row per date_key';

		-- Consolidated Daily Aggregation for Checks 3, 4, & 5
		SELECT d.date_key,
			   SUM(t.sales_value) AS expected_actual_sales,
			   SUM(ISNULL(ABS(t.coupon_disc), 0) + ISNULL(ABS(t.coupon_match_disc), 0)) AS expected_coupon_discount,
			   SUM(ISNULL(ABS(t.retail_disc), 0)) AS expected_instore_discount,
			   SUM(ISNULL(ABS(t.retail_disc), 0) + ISNULL(ABS(t.coupon_disc), 0) + ISNULL(ABS(t.coupon_match_disc), 0)) AS expected_total_discount
		INTO #expected_daily_sales
		FROM silver.transaction_data AS t
		INNER JOIN gold.dim_date AS d ON t.day = d.day_no
		GROUP BY d.date_key;

		-- Add a clustered index to make downstream checks instantaneous
		CREATE CLUSTERED INDEX CIX_expected_daily_sales ON #expected_daily_sales(date_key);

		-- Check 3: Date population reconciliation
		SET @check_count = @check_count + 1;
		IF (SELECT COUNT(*) FROM gold.fact_executive_daily_summary) <>
		   (SELECT COUNT(*) FROM #expected_daily_sales)
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: date population mismatch vs valid transaction dates';
		END
		ELSE
			PRINT 'PASS: date population matches valid transaction dates';

		-- Check 4: Actual sales reconciliation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_executive_daily_summary AS f
				   INNER JOIN #expected_daily_sales AS s ON f.date_key = s.date_key
				   WHERE f.actual_sales_amount <> s.expected_actual_sales
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: actual_sales_amount mismatch vs transaction_data';
		END
		ELSE
			PRINT 'PASS: actual_sales_amount matches transaction_data';

		-- Check 5: Coupon, instore, and total discount amounts
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_executive_daily_summary AS f
				   INNER JOIN #expected_daily_sales AS s ON f.date_key = s.date_key
				   WHERE f.coupon_discount_amount <> s.expected_coupon_discount
						 OR f.instore_discount_amount <> s.expected_instore_discount
					     OR f.total_discount_amount <> s.expected_total_discount
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: discount amounts mismatch vs transaction_data';
		END
		ELSE
			PRINT 'PASS: coupon, instore and total discount amounts match transaction_data';

		-- Clean up temp table immediately
		DROP TABLE #expected_daily_sales;

		-- Check 6: Total discount formula validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_executive_daily_summary
				   WHERE total_discount_amount <> coupon_discount_amount + instore_discount_amount
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: total_discount_amount does not equal coupon + instore discount';
		END
		ELSE
			PRINT 'PASS: total_discount_amount formula is valid';

		-- Check 7: Wasted spend business-rule validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_executive_daily_summary
				   WHERE wasted_spend_floored_amount < 0 OR wasted_spend_floored_amount > total_discount_amount
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: invalid wasted_spend_floored_amount found';
		END
		ELSE
			PRINT 'PASS: wasted_spend_floored_amount is within valid bounds';

		-- Check 8: Mandatory NULL check
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_executive_daily_summary
				   WHERE date_key IS NULL OR actual_sales_amount IS NULL OR behavioral_baseline_amount IS NULL OR 
						 coupon_discount_amount IS NULL OR instore_discount_amount IS NULL OR total_discount_amount IS NULL OR 
						 wasted_spend_floored_amount IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULL values found in mandatory executive summary columns';
		END
		ELSE
			PRINT 'PASS: no NULL values found in mandatory executive summary columns';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ---------------------------------------------------------------
		-- Checking Table 4: gold.fact_campaign_lift
		-- ---------------------------------------------------------------
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.fact_campaign_lift';

		-- Check 1: Household referential integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_campaign_lift AS f
				   WHERE NOT EXISTS (SELECT 1 FROM gold.dim_household AS h WHERE f.household_key = h.household_key)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: household_key values missing from gold.dim_household';
		END
		ELSE
			PRINT 'PASS: household_key - referential integrity OK';

		-- Check 2: Grain / duplicate validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT household_key, category
				   FROM gold.fact_campaign_lift
				   GROUP BY household_key, category HAVING COUNT(*) > 1
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate household_key + category combinations found';
		END
		ELSE
			PRINT 'PASS: household_key + category grain is unique';

		-- Check 3: is_reliable_pair business-rule validation (>= 5 active days on BOTH sides)
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_campaign_lift
				   WHERE is_reliable_pair <> CASE WHEN baseline_days >= 5 AND campaign_days >= 5 THEN 1 ELSE 0 END
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: is_reliable_pair does not match baseline_days>=5 AND campaign_days>=5 rule';
		END
		ELSE
			PRINT 'PASS: is_reliable_pair correctly reflects the >=5/>=5 threshold';

		-- Check 4: Spend-per-day and lift formula validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_campaign_lift
				   WHERE ABS(baseline_spend_per_day - ISNULL(CAST(baseline_spend / NULLIF(baseline_days, 0) AS DECIMAL(10,2)), 0.00)) > 0.01
						 OR ABS(campaign_spend_per_day - ISNULL(CAST(campaign_spend / NULLIF(campaign_days, 0) AS DECIMAL(10,2)), 0.00)) > 0.01
						 OR ABS(lift_per_day - (campaign_spend_per_day - baseline_spend_per_day)) > 0.01
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: baseline/campaign spend-per-day or lift_per_day formula is inconsistent';
		END
		ELSE
			PRINT 'PASS: spend-per-day and lift_per_day formulas are valid';

		-- Check 5: Non-negative spend / days validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_campaign_lift
				   WHERE baseline_spend < 0 OR campaign_spend < 0 OR baseline_days < 0 OR campaign_days < 0
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: negative spend or day-count values found';
		END
		ELSE
			PRINT 'PASS: spend and day-count values are non-negative';

		-- Check 6: Mandatory NULL check
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_campaign_lift
				   WHERE household_key IS NULL OR category IS NULL OR baseline_spend IS NULL OR baseline_days IS NULL
						 OR campaign_spend IS NULL OR campaign_days IS NULL OR baseline_spend_per_day IS NULL
						 OR campaign_spend_per_day IS NULL OR lift_per_day IS NULL OR is_catchall_category IS NULL
						 OR is_reliable_pair IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULL values found in mandatory fact_campaign_lift columns';
		END
		ELSE
			PRINT 'PASS: no NULL values found in mandatory fact_campaign_lift columns';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ----------';

		-- ---------------------------------------------------------------
		-- Checking Table 5: gold.fact_campaign_category_lift
		-- ---------------------------------------------------------------
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.fact_campaign_category_lift';

		-- Check 1: Campaign referential integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_campaign_category_lift AS f
				   LEFT JOIN gold.dim_campaign AS c ON f.campaign_id = c.campaign_id
				   WHERE c.campaign_id IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: campaign_id values missing from gold.dim_campaign';
		END
		ELSE
			PRINT 'PASS: campaign_id - referential integrity OK';

		-- Check 2: Campaign + category grain validation: One row should exist for each campaign_id + commodity_desc
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT campaign_id, commodity_desc
				   FROM gold.fact_campaign_category_lift
				   GROUP BY campaign_id, commodity_desc HAVING COUNT(*) > 1
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate campaign_id + commodity_desc combinations found';
		END
		ELSE
			PRINT 'PASS: campaign_id + commodity_desc grain is unique';

		-- Check 3: Coupon count validity: Coupon distributions and redemptions are counts and cannot be negative.
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_campaign_category_lift
				   WHERE coupons_distributed < 0 OR coupons_redeemed < 0
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: negative coupons_distributed or coupons_redeemed found';
		END
		ELSE
			PRINT 'PASS: coupon distribution and redemption counts are valid';

		-- Check 4: Discount spend validity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_campaign_category_lift
				   WHERE discount_spend < 0
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: negative discount_spend found';
		END
		ELSE
			PRINT 'PASS: no negative discount_spend found';

		-- Check 5: Incremental lift calculation validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_campaign_category_lift
				   WHERE ABS(incremental_lift - (actual_sales - behavioral_baseline_sales)) > 0.01
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: incremental_lift calculation is inconsistent';
		END
		ELSE
			PRINT 'PASS: incremental_lift calculation is valid';

		-- Check 6: Mandatory NULL check
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_campaign_category_lift
				   WHERE campaign_id IS NULL OR commodity_desc IS NULL OR coupons_distributed IS NULL OR coupons_redeemed IS NULL OR 
						 actual_sales IS NULL OR behavioral_baseline_sales IS NULL OR discount_spend IS NULL OR incremental_lift IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULL values found in mandatory fact_campaign_category_lift columns';
		END
		ELSE
			PRINT 'PASS: no NULL values found in mandatory fact_campaign_category_lift columns';

		-- Check 7: Negative sales / baseline validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_campaign_category_lift
				   WHERE actual_sales < 0 OR behavioral_baseline_sales < 0
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: negative actual_sales or behavioral_baseline_sales found';
		END
		ELSE
			PRINT 'PASS: actual_sales and behavioral_baseline_sales are non-negative';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ---------------------------------------------------------------
		-- Checking Table 6: gold.fact_store_promo_lift
		-- ---------------------------------------------------------------
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.fact_store_promo_lift';

		-- Check 1: Date referential integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_store_promo_lift AS f
				   WHERE NOT EXISTS (SELECT 1 
									 FROM gold.dim_date AS d 
									 WHERE f.date_key = d.date_key)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: date_key values missing from gold.dim_date';
		END
		ELSE
			PRINT 'PASS: date_key - referential integrity OK';

		-- Check 2: Store referential integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_store_promo_lift AS f
				   WHERE NOT EXISTS (SELECT 1 
									 FROM gold.dim_store AS s 
									 WHERE f.store_id = s.store_id)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: store_id values missing from gold.dim_store';
		END
		ELSE
			PRINT 'PASS: store_id - referential integrity OK';

		-- Check 3: Grain / duplicate validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT date_key, store_id, commodity_desc, display_flag, mailer_flag, is_unknown_mailer_flag, is_causal_tracked
				   FROM gold.fact_store_promo_lift
				   GROUP BY date_key, store_id, commodity_desc, display_flag, mailer_flag, is_unknown_mailer_flag, is_causal_tracked 
				   HAVING COUNT(*) > 1
		)
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate date/store/commodity/promotion combinations found';
		END
		ELSE
			PRINT 'PASS: fact_store_promo_lift grain is unique';

		-- Check 4: promo_combination_type business-rule validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_store_promo_lift
				   WHERE promo_combination_type <> CASE WHEN display_flag = '1' AND mailer_flag = '1' THEN 'Both'
														WHEN display_flag = '1' AND mailer_flag = '0' THEN 'Display Only'
														WHEN display_flag = '0' AND mailer_flag = '1' THEN 'Mailer Only'
														ELSE 'No Promo'
													END
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: promo_combination_type does not match display_flag/mailer_flag';
		END
		ELSE
			PRINT 'PASS: promo_combination_type logic is valid';

		-- Check 5: Promotion flag validity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_store_promo_lift
				   WHERE display_flag NOT IN ('0', '1') OR mailer_flag NOT IN ('0', '1')
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: invalid display_flag or mailer_flag values found';
		END
		ELSE
			PRINT 'PASS: display_flag and mailer_flag values are valid';

		-- Check 6: Derived flag validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_store_promo_lift
				   WHERE is_unknown_mailer_flag NOT IN (0, 1) OR is_causal_tracked NOT IN (0, 1)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: invalid derived promotion flag values found';
		END
		ELSE
			PRINT 'PASS: derived promotion flags contain valid 0/1 values';

		-- Check 7: Sales and units reconciliation (Using 1-cent tolerance threshold for float stability)
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM (SELECT SUM(actual_sales) AS gold_sales, SUM(units_sold) AS gold_units
						 FROM gold.fact_store_promo_lift) AS g
				   CROSS JOIN (SELECT SUM(ISNULL(t.sales_value, 0.00)) AS silver_sales,
									  SUM(ISNULL(t.quantity, 0)) AS silver_units
							   FROM silver.transaction_data AS t
							   INNER JOIN gold.dim_date AS d ON t.day = d.day_no) AS s
				   WHERE ABS(g.gold_sales - s.silver_sales) > 0.01 OR g.gold_units <> s.silver_units
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: actual_sales or units_sold mismatch vs transaction_data';
		END
		ELSE
			PRINT 'PASS: actual_sales and units_sold reconcile with transaction_data';

		-- Check 8: Mandatory NULL check
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_store_promo_lift
				   WHERE date_key IS NULL OR store_id IS NULL OR commodity_desc IS NULL OR display_flag IS NULL OR 
						 mailer_flag IS NULL OR is_unknown_mailer_flag IS NULL OR is_causal_tracked IS NULL OR 
						 promo_combination_type IS NULL OR actual_sales IS NULL OR units_sold IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULL values found in mandatory fact_store_promo_lift columns';
		END
		ELSE
			PRINT 'PASS: no NULL values found in mandatory fact_store_promo_lift columns';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- ---------------------------------------------------------------
		-- Checking Table 7: gold.fact_household_segment_lift
		-- ---------------------------------------------------------------
		SET @start_time = GETDATE();
		PRINT '>> Checking Table: gold.fact_household_segment_lift';

		-- Check 1: Household referential integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_household_segment_lift AS f
				   WHERE NOT EXISTS (SELECT 1 
									 FROM gold.dim_household AS h 
									 WHERE f.household_key = h.household_key)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: household_key values missing from gold.dim_household';
		END
		ELSE
			PRINT 'PASS: household_key - referential integrity OK';

		-- Check 2: Campaign referential integrity
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_household_segment_lift AS f
				   WHERE NOT EXISTS (SELECT 1 
									 FROM gold.dim_campaign AS c 
									 WHERE f.campaign_id = c.campaign_id)
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: campaign_id values missing from gold.dim_campaign';
		END
		ELSE
			PRINT 'PASS: campaign_id - referential integrity OK';

		-- Check 3: Grain / duplicate validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT household_key, campaign_id
				   FROM gold.fact_household_segment_lift
				   GROUP BY household_key, campaign_id HAVING COUNT(*) > 1
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: duplicate household_key + campaign_id combinations found';
		END
		ELSE
			PRINT 'PASS: household_key + campaign_id grain is unique';

		-- Pre-aggregated Discount Calculation for Check 4 (Driven by Gold Grain)
		SELECT f.household_key,
			   f.campaign_id,
			   SUM(ABS(ISNULL(t.retail_disc, 0)) + ABS(ISNULL(t.coupon_disc, 0)) + ABS(ISNULL(t.coupon_match_disc, 0))) AS expected_total_discount
		INTO #expected_household_discounts
		FROM (SELECT DISTINCT household_key, campaign_id
			  FROM gold.fact_household_segment_lift) AS f
		INNER JOIN gold.dim_campaign AS c ON f.campaign_id = c.campaign_id
		LEFT JOIN silver.transaction_data AS t ON f.household_key = t.household_key AND t.day BETWEEN c.start_day AND c.end_day
		GROUP BY f.household_key, f.campaign_id;

		CREATE CLUSTERED INDEX CIX_expected_hh_disc ON #expected_household_discounts(household_key, campaign_id);

		-- Check 4: Discount calculation validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_household_segment_lift AS f
				   INNER JOIN #expected_household_discounts AS e ON f.household_key = e.household_key AND f.campaign_id = e.campaign_id
				   WHERE ABS(f.total_discount_received - e.expected_total_discount) > 0.01
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: total_discount_received mismatch vs campaign-period transaction discounts';
		END
		ELSE
			PRINT 'PASS: total_discount_received matches campaign-period discounts';

		DROP TABLE #expected_household_discounts;

		-- Check 5: Incremental lift calculation validation (Using 1-cent tolerance)
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_household_segment_lift
				   WHERE ABS(incremental_lift - (total_spend - behavioral_baseline_spend)) > 0.01
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: incremental_lift calculation is inconsistent';
		END
		ELSE
			PRINT 'PASS: incremental_lift calculation is valid';

		-- Check 6: Non-negative spend / discount validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_household_segment_lift
				   WHERE total_spend < 0 OR behavioral_baseline_spend < 0 OR total_discount_received < 0
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: negative spend or discount values found';
		END
		ELSE
			PRINT 'PASS: spend and discount values are non-negative';

		-- Check 7: Behavioral baseline & total spend validation
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
		HouseholdDailyBaselines AS (
			SELECT t.household_key,
				   SUM(t.sales_value) / NULLIF((SELECT total_non_campaign_days FROM NonCampaignDayCount), 0) AS baseline_daily_rate
			FROM silver.transaction_data AS t
			LEFT JOIN ActiveCampaignDays AS acd ON t.day = acd.day_number
			WHERE acd.day_number IS NULL
			GROUP BY t.household_key
			),
		TargetedHouseholds AS (
			SELECT DISTINCT campaign AS campaign_id, 
						    household_key
			FROM silver.campaign_table
			WHERE household_key IS NOT NULL AND campaign IS NOT NULL
			)
		SELECT th.household_key,
			   th.campaign_id,
			   ISNULL(SUM(t.sales_value), 0.00) AS expected_total_spend,
			   (cd.end_day - cd.start_day + 1) * MAX(ISNULL(hdb.baseline_daily_rate, 0.00)) AS expected_baseline_spend
		INTO #expected_segment_performance
		FROM TargetedHouseholds AS th
		INNER JOIN silver.campaign_desc AS cd ON th.campaign_id = cd.campaign
		LEFT JOIN silver.transaction_data AS t ON t.household_key = th.household_key AND t.day BETWEEN cd.start_day AND cd.end_day
		LEFT JOIN HouseholdDailyBaselines AS hdb ON t.household_key = hdb.household_key
		GROUP BY th.household_key, th.campaign_id, cd.start_day, cd.end_day;

		CREATE CLUSTERED INDEX CIX_expected_segment_perf ON #expected_segment_performance(household_key, campaign_id);

		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_household_segment_lift AS f
				   INNER JOIN #expected_segment_performance AS e ON f.household_key = e.household_key AND f.campaign_id = e.campaign_id
				   WHERE ABS(f.total_spend - e.expected_total_spend) > 0.01 OR ABS(f.behavioral_baseline_spend - e.expected_baseline_spend) > 0.01
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: total_spend or behavioral_baseline_spend mismatch vs recomputed source values';
		END
		ELSE
			PRINT 'PASS: total_spend and behavioral_baseline_spend match recomputed source values';

		-- Check 8: Targeting scope validation
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT household_key, campaign_id FROM gold.fact_household_segment_lift
				   EXCEPT
				   SELECT household_key, campaign_id FROM #expected_segment_performance
				  )
		OR EXISTS (SELECT household_key, campaign_id FROM #expected_segment_performance
				   EXCEPT
				   SELECT household_key, campaign_id FROM gold.fact_household_segment_lift
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: fact_household_segment_lift household+campaign pairs do not match silver.campaign_table targeting exactly';
		END
		ELSE
			PRINT 'PASS: fact_household_segment_lift grain matches targeted household+campaign pairs exactly';

		DROP TABLE #expected_segment_performance;

		-- Check 9: Mandatory NULL check
		SET @check_count = @check_count + 1;
		IF EXISTS (SELECT 1
				   FROM gold.fact_household_segment_lift
				   WHERE household_key IS NULL OR campaign_id IS NULL OR total_spend IS NULL OR behavioral_baseline_spend IS NULL OR 
						 total_discount_received IS NULL OR incremental_lift IS NULL
				  )
		BEGIN
			SET @fail_count = @fail_count + 1;
			PRINT 'FAIL: NULL values found in mandatory fact_household_segment_lift columns';
		END
		ELSE
			PRINT 'PASS: no NULL values found in mandatory fact_household_segment_lift columns';

		SET @end_time = GETDATE();
		PRINT '>> Check Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @batch_end_time = GETDATE();
		PRINT '===============================================================';
		PRINT 'Data Quality Check Summary';
		PRINT '===============================================================';
		PRINT '>> Total Checks Run: ' + CAST(@check_count AS NVARCHAR);
		PRINT '>> Total Checks Failed: ' + CAST(@fail_count AS NVARCHAR);
		PRINT '>> Total Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		IF @fail_count = 0
			PRINT '>> ALL CHECKS PASSED';
		ELSE
			PRINT '>> ' + CAST(@fail_count AS NVARCHAR) + ' CHECK(S) FAILED - REVIEW ABOVE';

	END TRY
	BEGIN CATCH
		PRINT '===============================================================';
		PRINT 'ERROR OCCURRED DURING DATA QUALITY CHECKS';
		PRINT 'Error Message: ' + ERROR_MESSAGE();
		PRINT '===============================================================';
	END CATCH
END;
GO